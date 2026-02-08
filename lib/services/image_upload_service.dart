import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import '../config/database_config.dart';

class ImageUploadService {
  final Dio _dio = Dio();

  ImageUploadService() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// Upload an image file to the server
  /// Returns the file path/URL on success, null on failure
  Future<String?> uploadImage({
    required File imageFile,
    required int empId,
    String? customFileName,
  }) async {
    try {
      // Generate filename: empId_timestamp.jpg
      String fileName = customFileName ?? 
          'emp_${empId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Create form data
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
        'emp_id': empId.toString(),
        'folder': ServerConfig.uploadFolder,
      });

      print('📤 Uploading image to ${ServerConfig.uploadUrl}');

      // Upload the file
      Response response = await _dio.post(
        ServerConfig.uploadUrl,
        data: formData,
        onSendProgress: (sent, total) {
          print('Upload progress: ${(sent / total * 100).toStringAsFixed(0)}%');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Extract file path from response
        String filePath = response.data['filePath'] ?? 
                         response.data['file_path'] ??
                         response.data['path'] ??
                         '${ServerConfig.uploadFolder}/$fileName';
        
        print('✅ Image uploaded successfully: $filePath');
        return filePath;
      } else {
        print('❌ Upload failed with status: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('❌ Upload error: ${e.message}');
      if (e.response != null) {
        print('Response data: ${e.response?.data}');
        print('Response status: ${e.response?.statusCode}');
      }
      return null;
    } catch (e) {
      print('❌ Unexpected error during upload: $e');
      return null;
    }
  }

  /// Get the full URL for an uploaded image
  String getImageUrl(String? filePath) {
    if (filePath == null || filePath.isEmpty) {
      return '';
    }
    
    // If already a full URL, return as is
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    
    // Build full URL
    return '${ServerConfig.baseUrl}/$filePath';
  }

  /// Delete an image from the server
  Future<bool> deleteImage(String filePath) async {
    try {
      final deleteUrl = '${ServerConfig.protocol}://${ServerConfig.host}:${ServerConfig.port}/api/punchgo/delete';
      
      Response response = await _dio.delete(
        deleteUrl,
        data: {'filePath': filePath},
      );

      if (response.statusCode == 200) {
        print('✅ Image deleted successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }

  /// Test server connection
  Future<bool> testConnection() async {
    try {
      final testUrl = '${ServerConfig.protocol}://${ServerConfig.host}:${ServerConfig.port}/api/ping';
      Response response = await _dio.get(testUrl);
      return response.statusCode == 200;
    } catch (e) {
      print('Server connection test failed: $e');
      return false;
    }
  }
}
