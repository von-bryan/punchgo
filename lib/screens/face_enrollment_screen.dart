import 'package:flutter/material.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'home_screen.dart';
import 'dart:io';
import '../main.dart';
import '../models/employee.dart';
import '../services/database_helper.dart';
import '../services/face_recognition_service.dart';
import '../services/image_upload_service.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  final Employee employee;

  const FaceEnrollmentScreen({Key? key, required this.employee})
      : super(key: key);

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  bool _showPreview = false;
  XFile? _capturedPhoto;
      Timer? _stableTimer;
    bool _autoCaptured = false;
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!_faceDetectedLast) {
        timer.cancel();
        _stableTimer?.cancel();
        return;
      }
      if (_facePercent < 100) {
        setState(() {
          _facePercent += 1;
          if (_facePercent > 100) _facePercent = 100;
        });
        _stableTimer?.cancel();
      } else if (!_autoCaptured) {
        // Start stable timer if not already started
        _stableTimer ??= Timer(const Duration(seconds: 2), () async {
          print('[DEBUG] Stable timer fired at 100%. Starting auto-capture.');
          _progressTimer?.cancel();
          _autoCaptured = true;
          await _cameraController?.stopImageStream();
          if (mounted) setState(() {}); // Ensure UI updates after stream stops
          await _captureFace(auto: true);
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
  }
  CameraController? _cameraController;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final ImageUploadService _uploadService = ImageUploadService();
  bool _isProcessing = false;
  bool _isUploading = false;
  String _statusMessage = 'Position your face in the frame';
  bool _faceDetected = false;
  String? _capturedDescriptors;
  bool _enrollSuccess = false;
  double _facePercent = 0.0; // 0-100
  bool _faceDetectedLast = false;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Initialize cameras if not already done
    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } catch (e) {
        print('Error loading cameras: $e');
        setState(() {
          _statusMessage = 'Camera not available';
        });
        return;
      }
    }

    if (cameras.isEmpty) {
      setState(() {
        _statusMessage = 'No camera available';
      });
      return;
    }

    // Use front camera if available
    CameraDescription? frontCamera;
    for (var camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }

    final camera = frontCamera ?? cameras.first;

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() {});
      _startFaceDetection();
    }
  }

  void _startFaceDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _cameraController!.startImageStream((image) async {
      if (_isProcessing) return;
      _isProcessing = true;
      try {
        final faces = await _faceService.detectFaces(image);
        if (faces.isNotEmpty) {
          final face = faces.first;
          final descriptors = _faceService.extractFaceDescriptors(face);
          if (descriptors != null) {
            if (!_faceDetectedLast) {
              // Start progress animation if face just detected
              _startProgressTimer();
            }
            if (mounted) {
              setState(() {
                _faceDetected = true;
                _capturedDescriptors = descriptors;
                _statusMessage = 'Face detected! Hold still to enroll...';
              });
            }
            _faceDetectedLast = true;
          } else {
            if (mounted) {
              setState(() {
                _faceDetected = false;
                _capturedDescriptors = null;
                _statusMessage = 'Position your face in the frame';
              });
            }
            _faceDetectedLast = false;
            _stopProgressTimer();
          }
        } else {
          if (mounted) {
            setState(() {
              _faceDetected = false;
              _capturedDescriptors = null;
              _statusMessage = 'Position your face in the frame';
            });
          }
          _faceDetectedLast = false;
          _stopProgressTimer();
        }
      } catch (e) {
        print('Error in face detection: $e');
      }
      _isProcessing = false;
    });

  }

  Future<void> _captureFace({bool auto = false}) async {
    if (_capturedDescriptors == null || _facePercent < 100) {
      if (!auto) {
        _showSnackBar('Please hold your face steady until 100%');
      }
      return;
    }
    if (auto) {
      // Auto-capture: take photo, show preview, let user confirm/retry
      try {
        print('[DEBUG] _captureFace(auto: true) called.');
        print('[Enroll] Attempting to take picture...');
        final XFile photo = await _cameraController!.takePicture();
        print('[Enroll] Photo captured: \\${photo.path}');
        if (!mounted) return;
        setState(() {
          _capturedPhoto = photo;
          _showPreview = true;
          _isUploading = false;
        });
        print('[DEBUG] Preview should now be visible.');
        // Stop image stream after auto-capture
        if (_cameraController != null && _cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
      } catch (e, st) {
        print('[Enroll] Error capturing photo: $e');
        print(st);
        if (!mounted) return;
        setState(() {
          _isUploading = false;
        });
        _showSnackBar('Error capturing photo. Please try again.');
      }
      return;
    }
    // Only called by Confirm button now
    if (_capturedDescriptors == null || _capturedDescriptors!.isEmpty) {
      _showSnackBar('Face descriptors not available. Please retake.');
      return;
    }
    
    setState(() {
      _isUploading = true;
      _statusMessage = 'Uploading photo...';
    });
    // Do NOT call stopImageStream here; already stopped after auto-capture
    try {
      final File imageFile = File(_capturedPhoto!.path);
      final String? uploadedPath = await _uploadService.uploadImage(
        imageFile: imageFile,
        empId: widget.employee.empId,
      );
      // Strip folder prefix if present, save only filename
      String? photoPath = uploadedPath;
      if (photoPath != null && photoPath.contains('/')) {
        photoPath = photoPath.split('/').last;
      }
      if (photoPath == null || photoPath.isEmpty) {
        setState(() {
          _isUploading = false;
        });
        _showSnackBar('Photo upload failed, cannot enroll face.');
        return;
      }
      
      // Use new multi-sample enrollment system
      print('[Enroll] Starting enrollment session...');
      int? enrollmentId = await DatabaseHelper.instance.startFaceEnrollmentSession(
        widget.employee.empId,
      );
      
      if (enrollmentId == null) {
        print('[ERROR] enrollmentId is null');
        setState(() {
          _isUploading = false;
        });
        _showSnackBar('Failed to start enrollment session.');
        return;
      }
      
      print('[Enroll] Enrollment ID: $enrollmentId, saving sample...');
      // Save as first sample with quality assessment
      final quality = 85.0; // Default quality for now
      final saved = await DatabaseHelper.instance.saveFaceSample(
        enrollmentId: enrollmentId,
        empId: widget.employee.empId,
        faceDescriptors: _capturedDescriptors!,
        photoPath: photoPath,
        qualityScore: quality,
        lightingQuality: 90,
        angleQuality: 95,
        faceSizeQuality: 80,
        sharpnessQuality: 85,
        sampleAngle: 'frontal',
      );
      
      if (!saved) {
        print('[ERROR] saveFaceSample returned false');
        setState(() {
          _isUploading = false;
        });
        _showSnackBar('Failed to save face sample.');
        return;
      }
      
      print('[Enroll] Sample saved, completing enrollment...');
      // Mark enrollment as complete
      final completed = await DatabaseHelper.instance.completeEnrollment(enrollmentId);
      
      if (!completed) {
        print('[ERROR] completeEnrollment returned false');
        setState(() {
          _isUploading = false;
        });
        _showSnackBar('Failed to complete enrollment.');
        return;
      }
      
      print('✅ Face enrollment completed successfully');
      if (mounted) {
        setState(() {
          _enrollSuccess = true;
          _isUploading = false;
          _showPreview = false;
        });
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => HomeScreen(initialTabIndex: 0),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showSnackBar('Error enrolling face: ${e.toString()}');
    }
  }

  void _onRetake() async {
    setState(() {
      _showPreview = false;
      _capturedPhoto = null;
      _facePercent = 0;
      _autoCaptured = false;
      _enrollSuccess = false;
      _isUploading = false;
    });
    await _cameraController?.startImageStream((image) async {}); // Resume stream
    _startFaceDetection();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enroll Face'),
        centerTitle: true,
      ),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _enrollSuccess ? Colors.green : Colors.blue.shade50,
                  width: double.infinity,
                  child: Column(
                    children: [
                      Text(
                        widget.employee.fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('ID: ${widget.employee.empId}'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: Container(
                      width: 250,
                      height: 400,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _showPreview && _capturedPhoto != null
                                ? Center(
                                    child: Image.file(
                                      File(_capturedPhoto!.path),
                                      fit: BoxFit.cover,
                                      width: 250,
                                      height: 400,
                                    ),
                                  )
                                : Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Center(
                                        child: CameraPreview(_cameraController!),
                                      ),
                                      // Face frame overlay
                                      Center(
                                        child: Container(
                                          width: 200,
                                          height: 300,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: _faceDetected ? Colors.green : Colors.white,
                                              width: 3,
                                            ),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                        ),
                                      ),
                                      // Percentage progress indicator (top right)
                                      Positioned(
                                        top: 20,
                                        right: 20,
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '${_facePercent.toStringAsFixed(0)}%',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Instructions
                                      Positioned(
                                        top: 80,
                                        left: 20,
                                        right: 20,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                _faceDetected ? Icons.check_circle : Icons.face,
                                                color: _faceDetected ? Colors.green : Colors.white,
                                                size: 40,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _statusMessage,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          // Confirm/Retake buttons at bottom when preview is active and not uploading
                          if (_showPreview && _capturedPhoto != null && !_isUploading)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 24,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      // Only allow confirm if face is detected and progress is 100%
                                      if (_capturedDescriptors != null && _facePercent >= 100) {
                                        _captureFace(auto: false);
                                      } else {
                                        _showSnackBar('Please hold your face steady until 100%');
                                      }
                                    },
                                    icon: const Icon(Icons.check),
                                    label: const Text('Confirm'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _onRetake,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retake'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Show loading indicator over preview when uploading
                          if (_isUploading)
                            const Positioned.fill(
                              child: ColoredBox(
                                color: Color.fromARGB(120, 0, 0, 0),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Instructions:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Look directly at the camera\n'
                        '2. Ensure good lighting\n'
                        '3. Keep your face inside the frame\n'
                        '4. Wait for green border\n'
                        '5. Hold steady until 100%',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      if (_showPreview && _capturedPhoto != null && _isUploading)
                        const Text('Processing...'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
  }
}
