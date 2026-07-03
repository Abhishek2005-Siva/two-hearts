import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

const _iceConfig = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {
      'urls': [
        'turn:openrelay.metered.ca:80',
        'turn:openrelay.metered.ca:443',
        'turn:openrelay.metered.ca:443?transport=tcp',
      ],
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
  ]
};

class VideoCallScreen extends StatefulWidget {
  final String coupleId;
  final bool isCaller;
  final String callId;
  final String? partnerName;

  const VideoCallScreen({
    super.key,
    required this.coupleId,
    required this.isCaller,
    required this.callId,
    this.partnerName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  bool _micOn = true;
  bool _camOn = true;
  bool _connected = false;
  bool _disposed = false;
  bool _remoteDescSet = false;
  String? _error;

  Timer? _timer;
  int _seconds = 0;

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
    _timer?.cancel();
    _answerSub?.cancel();
    _calleeCandSub?.cancel();
    _callerCandSub?.cancel();
    _statusSub?.cancel();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _pc?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final camOk = await Permission.camera.request();
    final micOk = await Permission.microphone.request();
    if (!camOk.isGranted || !micOk.isGranted) {
      if (mounted) setState(() => _error = 'Camera & microphone permission required');
      return;
    }

    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user', 'width': {'ideal': 1280}, 'height': {'ideal': 720}},
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not access camera: $e');
      return;
    }

    if (_disposed || !mounted) return;
    setState(() => _localRenderer.srcObject = _localStream);

    _pc = await createPeerConnection(_iceConfig);

    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    _pc!.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _callDoc.collection(
        widget.isCaller ? 'callerCandidates' : 'calleeCandidates',
      ).add({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty && mounted) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          _connected = true;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
        });
      }
    };

    _pc!.onConnectionState = (state) {
      if (!mounted || _disposed) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _hangUp(notify: false);
      }
    };

    _statusSub = _callDoc.snapshots().listen((snap) {
      final data = snap.data() as Map<String, dynamic>?;
      final status = data?['status'];
      if (!mounted || _disposed) return;
      if (status == 'ended') {
        _hangUp(notify: false);
      } else if (status == 'declined') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call was declined')),
        );
        _hangUp(notify: false);
      }
    });

    if (widget.isCaller) {
      await _setupCaller();
    } else {
      await _setupCallee();
    }
  }

  Future<void> _setupCaller() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    await _callDoc.set({
      'status': 'ringing',
      'callerId': FirebaseAuth.instance.currentUser!.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'offer': {'sdp': offer.sdp, 'type': offer.type},
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
      } catch (_) {
        _remoteDescSet = false;
      }
    });

    _calleeCandSub = _callDoc.collection('calleeCandidates').snapshots().listen((snap) {
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

  Future<void> _setupCallee() async {
    // Wait for offer if not yet present (caller might still be initializing)
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
      data = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () { sub?.cancel(); return null; },
      );
    }

    if (data?['offer'] == null || _disposed) return;

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

    _callerCandSub = _callDoc.collection('callerCandidates').snapshots().listen((snap) {
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

  Future<void> _hangUp({bool notify = true}) async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _answerSub?.cancel();
    _calleeCandSub?.cancel();
    _callerCandSub?.cancel();
    _statusSub?.cancel();
    if (notify) {
      try { await _callDoc.update({'status': 'ended'}); } catch (_) {}
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

  void _toggleMic() {
    final tracks = _localStream?.getAudioTracks();
    if (tracks == null || tracks.isEmpty) return;
    setState(() {
      _micOn = !_micOn;
      tracks[0].enabled = _micOn;
    });
  }

  void _toggleCam() {
    final tracks = _localStream?.getVideoTracks();
    if (tracks == null || tracks.isEmpty) return;
    setState(() {
      _camOn = !_camOn;
      tracks[0].enabled = _camOn;
    });
  }

  void _flipCamera() {
    final tracks = _localStream?.getVideoTracks();
    if (tracks == null || tracks.isEmpty) return;
    Helper.switchCamera(tracks[0]);
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go back', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          Positioned.fill(
            child: _connected
                ? RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : _WaitingScreen(
                    isCaller: widget.isCaller,
                    partnerName: widget.partnerName,
                  ),
          ),

          // Local PiP — tap to flip camera
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            width: 96,
            height: 140,
            child: GestureDetector(
              onTap: _flipCamera,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: Colors.grey.shade900,
                  child: _localRenderer.srcObject != null
                      ? RTCVideoView(
                          _localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : const Center(
                          child: Icon(Icons.videocam_off_rounded,
                              color: Colors.white38, size: 28)),
                ),
              ),
            ),
          ),

          // Call timer
          if (_connected)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _fmt(_seconds),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

          // Controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 36,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CtrlBtn(
                  icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                  label: _micOn ? 'Mute' : 'Unmuted',
                  active: _micOn,
                  onTap: _toggleMic,
                ),
                _CtrlBtn(
                  icon: Icons.call_end_rounded,
                  label: 'End',
                  color: const Color(0xFFE53935),
                  size: 68,
                  onTap: () => _hangUp(),
                ),
                _CtrlBtn(
                  icon: _camOn
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  label: _camOn ? 'Camera' : 'Hidden',
                  active: _camOn,
                  onTap: _toggleCam,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingScreen extends StatelessWidget {
  final bool isCaller;
  final String? partnerName;
  const _WaitingScreen({required this.isCaller, this.partnerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0408),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFE8896A), Color(0xFFD4667A)],
                ),
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            if (partnerName != null)
              Text(
                partnerName!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 8),
            Text(
              isCaller ? 'Calling…' : 'Connecting…',
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final double size;
  final bool active;

  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.size = 56,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (active ? Colors.white24 : Colors.white12);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child:
                Icon(icon, color: Colors.white, size: size * 0.42),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}
