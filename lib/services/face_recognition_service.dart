import 'dart:convert';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Size;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceQualityMetrics {
  final double overallQuality;
  final double lightingQuality;
  final double angleQuality;
  final double faceSizeQuality;
  final double sharpnessQuality;
  final bool isQualitySufficient;

  FaceQualityMetrics({
    required this.overallQuality,
    required this.lightingQuality,
    required this.angleQuality,
    required this.faceSizeQuality,
    required this.sharpnessQuality,
    required this.isQualitySufficient,
  });

  @override
  String toString() =>
      'Quality: ${overallQuality.toStringAsFixed(1)}% | Lighting: ${lightingQuality.toStringAsFixed(1)}% | Angle: ${angleQuality.toStringAsFixed(1)}% | Size: ${faceSizeQuality.toStringAsFixed(1)}% | Sharpness: ${sharpnessQuality.toStringAsFixed(1)}%';
}

class FaceRecognitionService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      // allow smaller faces to be detected on some devices
      minFaceSize: 0.15,
    ),
  );

  Future<List<Face>> detectFaces(CameraImage image, {int rotation = 0}) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final InputImageRotation imageRotation = _rotationToInputImageRotation(rotation);

    final InputImageFormat inputImageFormat = InputImageFormat.yuv420;

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );

    final faces = await _faceDetector.processImage(inputImage);
    return faces;
  }

  // Extract face descriptors using normalized ratios
  String? extractFaceDescriptors(Face face) {
    if (face.landmarks.isEmpty) return null;

    // Require minimum bounding box size to avoid false detections
    // Lowered threshold to be more permissive for smaller faces on some devices
    if (face.boundingBox.width < 30 || face.boundingBox.height < 30)
      return null;

    List<double> descriptors = [];

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final noseBase = face.landmarks[FaceLandmarkType.noseBase];
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth];
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth];
    final bottomMouth = face.landmarks[FaceLandmarkType.bottomMouth];
    final leftEar = face.landmarks[FaceLandmarkType.leftEar];
    final rightEar = face.landmarks[FaceLandmarkType.rightEar];
    final leftCheek = face.landmarks[FaceLandmarkType.leftCheek];
    final rightCheek = face.landmarks[FaceLandmarkType.rightCheek];

    if (leftEye != null && rightEye != null && noseBase != null) {
      final eyeDistance = _distance(leftEye.position, rightEye.position);

      // Skip if eye distance too small (not a real face)
      if (eyeDistance < 20) return null;

      // Use RATIOS normalized by eye distance (scale-invariant)
      final noseToLeftEye =
          _distance(noseBase.position, leftEye.position) / eyeDistance;
      final noseToRightEye =
          _distance(noseBase.position, rightEye.position) / eyeDistance;
      final faceWidthRatio = face.boundingBox.width / eyeDistance;
      final faceHeightRatio = face.boundingBox.height / eyeDistance;
      final faceAspectRatio = face.boundingBox.width / face.boundingBox.height;

      descriptors.addAll([
        noseToLeftEye,
        noseToRightEye,
        faceWidthRatio,
        faceHeightRatio,
        faceAspectRatio,
      ]);

      if (leftMouth != null && rightMouth != null) {
        descriptors.add(
            _distance(leftMouth.position, rightMouth.position) / eyeDistance);
        descriptors
            .add(_distance(leftMouth.position, leftEye.position) / eyeDistance);
        descriptors.add(
            _distance(rightMouth.position, rightEye.position) / eyeDistance);
      }

      if (bottomMouth != null) {
        descriptors.add(
            _distance(bottomMouth.position, noseBase.position) / eyeDistance);
      }

      if (leftEar != null && rightEar != null) {
        descriptors
            .add(_distance(leftEar.position, rightEar.position) / eyeDistance);
      }

      if (leftCheek != null && rightCheek != null) {
        descriptors.add(
            _distance(leftCheek.position, rightCheek.position) / eyeDistance);
        descriptors.add(
            _distance(leftCheek.position, noseBase.position) / eyeDistance);
        descriptors.add(
            _distance(rightCheek.position, noseBase.position) / eyeDistance);
      }

      return jsonEncode(descriptors);
    }

    return null;
  }

  // Compare two face descriptors with EXTREMELY STRICT matching
  double compareFaces(String? descriptors1, String? descriptors2) {
    if (descriptors1 == null || descriptors2 == null || descriptors1.isEmpty || descriptors2.isEmpty) {
      return 0.0;
    }

    try {
      List<double> desc1 = List<double>.from(jsonDecode(descriptors1));
      List<double> desc2 = List<double>.from(jsonDecode(descriptors2));

      if (desc1.length != desc2.length || desc1.length < 6) {
        return 0.0;
      }

      // EXTREMELY STRICT: Penalize ANY difference heavily
      final int n = desc1.length;
      
      double totalAbsDiff = 0.0;
      int deviationCount = 0;
      
      for (int i = 0; i < n; i++) {
        final double absDiff = (desc1[i] - desc2[i]).abs();
        totalAbsDiff += absDiff;
        if (absDiff > 0.2) deviationCount++; // Even small deviations count
      }
      
      // Average difference per feature
      double avgDiff = totalAbsDiff / n;
      
      // EXTREMELY STRICT tiers - different faces should not score high
      // Perfect match = avgDiff ~0.02-0.04, other faces = avgDiff ~0.12-0.18
      double similarity;
      if (avgDiff < 0.04) {
        similarity = 98.0; // Nearly identical (enrolled face)
      } else if (avgDiff < 0.06) {
        similarity = 90.0; // Very close (same person, different angle)
      } else if (avgDiff < 0.08) {
        similarity = 82.0; // Close but some variance
      } else if (avgDiff < 0.1) {
        similarity = 72.0; // Moderate similarity
      } else if (avgDiff < 0.12) {
        similarity = 60.0; // Getting different
      } else if (avgDiff < 0.15) {
        similarity = 45.0; // Different face
      } else if (avgDiff < 0.2) {
        similarity = 30.0; // Very different
      } else {
        similarity = 10.0; // Completely different
      }
      
      // Heavy penalty for multiple deviations >0.2 (suspicious differences)
      similarity -= (deviationCount * 3.0);
      
      // 🚨 DEBUG: Show detailed comparison
      print('[COMPARE] avgDiff: ${avgDiff.toStringAsFixed(4)}, deviations>0.2: $deviationCount, similarity: ${similarity.toStringAsFixed(1)}%');
      if (avgDiff > 0.08) {
        // For suspicious matches, show feature-by-feature breakdown
        print('[COMPARE] Feature breakdown (enrolled vs current):');
        for (int i = 0; i < n; i++) {
          final double diff = (desc1[i] - desc2[i]).abs();
          if (diff > 0.08) {
            print('  Feature $i: enrolled=${desc1[i].toStringAsFixed(3)}, current=${desc2[i].toStringAsFixed(3)}, diff=${diff.toStringAsFixed(3)} ⚠️');
          }
        }
      }
      
      return similarity.clamp(0, 100).toDouble();
    } catch (e) {
      print('Error comparing faces: $e');
      return 0.0;
    }
  }

  double _distance(Point<int> p1, Point<int> p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  /// Assess face quality metrics (like modern phone face unlock)
  FaceQualityMetrics assessFaceQuality(Face face, CameraImage image) {
    // 1. Face Size Quality (40-60% of image width is ideal)
    final faceWidthRatio = face.boundingBox.width / image.width;
    double faceSizeQuality = 0.0;
    if (faceWidthRatio >= 0.4 && faceWidthRatio <= 0.6) {
      faceSizeQuality = 100;
    } else if (faceWidthRatio >= 0.3 && faceWidthRatio <= 0.7) {
      faceSizeQuality = 80 - (faceWidthRatio < 0.4 ? (0.4 - faceWidthRatio) * 200 : (faceWidthRatio - 0.6) * 200);
    } else if (faceWidthRatio >= 0.15 && faceWidthRatio <= 0.8) {
      faceSizeQuality = 50 - (faceWidthRatio < 0.3 ? (0.3 - faceWidthRatio) * 100 : (faceWidthRatio - 0.7) * 100);
    } else {
      faceSizeQuality = 20;
    }
    faceSizeQuality = faceSizeQuality.clamp(0, 100);

    // 2. Angle Quality (frontal face is best)
    double angleQuality = 100.0;
    if (face.headEulerAngleY != null && face.headEulerAngleZ != null) {
      final yawAngle = (face.headEulerAngleY ?? 0).abs();
      final rollAngle = (face.headEulerAngleZ ?? 0).abs();
      
      // Penalize large angles
      if (yawAngle > 30 || rollAngle > 30) angleQuality = 50;
      else if (yawAngle > 20 || rollAngle > 20) angleQuality = 70;
      else if (yawAngle > 10 || rollAngle > 10) angleQuality = 85;
    }

    // 3. Lighting Quality (based on landmarks visibility)
    double lightingQuality = 100.0;
    int visibleLandmarks = face.landmarks.length;
    if (visibleLandmarks < 5) lightingQuality = 50;
    else if (visibleLandmarks < 8) lightingQuality = 70;
    else if (visibleLandmarks < 10) lightingQuality = 85;

    // 4. Sharpness Quality (estimated from landmark spread/contrast)
    double sharpnessQuality = 95.0; // Assume good unless proven otherwise
    if (face.landmarks.isEmpty) {
      sharpnessQuality = 40;
    } else {
      // More landmarks = sharper image
      sharpnessQuality = min(100, 70 + (visibleLandmarks * 3.0));
    }

    // Calculate overall quality as weighted average
    double overallQuality = (faceSizeQuality * 0.35 + 
                            angleQuality * 0.25 + 
                            lightingQuality * 0.25 + 
                            sharpnessQuality * 0.15);

    bool isSufficient = overallQuality >= 70; // 70% threshold

    return FaceQualityMetrics(
      overallQuality: overallQuality,
      lightingQuality: lightingQuality,
      angleQuality: angleQuality,
      faceSizeQuality: faceSizeQuality,
      sharpnessQuality: sharpnessQuality,
      isQualitySufficient: isSufficient,
    );
  }

  /// Compare against multiple samples (phone-like matching) - EXTREMELY STRICT
  double compareAgainstMultipleSamples(String currentDescriptors, List<String> enrolledDescriptorsList) {
    if (enrolledDescriptorsList.isEmpty) return 0.0;
    
    // Get best match from all samples
    double bestSimilarity = 0.0;
    for (String enrolled in enrolledDescriptorsList) {
      double similarity = compareFaces(currentDescriptors, enrolled);
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
      }
    }
    
    // No bonus - just use best match score directly
    // Each sample must stand on its own merit
    return bestSimilarity.clamp(0, 100);
  }

  InputImageRotation _rotationToInputImageRotation(int rotation) {
    // Normalize rotation to 0/90/180/270
    final r = ((rotation % 360) + 360) % 360;
    switch (r) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
