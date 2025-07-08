import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../utils/constants.dart';

class CloudinaryService {
  static const String cloudName = AppConstants.cloudinaryCloudName;
  static const String apiKey = AppConstants.cloudinaryApiKey;
  static const String apiSecret = AppConstants.cloudinaryApiSecret;
  static const String baseUrl = 'https://api.cloudinary.com/v1_1';

  // Upload image to Cloudinary
  static Future<String?> uploadImage(File imageFile, {String? folder}) async {
    try {
      final url = '$baseUrl/$cloudName/image/upload';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create signature
      final publicId = 'image_$timestamp';
      final paramsToSign = folder != null 
          ? 'folder=$folder&public_id=$publicId&timestamp=$timestamp'
          : 'public_id=$publicId&timestamp=$timestamp';
      
      final signature = _generateSignature(paramsToSign, apiSecret);
      
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['api_key'] = apiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['signature'] = signature;
      request.fields['public_id'] = publicId;
      
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      // Add upload preset if available
      if (AppConstants.cloudinaryUploadPreset.isNotEmpty) {
        request.fields['upload_preset'] = AppConstants.cloudinaryUploadPreset;
      }
      
      // Add the image file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ));
      
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        return jsonResponse['secure_url'];
      } else {
        print('Cloudinary upload error: $responseData');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  // Upload video to Cloudinary
  static Future<String?> uploadVideo(File videoFile, {String? folder}) async {
    try {
      final url = '$baseUrl/$cloudName/video/upload';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create signature
      final publicId = 'video_$timestamp';
      final paramsToSign = folder != null 
          ? 'folder=$folder&public_id=$publicId&timestamp=$timestamp'
          : 'public_id=$publicId&timestamp=$timestamp';
      
      final signature = _generateSignature(paramsToSign, apiSecret);
      
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['api_key'] = apiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['signature'] = signature;
      request.fields['public_id'] = publicId;
      
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      // Add upload preset if available
      if (AppConstants.cloudinaryUploadPreset.isNotEmpty) {
        request.fields['upload_preset'] = AppConstants.cloudinaryUploadPreset;
      }
      
      // Add the video file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        videoFile.path,
      ));
      
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        return jsonResponse['secure_url'];
      } else {
        print('Cloudinary video upload error: $responseData');
        return null;
      }
    } catch (e) {
      print('Error uploading video to Cloudinary: $e');
      return null;
    }
  }

  // Upload any file to Cloudinary with proper resource type detection
  static Future<String?> uploadFile(File file, {String? folder, String? resourceType}) async {
    try {
      // Detect resource type from file extension if not provided
      String detectedResourceType = resourceType ?? _detectResourceType(file.path);
      
      final url = '$baseUrl/$cloudName/$detectedResourceType/upload';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create signature
      final publicId = '${detectedResourceType}_$timestamp';
      final paramsToSign = folder != null 
          ? 'folder=$folder&public_id=$publicId&timestamp=$timestamp'
          : 'public_id=$publicId&timestamp=$timestamp';
      
      final signature = _generateSignature(paramsToSign, apiSecret);
      
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['api_key'] = apiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['signature'] = signature;
      request.fields['public_id'] = publicId;
      
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      // Add upload preset if available
      if (AppConstants.cloudinaryUploadPreset.isNotEmpty) {
        request.fields['upload_preset'] = AppConstants.cloudinaryUploadPreset;
      }
      
      // Add the file
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
      ));
      
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        return jsonResponse['secure_url'];
      } else {
        print('Cloudinary file upload error: $responseData');
        return null;
      }
    } catch (e) {
      print('Error uploading file to Cloudinary: $e');
      return null;
    }
  }

  // Detect resource type from file extension
  static String _detectResourceType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    
    if (AppConstants.supportedImageFormats.contains(extension)) {
      return 'image';
    } else if (AppConstants.supportedVideoFormats.contains(extension)) {
      return 'video';
    } else if (AppConstants.supportedAudioFormats.contains(extension)) {
      return 'video'; // Cloudinary uses 'video' for audio files
    } else {
      return 'raw'; // For documents and other files
    }
  }

  // Delete resource from Cloudinary
  static Future<bool> deleteResource(String publicId, {String resourceType = 'image'}) async {
    try {
      final url = '$baseUrl/$cloudName/$resourceType/destroy';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      final paramsToSign = 'public_id=$publicId&timestamp=$timestamp';
      final signature = _generateSignature(paramsToSign, apiSecret);
      
      final response = await http.post(
        Uri.parse(url),
        body: {
          'api_key': apiKey,
          'timestamp': timestamp,
          'signature': signature,
          'public_id': publicId,
        },
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['result'] == 'ok';
      } else {
        print('Cloudinary delete error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error deleting from Cloudinary: $e');
      return false;
    }
  }

  // Generate signature for Cloudinary API
  static String _generateSignature(String paramsToSign, String apiSecret) {
    final bytes = utf8.encode('$paramsToSign$apiSecret');
    final digest = sha1.convert(bytes);
    return digest.toString();
  }

  // Get optimized image URL
  static String getOptimizedImageUrl(String originalUrl, {
    int? width,
    int? height,
    String quality = 'auto',
    String format = 'auto',
  }) {
    if (!originalUrl.contains('cloudinary.com')) {
      return originalUrl;
    }
    
    final transformations = <String>[];
    
    if (width != null) transformations.add('w_$width');
    if (height != null) transformations.add('h_$height');
    transformations.add('q_$quality');
    transformations.add('f_$format');
    
    final transformationString = transformations.join(',');
    
    return originalUrl.replaceFirst(
      '/upload/',
      '/upload/$transformationString/',
    );
  }

  // Get thumbnail URL for images
  static String getThumbnailUrl(String originalUrl, {int size = 150}) {
    return getOptimizedImageUrl(
      originalUrl,
      width: size,
      height: size,
      quality: 'auto',
      format: 'auto',
    );
  }

  // Get preview image URL
  static String getPreviewImageUrl(String originalUrl, {int maxWidth = 800}) {
    return getOptimizedImageUrl(
      originalUrl,
      width: maxWidth,
      quality: 'auto',
      format: 'auto',
    );
  }

  // Check if Cloudinary is properly configured
  static bool isConfigured() {
    return cloudName != 'your-cloudinary-cloud-name' &&
           cloudName.isNotEmpty &&
           apiKey != 'your-cloudinary-api-key' &&
           apiKey.isNotEmpty;
  }
}