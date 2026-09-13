import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

enum CommunityCameraMode { story, reel }

class CommunityCameraResult {
  const CommunityCameraResult({
    required this.bytes,
    required this.fileName,
    required this.isVideo,
  });

  final Uint8List bytes;
  final String fileName;
  final bool isVideo;
}

class CommunityCameraCaptureScreen extends StatefulWidget {
  const CommunityCameraCaptureScreen({super.key, required this.mode});

  final CommunityCameraMode mode;

  @override
  State<CommunityCameraCaptureScreen> createState() =>
      _CommunityCameraCaptureScreenState();
}

class _CommunityCameraCaptureScreenState
    extends State<CommunityCameraCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  int _cameraIndex = 0;

  bool _loading = true;
  bool _recording = false;
  bool _busy = false;

  String? _error;

  bool get _storyMode => widget.mode == CommunityCameraMode.story;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No camera is available on this device.');
      }

      var preferredIndex = 0;

      for (var i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.front) {
          preferredIndex = i;
          break;
        }
      }

      _cameraIndex = preferredIndex;

      await _startCamera(_cameraIndex);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _startCamera(int index) async {
    final previous = _controller;

    _controller = null;

    if (previous != null) {
      await previous.dispose();
    }

    final camera = _cameras[index];

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    await controller.initialize();

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _flipCamera() async {
    if (_busy || _recording || _cameras.length < 2) return;

    setState(() {
      _busy = true;
    });

    try {
      final next = (_cameraIndex + 1) % _cameras.length;
      _cameraIndex = next;

      await _startCamera(next);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to switch camera: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _busy ||
        _recording) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      if (!mounted) return;

      Navigator.of(context).pop(
        CommunityCameraResult(
          bytes: bytes,
          fileName: 'story_${DateTime.now().millisecondsSinceEpoch}.jpg',
          isVideo: false,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to take photo: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _busy ||
        _recording) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await controller.startVideoRecording();

      if (!mounted) return;

      setState(() {
        _recording = true;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start recording: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        !_recording ||
        _busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final file = await controller.stopVideoRecording();
      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _recording = false;
      });

      Navigator.of(context).pop(
        CommunityCameraResult(
          bytes: bytes,
          fileName:
              '${_storyMode ? 'story' : 'reel'}_${DateTime.now().millisecondsSinceEpoch}.mp4',
          isVideo: true,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _recording = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to finish recording: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    final controller = _controller;

    if (controller != null) {
      controller.dispose();
    }

    super.dispose();
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback? onPressed,
    double size = 48,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: .42),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: .24)),
        ),
        icon: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.white70,
                        size: 60,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Camera unavailable',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _initializeCamera,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (controller != null && controller.value.isInitialized)
              Positioned.fill(
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.previewSize?.height ?? 1,
                      height: controller.value.previewSize?.width ?? 1,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
              ),

            Positioned(
              left: 14,
              right: 14,
              top: 12,
              child: Row(
                children: [
                  _roundButton(
                    icon: Icons.close_rounded,
                    onPressed: _recording
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .44),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFF42E8FF).withValues(alpha: .45),
                      ),
                    ),
                    child: Text(
                      _storyMode ? '999 STORY' : '999 REEL',
                      style: const TextStyle(
                        color: Color(0xFF63ECFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _roundButton(
                    icon: Icons.cameraswitch_rounded,
                    onPressed: _recording ? null : _flipCamera,
                  ),
                ],
              ),
            ),

            if (_recording)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: .86),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 13,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'RECORDING',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_storyMode && !_recording)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Text(
                        'Take a photo or record a video',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else if (!_storyMode && !_recording)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Text(
                        'Record your Reel',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_storyMode && !_recording) ...[
                        GestureDetector(
                          onTap: _busy ? null : _takePhoto,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFF38E7FF),
                                width: 4,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.black,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(width: 30),
                      ],

                      GestureDetector(
                        onTap: _busy
                            ? null
                            : _recording
                            ? _stopRecording
                            : _startRecording,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _recording ? Colors.red : Colors.transparent,
                            border: Border.all(
                              color: _recording
                                  ? Colors.white
                                  : const Color(0xFFFF4D87),
                              width: 5,
                            ),
                          ),
                          child: Icon(
                            _recording
                                ? Icons.stop_rounded
                                : Icons.videocam_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 13),

                  Text(
                    _storyMode
                        ? 'PHOTO  •  VIDEO'
                        : (_recording
                              ? 'Tap stop when finished'
                              : 'Tap to record'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .76),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                    ),
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
