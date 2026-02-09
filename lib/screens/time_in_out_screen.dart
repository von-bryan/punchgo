import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
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
  Size? _lastFaceBoxSize;
  // Matching parameters - STRICT FOR SECURITY
  final double _matchThreshold = 84.0; // primary acceptance threshold - STRICT: rejects similar faces
  final double _autoStopThreshold = 90.0; // auto-stop detection at this very high confidence
  // Track recent similarities for debugging/logging only (NOT used for matching decision)
  final List<double> _recentSimilarities = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _initializeCamera();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final empId = await AuthService.getEmpId();
      if (empId == null) {
        _currentUser = null;
        return;
      }

      // Try to get LATEST active enrollment only
      final enrollment = await DatabaseHelper.instance.getActiveEnrollment(empId);
      if (enrollment == null) {
        _currentUser = null;
        print('⚠️ No active enrollment found');
        return;
      }

      final enrollmentId = enrollment['face_id'];
      if (enrollmentId == null) {
        _currentUser = null;
        print('⚠️ Enrollment ID is null');
        return;
      }
      
      print('[TimeInOut] Using enrollment ID: $enrollmentId (completed: ${enrollment['is_complete']}, samples: ${enrollment['sample_count']})');

      // Try to get samples from new face_samples table
      try {
        final samples = await DatabaseHelper.instance.getEnrollmentSamples(enrollmentId);
        
        if (samples.isNotEmpty) {
          // New system with multiple samples
          List<String> descriptorsList = [];
          for (int i = 0; i < samples.length; i++) {
            final sample = samples[i];
            
            final desc = sample['face_descriptors'];
            
            if (desc != null && desc is String && desc.isNotEmpty) {
              descriptorsList.add(desc);
            } else if (desc != null) {
              String descStr = desc.toString();
              if (descStr.isNotEmpty && descStr != 'null') {
                descriptorsList.add(descStr);
              }
            }
          }

          if (descriptorsList.isNotEmpty) {
            final joinedDesc = descriptorsList.join('|');
            print('[TimeInOut] ✅ Loaded ${descriptorsList.length} face samples');
            print('[TimeInOut] Sample 1 (first 50 chars): ${descriptorsList[0].length > 50 ? descriptorsList[0].substring(0, 50) : descriptorsList[0]}...');
            _currentUser = Employee(
              empId: empId,
              surname: '',
              firstName: '',
              faceDescriptors: joinedDesc,
            );
            print('✅ Loaded ${descriptorsList.length} face samples for matching');
            return;
          }
        }
      } catch (e) {
        print('[ERROR] Error loading samples: $e');
      }

      // Fallback: Old system with single descriptor in face_enrollments
      var descriptors = enrollment['face_descriptors'];
      
      if (descriptors != null) {
        String descStr = '';
        if (descriptors is String) {
          descStr = descriptors;
        } else {
          try {
            descStr = descriptors.toString();
          } catch (e) {
            print('[ERROR] Failed to convert descriptors: $e');
            descStr = '';
          }
        }

        if (descStr.isNotEmpty && descStr != 'null') {
          _currentUser = Employee(
            empId: empId,
            surname: '',
            firstName: '',
            faceDescriptors: descStr,
          );
          print('✅ Loaded legacy face enrollment for matching');
          return;
        }
      }

      // No valid enrollment found
      _currentUser = null;
      print('⚠️ No valid face enrollment found');
    } catch (e) {
      print('[ERROR] _loadCurrentUser exception: $e');
      _currentUser = null;
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

      await _loadCurrentUser();

      if (_currentUser == null) {
        _isProcessing = false;
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
          setState(() {
            _lastFaceBoxSize = Size(faceBox.width, faceBox.height);
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
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _statusMessage = 'No face detected';
              _recognizedEmployee = null;
              _lastFaceBoxSize = null;
            });
          }
          // clear recent similarities when no face is present
          _recentSimilarities.clear();
        }
      } catch (e) {
        print('Error in face detection: $e');
      }

      _isProcessing = false;
    });
  }

  Future<void> _matchFace(String descriptors) async {
    // STRICT: Validate that we have valid descriptors
    if (descriptors.isEmpty) {
      print('[ERROR] Descriptors are empty');
      return;
    }
    
    if (_currentUser == null ||
        _currentUser?.faceDescriptors == null ||
        (_currentUser?.faceDescriptors ?? '').isEmpty) {
      if (mounted) {
        setState(() {
          _statusMessage =
              'No enrolled face found. Please enroll your face in the Profile tab.';
        });
      }
      print('[ERROR] No enrolled face descriptors found.');
      return;
    }

    double similarity = 0.0;
    try {
      // Split multiple samples (separated by |)
      final String enrolledDescStr = _currentUser?.faceDescriptors ?? '';
      final List<String> enrolledSamples = enrolledDescStr
        .split('|')
        .where((s) => s.isNotEmpty)
        .toList();

      print('[TimeInOut] Comparing against ${enrolledSamples.length} enrolled sample(s)');

      if (enrolledSamples.isEmpty) {
        // Fallback for single sample
        similarity = _faceService.compareFaces(descriptors, enrolledDescStr);
      } else if (enrolledSamples.length == 1) {
        // Single sample - normal comparison
        print('[TimeInOut] Using single sample (first 50 chars): ${enrolledSamples[0].length > 50 ? enrolledSamples[0].substring(0, 50) : enrolledSamples[0]}...');
        similarity = _faceService.compareFaces(descriptors, enrolledSamples[0]);
      } else {
        // Multiple samples - use best match + bonus
        similarity = _faceService.compareAgainstMultipleSamples(descriptors, enrolledSamples);
      }
      
      if (similarity == 0.0) {
        print('[ERROR] Comparison resulted in 0% - invalid descriptors or mismatch');
        if (mounted) {
          setState(() {
            _statusMessage = 'Face quality too poor for matching';
            _recognizedEmployee = null;
          });
        }
        return;
      }
      
      print('[TimeInOut] 🔍 DETAILED MATCH: ${similarity.toStringAsFixed(2)}% (threshold: $_matchThreshold%)\nEnrolled samples: ${enrolledSamples.length}, Current face avg quality: ${(_lastFaceBoxSize?.width ?? 0).toStringAsFixed(0)}px');
      
      // STRICT: Only accept if WELL above threshold - clear history if not matched
      if (similarity < _matchThreshold) {
        _recentSimilarities.clear();
        print('[❌ REJECTED] ${similarity.toStringAsFixed(1)}% < $_matchThreshold% threshold');
      } else {
        print('[✅ ACCEPTED] ${similarity.toStringAsFixed(1)}% >= $_matchThreshold% threshold - MATCH FOUND!');
        _recentSimilarities.add(similarity);
        if (_recentSimilarities.length > 6) _recentSimilarities.removeAt(0);
      }
    } catch (e) {
      print('[ERROR] _matchFace exception: $e');
      if (mounted) {
        setState(() {
          _statusMessage =
              'Face data corrupted or invalid. Please re-enroll your face in the Profile tab.';
          _recognizedEmployee = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        // STRICT: Only accept if current similarity meets threshold
        // Do NOT use temporal variance - each face must be independently verified
        final bool matched = similarity >= _matchThreshold;

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
        }
      });

      // If very high confidence and matched, stop detection automatically
      if (similarity >= _autoStopThreshold && _recognizedEmployee != null) {
        try {
          await _cameraController?.stopImageStream();
        } catch (_) {}
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
                                  ],
                                ),
                              ),
                            ),
                          ),
                                          // Removed on-camera displays per user request
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
                                  if (_recognizedEmployee != null && !_showSuccess)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            // Assign current user if not already set
                                            if (_recognizedEmployee == null && _currentUser != null) {
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
                                            if (_recognizedEmployee == null && _currentUser != null) {
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
