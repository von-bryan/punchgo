import 'dart:convert';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Size;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

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

  // Compare two face descriptors
  double compareFaces(String? descriptors1, String? descriptors2) {
    if (descriptors1 == null || descriptors2 == null) return 0.0;

    try {
      List<double> desc1 = List<double>.from(jsonDecode(descriptors1));
      List<double> desc2 = List<double>.from(jsonDecode(descriptors2));

      if (desc1.length != desc2.length || desc1.length < 6) {
        print('[FaceRecognition] Descriptor length mismatch or too short: desc1=${desc1.length}, desc2=${desc2.length}');
        print('[FaceRecognition] desc1 sample: ${desc1.length>0?desc1.sublist(0,min(8,desc1.length)).toString():desc1}');
        print('[FaceRecognition] desc2 sample: ${desc2.length>0?desc2.sublist(0,min(8,desc2.length)).toString():desc2}');
        return 0.0;
      }

      // Weighted Euclidean distance with emphasis on primary facial ratios
      final int n = desc1.length;
      List<double> weights = List<double>.filled(n, 1.0);
      // Heavier weights for nose/eye/face-size/aspect (indices 0..4)
      for (int i = 0; i < min(5, n); i++) weights[i] = 3.0;

      double sum = 0.0;
      for (int i = 0; i < n; i++) {
        final double d = desc1[i] - desc2[i];
        sum += weights[i] * d * d;
      }
      double distance = sqrt(sum);

      // Log per-index diffs for first few descriptors to aid debugging
      final int debugCount = min(8, n);
      List<String> diffs = [];
      for (int i = 0; i < debugCount; i++) {
        diffs.add('${i}:${(desc1[i] - desc2[i]).abs().toStringAsFixed(4)}');
      }
      print('[FaceRecognition] per-index diffs (first $debugCount): ${diffs.join(', ')}');

      // Primary-feature average absolute difference (indices 0..2: nose/eye ratios)
      double primaryAvg = 0.0;
      int primaryCount = min(3, n);
      for (int i = 0; i < primaryCount; i++) {
        primaryAvg += (desc1[i] - desc2[i]).abs();
      }
      primaryAvg = primaryCount > 0 ? primaryAvg / primaryCount : 0.0;

      // Allow larger primaryAvg differences but log for debugging; apply softer rejection
      // Increase cutoff so small pose/scale differences don't immediately fail
      final double primaryCutoff = 0.25;
      if (primaryAvg > primaryCutoff) {
        print('[FaceRecognition] primaryAvg=$primaryAvg > $primaryCutoff (soft reject)');
        // apply a strong penalty by inflating distance instead of outright rejecting
        distance += primaryAvg * 10.0;
      }

      // Map weighted distance to similarity
      // Scale: expected distances vary with weights; use an empirical divisor
      double maxExpectedDistance = sqrt(weights.reduce((a, b) => a + b)) * 0.6;
      if (distance > maxExpectedDistance * 2.0) {
        print(
            '[FaceRecognition] compareFaces: distance=$distance > cutoff -> similarity=0');
        return 0.0;
      }

        double rawSimilarity = max(0, 100 - (distance / maxExpectedDistance * 100));

      // Penalties for individual primary descriptor deviations
      double penalty = 0.0;
      for (int i = 0; i < min(5, n); i++) {
        double diff = (desc1[i] - desc2[i]).abs();
        if (diff > 0.15)
          penalty += 12.0;
        else if (diff > 0.10)
          penalty += 6.0;
      }

      double similarity = (rawSimilarity - penalty).clamp(0, 100);
      similarity = pow(similarity / 100.0, 1.06) * 100.0; // slight curve

      print(
          '[FaceRecognition] compareFaces: distance=${distance.toStringAsFixed(3)}, raw=${rawSimilarity.toStringAsFixed(2)}, primaryAvg=${primaryAvg.toStringAsFixed(3)}, penalty=${penalty.toStringAsFixed(2)}, final=${similarity.toStringAsFixed(2)}');
      return similarity.toDouble();
    } catch (e) {
      print('Error comparing faces: $e');
      return 0.0;
    }
  }

  double _distance(Point<int> p1, Point<int> p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
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
