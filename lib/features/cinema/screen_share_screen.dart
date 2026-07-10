import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import 'screen_capture_service.dart';

const _fallbackIceServers = [
  {'urls': 'stun:stun.l.google.com:19302'},
  {'urls': 'stun:stun1.l.google.com:19302'},
  {'urls': 'stun:stun2.l.google.com:19302'},
  {'urls': 'stun:stun.cloudflare.com:3478'},
];

Future<Map<String, dynamic>> _buildIceConfig() async {
  final servers = List<Map<String, dynamic>>.from(_fallbackIceServers);
  try {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('webrtc')
        .get()
        .timeout(const Duration(seconds: 5));
    final data = doc.data();
    final urls = (data?['turnUrls'] as List?)?.cast<String>();
    final user = data?['turnUsername'] as String?;
    final cred = data?['turnCredential'] as String?;
    if (urls != null && urls.isNotEmpty && user != null && cred != null) {
      servers.add({'urls': urls, 'username': user, 'credential': cred});
    }
  } catch (_) {}
  return {'iceServers': servers, 'sdpSemantics': 'unified-plan'};
}

const _offerTimeout = Duration(seconds: 20);
const _ringTimeout = Duration(seconds: 45);

/// Screen sharing for Movie Night — the sharer mirrors their phone screen
/// and the partner watches live. Android's own screen-cast picker is what
/// lets the sharer choose entire screen vs a single app, so there's nothing
/// to pre-select in-app. Reuses the same Firestore WebRTC signaling as
/// video calls, tagged with `mode: 'screen'` so the incoming prompt knows
/// what it is.
class ScreenShareScreen extends StatefulWidget {
  final String coupleId;
  final bool isSharer;
  final String callId;
  final String? partnerName;

  const ScreenShareScreen({
    super.key,
    required this.coupleId,
    required this.isSharer,
    required this.callId,
    this.partnerName,
  });

  @override
  State<ScreenShareScreen> createState() => _ScreenShareScreenState();
}

class _ScreenShareScreenState extends State<ScreenShareScreen> {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final _remoteRenderer = RTCVideoRenderer();
  final _localRenderer = RTCVideoRenderer();

  bool _connected = false;
  bool _disposed = false;
  bool _remoteDescSet = false;
  bool _micOn = false;
  bool _serviceStarted = false;
  bool _controlsVisible = true;
  String? _error;

  Timer? _ringTimer;
  StreamSubscription? _answerSub;
  StreamSubscription? _calleeCandSub;
  StreamSubscription? _callerCandSub;
  StreamSubscription? _statusSub;

