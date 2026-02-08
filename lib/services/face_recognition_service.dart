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

  // Compare two face descriptors with STRICT matching
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

      // STRICT APPROACH: Use equal weights, penalize differences heavily
      final int n = desc1.length;
      
      double sum = 0.0;
      double maxDiff = 0.0;
      int largeDeviations = 0;
      
      for (int i = 0; i < n; i++) {
        final double d = desc1[i] - desc2[i];
        sum += d * d;
        final double absDiff = d.abs();
        if (absDiff > maxDiff) maxDiff = absDiff;
        if (absDiff > 0.4) largeDeviations++; // Count large differences
      }
      
      double distance = sqrt(sum);
      
      // MUCH stricter: higher multiplier means high distance = very low similarity
      double rawSimilarity = max(0, 100 - (distance * 20)); // Increased from 8 to 20
      
      // STRICT penalties for deviations
      double penalty = 0.0;
      penalty += largeDeviations * 5.0; // Heavy penalty for each large deviation
      if (maxDiff > 0.8) penalty += 15.0; // Extra penalty if any diff is very large
      
      double similarity = (rawSimilarity - penalty).clamp(0, 100);
      
      return similarity.toDouble();
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

  /// Compare against multiple samples (phone-like matching) - STRICT
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
    
    // Only boost if we have multiple VERY GOOD matches (80%+)
    int veryGoodMatches = enrolledDescriptorsList.fold<int>(
      0,
      (count, enrolled) => compareFaces(currentDescriptors, enrolled) > 80 ? count + 1 : count,
    );
    
    // Minimal bonus - only if multiple samples match
    double bonus = veryGoodMatches > 1 ? 5.0 : 0.0; // Only 5% bonus for multiple matches
    double finalScore = (bestSimilarity + bonus).clamp(0, 100);
    
    return finalScore;
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
