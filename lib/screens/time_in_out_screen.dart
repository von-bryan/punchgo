import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../main.dart';
import '../models/employee.dart';
import '../models/login_record.dart';
import '../services/database_helper.dart';
import '../services/face_recognition_service.dart';
import '../services/auth_service.dart';
import 'attendance_history_screen.dart';

class TimeInOutScreen extends StatefulWidget {
  const TimeInOutScreen({Key? key}) : super(key: key);

  @override
  State<TimeInOutScreen> createState() => _TimeInOutScreenState();
}

class _TimeInOutScreenState extends State<TimeInOutScreen> {
  CameraController? _cameraController;
  final FaceRecognitionService _faceService = FaceRecognitionService();
  bool _isProcessing = false;
  String _statusMessage = 'Position your face in the camera';
  Employee? _recognizedEmployee;
  bool _showSuccess = false;
  bool _isConfirmed = false;
  Employee? _currentUser;
  String? _enrolledPhotoUrl;
  // Debug info
  double? _lastSimilarity;
  Size? _lastFaceBoxSize;
  // Relative face box position (percent of image) and size
  double? _lastFaceBoxCenterX;
  double? _lastFaceBoxCenterY;
  double? _lastFaceBoxWidthPct;
  double? _lastFaceBoxHeightPct;
  bool _isMatching = false; // New variable to track matching state
  // Matching parameters
  final double _matchThreshold = 60.0; // primary acceptance threshold (easier)
  final double _matchTolerance = 10.0; // accept within +/- this value
  final double _autoStopThreshold = 85.0; // auto-stop detection at this confidence
  // Recent similarity history to allow small temporal variance matching
  final List<double> _recentSimilarities = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _initializeCamera();
  }

  Future<void> _loadCurrentUser() async {
    final empId = await AuthService.getEmpId();
    if (empId != null) {
      // Get only the latest active enrolled face
      final active =
          await DatabaseHelper.instance.getActiveFaceEnrollment(empId);
      if (active != null && active['face_descriptors'] != null) {
        // Handle Blob, Uint8List, or String for face_descriptors
        var descriptors = active['face_descriptors'];
        if (descriptors is! String) {
          try {
            print('[DEBUG] Blob runtimeType: ' +
                descriptors.runtimeType.toString());
            print('[DEBUG] Blob toString: ' + descriptors.toString());
            // Ensure Blob's toString() is a valid JSON array string
            var descStr = descriptors.toString();
            if (descStr.startsWith('[')) {
              descriptors = descStr;
            } else {
              descriptors = '[${descStr}]';
            }
          } catch (e) {
            print('[ERROR] Failed to convert face_descriptors to String: $e');
            descriptors = '';
          }
        }
        _currentUser = Employee(
          empId: empId,
          surname: '',
          firstName: '',
          faceDescriptors: descriptors,
        );
        // Set the enrolled photo URL if available
        print('[DEBUG] Enrolled photo_path: ${active['photo_path']}');
        if (active['photo_path'] != null &&
            active['photo_path'].toString().isNotEmpty) {
          // If photo_path is a relative path, prepend your server URL if needed
          _enrolledPhotoUrl = active['photo_path'];
        } else {
          _enrolledPhotoUrl = null;
        }
        print('Loaded current user with latest enrolled face.');
      } else {
        _currentUser = null;
        _enrolledPhotoUrl = null;
        print('No active enrolled face for current user.');
      }
    } else {
      _enrolledPhotoUrl = null;
    }
  }

  Future<void> _initializeCamera() async {
    print('[TimeInOut] Initializing camera...');
    try {
      // Always reload the latest enrolled face before starting camera
      await _loadCurrentUser();
    } catch (e) {
      print('[TimeInOut] Error loading user: $e');
    }

    try {
      // Initialize cameras if not already done
      if (cameras.isEmpty) {
        try {
          cameras = await availableCameras();
        } catch (e) {
          print('[TimeInOut] Error loading cameras: $e');
          if (mounted) {
            setState(() {
              _statusMessage = 'Camera not available';
            });
          }
          return;
        }
      }

      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = 'No camera available';
          });
        }
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
      print('[TimeInOut] Camera initialized!');

      if (mounted) {
        setState(() {});
        _startFaceDetection();
      }
    } catch (e) {
      print('[TimeInOut] Camera initialization failed: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Failed to initialize camera.';
        });
      }
    }
  }

  void _startFaceDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _cameraController!.startImageStream((image) async {
      if (_isProcessing ||
          _isConfirmed ||
          _showSuccess ||
          _recognizedEmployee != null) return;

      _isProcessing = true;
      _isMatching = true;

      await _loadCurrentUser();

      if (_currentUser == null) {
        _isProcessing = false;
        _isMatching = false;
        return;
      }

      try {
        // pass the camera sensor orientation so ML Kit can rotate image correctly
        final rotation = _cameraController?.description.sensorOrientation ?? 0;
        final faces = await _faceService.detectFaces(image, rotation: rotation);
        print('[TimeInOut] detectFaces returned ${faces.length} faces');

        if (faces.isNotEmpty) {
          final face = faces.first;
          print('[TimeInOut] face bbox: ${face.boundingBox.width}x${face.boundingBox.height}');
          final faceBox = face.boundingBox;
          // compute relative positions based on the camera image dimensions
          final imgW = image.width.toDouble();
          final imgH = image.height.toDouble();
          final centerX = (faceBox.center.dx) / imgW;
          final centerY = (faceBox.center.dy) / imgH;
          final widthPct = faceBox.width / imgW;
          final heightPct = faceBox.height / imgH;
          setState(() {
            _lastFaceBoxSize = Size(faceBox.width, faceBox.height);
            _lastFaceBoxCenterX = centerX;
            _lastFaceBoxCenterY = centerY;
            _lastFaceBoxWidthPct = widthPct;
            _lastFaceBoxHeightPct = heightPct;
          });
          final descriptors = _faceService.extractFaceDescriptors(face);
          print('[TimeInOut] extracted descriptors: ${descriptors?.toString() ?? 'null'}');

          if (descriptors != null) {
            await _matchFace(descriptors);
            // If matched, stop detection
            if (_recognizedEmployee != null) {
              await _cameraController?.stopImageStream();
              // Time In/Out buttons will always be displayed
              return;
            }
          } else {
            if (mounted) {
              setState(() {
                _statusMessage = 'Face too small or unclear';
                _recognizedEmployee = null;
                _lastSimilarity = null;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _statusMessage = 'No face detected';
              _recognizedEmployee = null;
              _lastFaceBoxSize = null;
              _lastSimilarity = null;
            });
          }
          // clear recent similarities when no face is present
          _recentSimilarities.clear();
        }
      } catch (e) {
        print('Error in face detection: $e');
      }

      _isProcessing = false;
      _isMatching = false;
    });
  }

  Future<void> _matchFace(String descriptors) async {
    // Debug: print enrolled and detected descriptors
    print('[DEBUG] Enrolled descriptors: ${_currentUser?.faceDescriptors}');
    print('[DEBUG] Detected descriptors: $descriptors');

    if (_currentUser == null ||
        _currentUser?.faceDescriptors == null ||
        (_currentUser?.faceDescriptors ?? '').isEmpty) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'No enrolled face found. Please enroll your face in the Profile tab.';
          _lastSimilarity = null;
        });
      }
      print('[ERROR] No enrolled face descriptors found.');
      return;
    }

    double similarity = 0.0;
    try {
      similarity = _faceService.compareFaces(
        descriptors,
        _currentUser?.faceDescriptors,
      );
      print('[TimeInOut] _matchFace: similarity=$similarity');
      // record recent similarities
      _recentSimilarities.add(similarity);
      if (_recentSimilarities.length > 6) _recentSimilarities.removeAt(0);
    } catch (e) {
      print('[ERROR] _matchFace exception: $e');
      if (mounted) {
        setState(() {
          _statusMessage =
              'Face data corrupted or invalid. Please re-enroll your face in the Profile tab.';
          _recognizedEmployee = null;
          _lastSimilarity = null;
        });
      }
      return;
    }

    if (mounted) {
      // Update similarity and basic status first
      setState(() {
        _lastSimilarity = similarity;
        // Accept match if similarity meets threshold OR is within tolerance
        // of any recent confirmed similarity (handles small temporal variance)
        final double effectiveThreshold = _matchThreshold;
        final bool matched = (similarity >= effectiveThreshold) ||
          _recentSimilarities.any((s) =>
            s >= effectiveThreshold && (s - similarity).abs() <= _matchTolerance);

        if (matched) {
          _recognizedEmployee = _currentUser;
          _statusMessage =
              '${_currentUser?.surname ?? 'User'}\nMatch: ${similarity.toStringAsFixed(1)}%';
        } else {
          _recognizedEmployee = null;
          // More explicit feedback for user
          String suggestion = '';
          if (_lastFaceBoxSize != null &&
              (_lastFaceBoxSize!.width < 100 ||
                  _lastFaceBoxSize!.height < 100)) {
            suggestion = '\nFace too small: Move closer to the camera.';
          } else {
            suggestion =
                '\nTry better lighting, center your face, or re-enroll.';
          }
            _statusMessage = 'Face not matched (${similarity.toStringAsFixed(1)}%)' +
              suggestion;
          print('[DEBUG] Face not matched. Similarity: $similarity');
        }
      });

      // If very high confidence, stop detection automatically (outside setState)
      if (similarity >= _autoStopThreshold) {
        try {
          await _cameraController?.stopImageStream();
        } catch (_) {}
        if (mounted) {
          setState(() {
            _showSuccess = true;
            _statusMessage =
                '${_currentUser?.surname ?? 'User'}\nHigh confidence match: ${similarity.toStringAsFixed(1)}%';
          });
        }
      }
    }
  }

  Future<void> _recordAttendance(String action) async {
    if (_recognizedEmployee == null) {
      _showSnackBar('No employee recognized');
      return;
    }

    final now = DateTime.now();
    final dbDateFormat = DateFormat('yyyy-MM-dd');
    final dbTimeFormat = DateFormat('HH:mm:ss');
    final displayDateFormat = DateFormat('MM/dd/yyyy');
    final displayTimeFormat = DateFormat('h:mm a');

    // state: 1 = IN, 0 = OUT
    final String state = action == 'IN' ? '1' : '0';

    final record = LoginRecord(
      empId: _recognizedEmployee?.empId ?? 0,
      time: dbTimeFormat.format(now),
      date: dbDateFormat.format(now),
      state: state,
      loginStatus: 'Face Recognition',
    );

    await DatabaseHelper.instance.createLoginRecord(record);

    final label = action == 'IN' ? 'TIME IN' : 'TIME OUT';
    setState(() {
      _showSuccess = true;
      _statusMessage =
          '$label recorded!\n${_recognizedEmployee?.fullName ?? 'Unknown'}\n${displayDateFormat.format(now)} ${displayTimeFormat.format(now)}';
    });

    // Stop the camera stream after attendance is recorded
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 2));

    // Navigate to AttendanceHistoryScreen
    if (mounted && _recognizedEmployee != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              AttendanceHistoryScreen(empId: _recognizedEmployee!.empId),
        ),
      );
    }
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
        title: const Text('Time In / Time Out'),
        centerTitle: true,
      ),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final availableHeight = constraints.maxHeight;
                final cameraHeight = availableHeight * 0.6;
                final double previewW = 320.0;
                final double previewH = cameraHeight > 480 ? 430 : cameraHeight;

                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: availableHeight,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Center(
                              child: Container(
                                width: 320,
                                height: cameraHeight > 480 ? 430 : cameraHeight,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SizedBox(
                                        width: previewW,
                                        height: previewH,
                                        child: FittedBox(
                                          fit: BoxFit.cover,
                                          child: SizedBox(
                                            width: _cameraController!.value.previewSize?.height ?? previewW,
                                            height: _cameraController!.value.previewSize?.width ?? previewH,
                                            child: CameraPreview(_cameraController!),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Face frame overlay that follows detected face
                                    if (_lastFaceBoxCenterX != null &&
                                        _lastFaceBoxWidthPct != null &&
                                        _lastFaceBoxHeightPct != null)
                                      Positioned(
                                        left: (() {
                                          // enlarge box slightly and clamp
                                          final scale = 1.25;
                                          final minBox = 60.0;
                                          final rawW = _lastFaceBoxWidthPct! * previewW * scale;
                                          final boxW = rawW < minBox ? minBox : rawW;
                                          double left = _lastFaceBoxCenterX! * previewW - boxW / 2;
                                          if (left < 0) left = 0;
                                          if (left + boxW > previewW) left = previewW - boxW;
                                          return left;
                                        }()),
                                        top: (() {
                                          final scale = 1.25;
                                          final minBox = 60.0;
                                          final rawH = _lastFaceBoxHeightPct! * previewH * scale;
                                          final boxH = rawH < minBox ? minBox : rawH;
                                          double top = _lastFaceBoxCenterY! * previewH - boxH / 2;
                                          if (top < 0) top = 0;
                                          if (top + boxH > previewH) top = previewH - boxH;
                                          return top;
                                        }()),
                                        child: Container(
                                          width: (_lastFaceBoxWidthPct! * previewW * 1.25).clamp(60.0, previewW),
                                          height: (_lastFaceBoxHeightPct! * previewH * 1.25).clamp(60.0, previewH),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: _recognizedEmployee != null
                                                  ? Colors.green
                                                  : Colors.white,
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.zero,
                                          ),
                                        ),
                                      ),

                                    // Instructions overlay
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
                                              _recognizedEmployee != null
                                                  ? Icons.check_circle
                                                  : Icons.face,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _statusMessage,
                                              style: const TextStyle(color: Colors.white),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                                          // (removed on-screen debug info)
                          // Show matching progress if running and not matched
                          if (_isMatching && _recognizedEmployee == null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 8.0, bottom: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Detecting face...')
                                ],
                              ),
                            ),
                          Container(
                            width: double.infinity,
                            constraints: BoxConstraints(
                              maxHeight: 140,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            color: _showSuccess ? Colors.green : Colors.white,
                            child: SafeArea(
                              top: false,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showSuccess
                                        ? Icons.check_circle
                                        : _recognizedEmployee != null
                                            ? Icons.face
                                            : Icons.face_retouching_natural,
                                    size: 30,
                                    color: _showSuccess
                                        ? Colors.white
                                        : _recognizedEmployee != null
                                            ? Colors.green
                                            : Colors.grey,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _statusMessage,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _showSuccess
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  if ((_recognizedEmployee != null ||
                                          (_lastSimilarity != null &&
                                              _lastSimilarity! >=
                                                  (_matchThreshold -
                                                      _matchTolerance))) &&
                                      !_showSuccess)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            // allow recording on borderline match by assigning currentUser
                                            if (_recognizedEmployee == null &&
                                                _lastSimilarity != null &&
                                                _lastSimilarity! >=
                                                    (_matchThreshold -
                                                        _matchTolerance)) {
                                              _recognizedEmployee = _currentUser;
                                              setState(() {});
                                            }
                                            await _recordAttendance('IN');
                                          },
                                          icon:
                                              const Icon(Icons.login, size: 16),
                                          label: const Text('TIME IN',
                                              style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 8),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            if (_recognizedEmployee == null &&
                                                _lastSimilarity != null &&
                                                _lastSimilarity! >=
                                                    (_matchThreshold -
                                                        _matchTolerance)) {
                                              _recognizedEmployee = _currentUser;
                                              setState(() {});
                                            }
                                            await _recordAttendance('OUT');
                                          },
                                          icon: const Icon(Icons.logout,
                                              size: 16),
                                          label: const Text('TIME OUT',
                                              style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 8),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
  }
}
