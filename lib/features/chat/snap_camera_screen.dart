import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SnapCameraResult { photo, video }

class SnapCameraCapture {
  final SnapCameraResult type;
  final String path;
  const SnapCameraCapture({required this.type, required this.path});
}

class SnapCameraScreen extends StatefulWidget {
  const SnapCameraScreen({super.key});

  @override
  State<SnapCameraScreen> createState() => _SnapCameraScreenState();
}

class _SnapCameraScreenState extends State<SnapCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _isReady = false;
  bool _isRecording = false;
  bool _isLocked = false;
  bool _isProcessing = false;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  static const int _maxVideoSeconds = 30;
  static const double _lockThreshold = -40.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(index: _cameraIndex);
    }
  }

  Future<void> _initCamera({int index = 0}) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    setState(() {
      _cameras = cameras;
      _isReady = false;
    });
    final ctrl = CameraController(
      cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = ctrl;
    try {
      await ctrl.initialize();
      if (!mounted) return;
      setState(() {
        _cameraIndex = index;
        _isReady = true;
      });
    } catch (_) {}
  }

  void _flipCamera() {
    if (_cameras.length < 2 || _isRecording) return;
    _initCamera(index: (_cameraIndex + 1) % _cameras.length);
  }

  Future<void> _takePhoto() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    try {
      final file = await ctrl.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(SnapCameraCapture(type: SnapCameraResult.photo, path: file.path));
    } catch (_) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _startVideo() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isProcessing) return;
    HapticFeedback.heavyImpact();
    await ctrl.startVideoRecording();
    setState(() {
      _isRecording = true;
      _isLocked = false;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordSeconds++);
      if (_recordSeconds >= _maxVideoSeconds) _stopVideo();
    });
  }

  Future<void> _stopVideo() async {
    _recordTimer?.cancel();
    final ctrl = _controller;
    if (ctrl == null || !_isRecording) return;
    setState(() {
      _isRecording = false;
      _isLocked = false;
      _isProcessing = true;
    });
    HapticFeedback.mediumImpact();
    try {
      final file = await ctrl.stopVideoRecording();
      if (!mounted) return;
      Navigator.of(context).pop(SnapCameraCapture(type: SnapCameraResult.video, path: file.path));
    } catch (_) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _formatTime(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isReady && _controller != null)
            Center(child: CameraPreview(_controller!))
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Top bar: close + flip
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                  // Recording timer
                  if (_isRecording)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                          const SizedBox(width: 6),
                          Text(_formatTime(_recordSeconds),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  // Flip camera
                  GestureDetector(
                    onTap: _flipCamera,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom: shutter button
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hint / lock indicator
                if (!_isRecording)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Tap photo  ·  Hold video  ·  Swipe ↑ to lock',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  )
                else if (_isLocked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        const Text('Locked — tap ■ to stop',
                            style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward_rounded, color: Colors.white60, size: 16),
                        const SizedBox(width: 4),
                        const Text('Swipe up to lock',
                            style: TextStyle(color: Colors.white60, fontSize: 13)),
                      ],
                    ),
                  ),

                // Shutter button
                Center(
                  child: GestureDetector(
                    onTap: _isLocked
                        ? _stopVideo
                        : (_isRecording ? null : _takePhoto),
                    onLongPressStart: (_isRecording || _isProcessing)
                        ? null
                        : (_) => _startVideo(),
                    onLongPressMoveUpdate: _isRecording && !_isLocked
                        ? (details) {
                            if (details.offsetFromOrigin.dy < _lockThreshold) {
                              setState(() => _isLocked = true);
                              HapticFeedback.heavyImpact();
                            }
                          }
                        : null,
                    onLongPressEnd: (_isRecording && !_isLocked)
                        ? (_) => _stopVideo()
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isRecording ? 72 : 80,
                      height: _isRecording ? 72 : 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isRecording ? Colors.red : Colors.white,
                          width: _isRecording ? 4 : 3,
                        ),
                        color: _isRecording
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                      child: _isProcessing
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : _isLocked
                              ? const Icon(Icons.stop_rounded, color: Colors.red, size: 36)
                              : _isRecording
                                  ? const Icon(Icons.stop_rounded, color: Colors.red, size: 36)
                                  : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
