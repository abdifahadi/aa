import 'dart:io';


import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../utils/constants.dart';

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  Directory? _cacheDirectory;
  bool _isInitialized = false;

  // Initialize the cache service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _cacheDirectory = await getTemporaryDirectory();
      final mediaCacheDir = Directory('${_cacheDirectory!.path}/media_cache');
      
      if (!await mediaCacheDir.exists()) {
        await mediaCacheDir.create(recursive: true);
        debugPrint('📁 Created media cache directory: ${mediaCacheDir.path}');
      }
      
      _cacheDirectory = mediaCacheDir;
      _isInitialized = true;
      
      // Clean up old cache files on initialization
      await _cleanupOldCache();
      
      debugPrint('✅ MediaCacheService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing MediaCacheService: $e');
    }
  }

  // Get cache directory
  Future<Directory> get cacheDirectory async {
    if (!_isInitialized) await initialize();
    return _cacheDirectory!;
  }

  // Generate cache key from URL
  String _generateCacheKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Get cached file path
  Future<String> _getCacheFilePath(String url, String extension) async {
    final dir = await cacheDirectory;
    final key = _generateCacheKey(url);
    return '${dir.path}/$key.$extension';
  }

  // Cache image
  Future<File?> cacheImage(String url, Uint8List imageBytes) async {
    try {
      final extension = _getFileExtension(url) ?? 'jpg';
      final filePath = await _getCacheFilePath(url, extension);
      final file = File(filePath);
      
      await file.writeAsBytes(imageBytes);
      debugPrint('💾 Cached image: ${file.path}');
      
      return file;
    } catch (e) {
      debugPrint('❌ Error caching image: $e');
      return null;
    }
  }

  // Cache video
  Future<File?> cacheVideo(String url, Uint8List videoBytes) async {
    try {
      final extension = _getFileExtension(url) ?? 'mp4';
      final filePath = await _getCacheFilePath(url, extension);
      final file = File(filePath);
      
      await file.writeAsBytes(videoBytes);
      debugPrint('💾 Cached video: ${file.path}');
      
      return file;
    } catch (e) {
      debugPrint('❌ Error caching video: $e');
      return null;
    }
  }

  // Cache audio
  Future<File?> cacheAudio(String url, Uint8List audioBytes) async {
    try {
      final extension = _getFileExtension(url) ?? 'mp3';
      final filePath = await _getCacheFilePath(url, extension);
      final file = File(filePath);
      
      await file.writeAsBytes(audioBytes);
      debugPrint('💾 Cached audio: ${file.path}');
      
      return file;
    } catch (e) {
      debugPrint('❌ Error caching audio: $e');
      return null;
    }
  }

  // Get cached image
  Future<File?> getCachedImage(String url) async {
    try {
      final extension = _getFileExtension(url) ?? 'jpg';
      final filePath = await _getCacheFilePath(url, extension);
      final file = File(filePath);
      
      if (await file.exists()) {
        // Check if file is not too old
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        
        if (age.inDays <= AppConstants.imageCacheMaxAge) {
          debugPrint('📷 Found cached image: ${file.path}');
          return file;
        } else {
          // File is too old, delete it
          await file.delete();
          debugPrint('🗑️ Deleted old cached image: ${file.path}');
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting cached image: $e');
      return null;
    }
  }

  // Get cached video
  Future<File?> getCachedVideo(String url) async {
    try {
      final extension = _getFileExtension(url) ?? 'mp4';
      final filePath = await _getCacheFilePath(url, extension);
      final file = File(filePath);
      
      if (await file.exists()) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        
        if (age.inDays <= AppConstants.videoCacheMaxAge) {
          debugPrint('🎥 Found cached video: ${file.path}');
          return file;
        } else {
          await file.delete();
          debugPrint('🗑️ Deleted old cached video: ${file.path}');
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting cached video: $e');
      return null;
    }
  }

  // Get cached audio
  Future<File?> getCachedAudio(String url) async {
    try {
      final extension = _getFileExtension(url) ?? 'mp3';
      final filePath = await _getCacheFilePath(url, extension);
      final file = File(filePath);
      
      if (await file.exists()) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        
        if (age.inDays <= AppConstants.audioCacheMaxAge) {
          debugPrint('🎵 Found cached audio: ${file.path}');
          return file;
        } else {
          await file.delete();
          debugPrint('🗑️ Deleted old cached audio: ${file.path}');
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting cached audio: $e');
      return null;
    }
  }

  // Clear entire cache
  static Future<void> clearCache() async {
    try {
      final instance = MediaCacheService._instance;
      if (!instance._isInitialized) await instance.initialize();
      
      final dir = await instance.cacheDirectory;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
        debugPrint('🧹 Cleared entire media cache');
      }
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  // Get cache size
  static Future<int> getCacheSize() async {
    try {
      final instance = MediaCacheService._instance;
      if (!instance._isInitialized) await instance.initialize();
      
      final dir = await instance.cacheDirectory;
      if (!await dir.exists()) return 0;
      
      int totalSize = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('❌ Error calculating cache size: $e');
      return 0;
    }
  }

  // Get formatted cache size
  static Future<String> getCacheSizeFormatted() async {
    final size = await getCacheSize();
    return _formatBytes(size);
  }

  // Format bytes to human readable string
  static String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    final i = (log(bytes) / log(1024)).floor();
    final size = bytes / pow(1024, i);
    
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  // Cleanup old cache files
  Future<void> _cleanupOldCache() async {
    try {
      final dir = await cacheDirectory;
      if (!await dir.exists()) return;
      
      int deletedCount = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = DateTime.now().difference(stat.modified);
          
          // Delete files older than the maximum cache age for any type
          final maxAge = [
            AppConstants.imageCacheMaxAge,
            AppConstants.videoCacheMaxAge,
            AppConstants.audioCacheMaxAge,
          ].reduce((a, b) => a > b ? a : b);
          
          if (age.inDays > maxAge) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
      
      if (deletedCount > 0) {
        debugPrint('🧹 Cleaned up $deletedCount old cache files');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning up cache: $e');
    }
  }

  // Get file extension from URL
  String? _getFileExtension(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final lastDot = path.lastIndexOf('.');
      
      if (lastDot != -1 && lastDot < path.length - 1) {
        return path.substring(lastDot + 1).toLowerCase();
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  // Check if cache size exceeds limit
  Future<bool> _shouldCleanupBySize() async {
    final currentSize = await getCacheSize();
    return currentSize > AppConstants.maxCacheSize;
  }

  // Cleanup cache by size (remove oldest files first)
  Future<void> _cleanupBySize() async {
    try {
      final dir = await cacheDirectory;
      if (!await dir.exists()) return;
      
      // Get all files with their modification dates
      final List<MapEntry<File, DateTime>> files = [];
      
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          files.add(MapEntry(entity, stat.modified));
        }
      }
      
      // Sort by modification date (oldest first)
      files.sort((a, b) => a.value.compareTo(b.value));
      
      // Delete files until we're under the size limit
      int deletedCount = 0;
      for (final entry in files) {
        await entry.key.delete();
        deletedCount++;
        
        if (!await _shouldCleanupBySize()) {
          break;
        }
      }
      
      debugPrint('🧹 Cleaned up $deletedCount files due to size limit');
    } catch (e) {
      debugPrint('❌ Error cleaning up cache by size: $e');
    }
  }

  // Periodic cleanup (should be called regularly)
  Future<void> performMaintenance() async {
    await _cleanupOldCache();
    
    if (await _shouldCleanupBySize()) {
      await _cleanupBySize();
    }
  }
}

// Helper function for logarithm (since dart doesn't have it built-in)
double log(num x) => (x as double).log();

// Helper function for power
double pow(num x, num exponent) => (x as double).pow(exponent);

// Extension methods for double
extension DoubleExtensions on double {
  double log() => this <= 0 ? double.negativeInfinity : this.log();
  double pow(num exponent) => this.pow(exponent);
}