  late final DocumentReference _callDoc;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _callDoc = FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .collection('calls')
        .doc(widget.callId);
    _init();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _ringTimer?.cancel();
    _answerSub?.cancel();
    _calleeCandSub?.cancel();
    _callerCandSub?.cancel();
    _statusSub?.cancel();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _pc?.close();
    _remoteRenderer.dispose();
    _localRenderer.dispose();
    if (_serviceStarted) ScreenCaptureService.stop();
    super.dispose();
  }

  Future<void> _init() async {
    await _remoteRenderer.initialize();
    await _localRenderer.initialize();

    try {
      if (widget.isSharer) {
        // Start the foreground service FIRST — Android 14+ requires it to
        // be running before a screen-capture virtual display is created.
        await ScreenCaptureService.start();
        _serviceStarted = true;

        final display = await navigator.mediaDevices.getDisplayMedia({
          'audio': false,
          'video': true,
        });
        // Add the sharer's mic so they can narrate — off by default, tap
        // the mic button to turn it on.
        try {
          await Permission.microphone.request();
          final mic = await navigator.mediaDevices
              .getUserMedia({'audio': true, 'video': false});
          for (final t in mic.getAudioTracks()) {
            t.enabled = false;
            await display.addTrack(t);
          }
        } catch (_) {}
        _localStream = display;
        if (mounted) setState(() => _localRenderer.srcObject = _localStream);
      }
    } catch (e) {
      if (_serviceStarted) {
        await ScreenCaptureService.stop();
        _serviceStarted = false;
      }
      if (mounted) {
        setState(() => _error = 'Screen share was cancelled or blocked.\n$e');
      }
      return;
    }

    if (_disposed) return;
    _pc = await createPeerConnection(await _buildIceConfig());

    if (widget.isSharer && _localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
    } else {
      // Viewer only receives — declare recv-only transceivers.
      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.RecvOnly),
      );
      await _pc!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(
            direction: TransceiverDirection.RecvOnly),
      );
    }

    _pc!.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _callDoc
          .collection(
              widget.isSharer ? 'callerCandidates' : 'calleeCandidates')
          .add({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty && mounted) {
        _ringTimer?.cancel();
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          _connected = true;
        });
      }
    };

    _pc!.onConnectionState = (state) {
      if (!mounted || _disposed) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _connected = true);
      } else if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _end(notify: false);
      }
    };

    _statusSub = _callDoc.snapshots().listen((snap) {
      final data = snap.data() as Map<String, dynamic>?;
      final status = data?['status'];
      if (!mounted || _disposed) return;
      if (status == 'ended' || status == 'declined') {
        _end(notify: false);
      }
    });

    if (widget.isSharer) {
      await _setupSharer();
    } else {
      await _setupViewer();
    }
  }

  Future<void> _setupSharer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    await _callDoc.set({
      'status': 'ringing',
      'mode': 'screen',
      'callerId': FirebaseAuth.instance.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });

    _ringTimer = Timer(_ringTimeout, () {
      if (_connected || _disposed || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${widget.partnerName ?? 'Your person'} didn\'t join')));
      _end();
    });

    _answerSub = _callDoc.snapshots().listen((snap) async {
      if (_remoteDescSet || _disposed) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data?['answer'] == null) return;
      _remoteDescSet = true;
      try {
        await _pc!.setRemoteDescription(RTCSessionDescription(
          data!['answer']['sdp'] as String,
          data['answer']['type'] as String,
        ));
      } catch (_) {}
    });

    _calleeCandSub =
        _callDoc.collection('calleeCandidates').snapshots().listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _pc?.addCandidate(RTCIceCandidate(
            change.doc['candidate'] as String,
            change.doc['sdpMid'] as String? ?? '',
            change.doc['sdpMLineIndex'] as int? ?? 0,
          ));
        }
      }
    });
  }

  Future<void> _setupViewer() async {
    var snap = await _callDoc.get();
    var data = snap.data() as Map<String, dynamic>?;

    if (data?['offer'] == null) {
      final completer = Completer<Map<String, dynamic>?>();
      StreamSubscription? sub;
      sub = _callDoc.snapshots().listen((s) {
        final d = s.data() as Map<String, dynamic>?;
        if (d?['offer'] != null && !completer.isCompleted) {
          completer.complete(d);
          sub?.cancel();
        }
      });
      data = await completer.future
          .timeout(_offerTimeout, onTimeout: () {
        sub?.cancel();
        return null;
      });
    }

    if (_disposed) return;
    if (data?['offer'] == null) {
      if (mounted) {
        setState(() =>
            _error = 'Could not connect.\nAsk them to share again.');
      }
      return;
    }

    await _pc!.setRemoteDescription(RTCSessionDescription(
      data!['offer']['sdp'] as String,
      data['offer']['type'] as String,
    ));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    await _callDoc.update({
      'answer': {'sdp': answer.sdp, 'type': answer.type},
      'status': 'active',
    });

    _callerCandSub =
        _callDoc.collection('callerCandidates').snapshots().listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _pc?.addCandidate(RTCIceCandidate(
            change.doc['candidate'] as String,
            change.doc['sdpMid'] as String? ?? '',
            change.doc['sdpMLineIndex'] as int? ?? 0,
          ));
        }
      }
    });
  }

  Future<void> _end({bool notify = true}) async {
    if (_disposed) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _disposed = true;
    _ringTimer?.cancel();
    _answerSub?.cancel();
    _calleeCandSub?.cancel();
    _callerCandSub?.cancel();
    _statusSub?.cancel();
    if (notify) {
      try {
        await _callDoc.update({'status': 'ended'});
      } catch (_) {}
    }
    if (widget.isSharer) _cleanupCallDoc();
    if (_serviceStarted) {
      await ScreenCaptureService.stop();
      _serviceStarted = false;
    }
    final stream = _localStream;
    _localStream = null;
    stream?.getTracks().forEach((t) => t.stop());
    await stream?.dispose();
    final pc = _pc;
    _pc = null;
    await pc?.close();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cleanupCallDoc() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final col in ['callerCandidates', 'calleeCandidates']) {
        final docs = await _callDoc.collection(col).get();
        for (final d in docs.docs) {
          batch.delete(d.reference);
        }
      }
      await batch.commit();
    } catch (_) {}
  }

  void _toggleMic() {
    final tracks = _localStream?.getAudioTracks();
    if (tracks == null || tracks.isEmpty) return;
    setState(() {
      _micOn = !_micOn;
      tracks[0].enabled = _micOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _MessagePane(
        emoji: '📵',
        message: _error!,
        onClose: () => _end(notify: false),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The shared screen (viewer sees remote; sharer sees own preview).
            if (widget.isSharer)
              _localRenderer.srcObject != null
                  ? RTCVideoView(_localRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)
                  : const _MessageBody(
                      emoji: '🖥️',
                      message: 'Getting ready…\nChoose what to share in the '
                          'next prompt — entire screen, or just one app.')
            else if (_connected && _remoteRenderer.srcObject != null)
              RTCVideoView(_remoteRenderer,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)
            else
              _MessageBody(
                emoji: '🍿',
                message:
                    'Connecting to ${widget.partnerName ?? 'their'} screen…',
              ),

            // Top status pill
            if (_controlsVisible)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _connected
                              ? const Color(0xFF43A047)
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isSharer
                            ? (_connected
                                ? 'Sharing your screen'
                                : 'Waiting for them to join…')
                            : (_connected ? 'Live' : 'Connecting…'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom controls
            if (_controlsVisible)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isSharer)
                      _CtrlBtn(
                        icon: _micOn
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                        bg: _micOn ? Colors.white24 : Colors.white,
                        fg: _micOn ? Colors.white : Colors.black,
                        onTap: _toggleMic,
                      ),
                    const SizedBox(width: 22),
                    _CtrlBtn(
                      icon: Icons.call_end_rounded,
                      bg: const Color(0xFFE53935),
                      fg: Colors.white,
                      onTap: () => _end(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _CtrlBtn(
      {required this.icon,
      required this.bg,
      required this.fg,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SquishyTap(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: 26),
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  final String emoji;
  final String message;
  const _MessageBody({required this.emoji, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 54)),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5)),
        ],
      ),
    );
  }
}

class _MessagePane extends StatelessWidget {
  final String emoji;
  final String message;
  final VoidCallback onClose;
  const _MessagePane(
      {required this.emoji, required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 54)),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.white70, height: 1.5)),
              const SizedBox(height: 24),
              TextButton(
                onPressed: onClose,
                child: const Text('Close',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
