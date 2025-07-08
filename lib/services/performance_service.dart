import 'dart:async';

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../utils/constants.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // Performance metrics
  final Map<String, int> _operationCounts = {};
  final Map<String, List<double>> _operationTimes = {};
  final Map<String, DateTime> _startTimes = {};
  
  // Memory management
  Timer? _memoryCleanupTimer;
  Timer? _performanceMonitorTimer;
  
  // Frame rate monitoring
  FrameCallback? _frameCallback;
  List<Duration> _frameTimes = [];
  int _frameCount = 0;
  DateTime? _lastFrameTime;

  void initialize() {
    if (AppConstants.enablePerformanceLogs) {
      _startPerformanceMonitoring();
      _startMemoryCleanup();
      _startFrameRateMonitoring();
    }
  }

  void dispose() {
    _memoryCleanupTimer?.cancel();
    _performanceMonitorTimer?.cancel();
    if (_frameCallback != null) {
      // Note: There's no removePostFrameCallback method, we just set the callback to null
      _frameCallback = null;
    }
  }

  // Performance tracking methods
  void startOperation(String operationName) {
    if (AppConstants.enablePerformanceLogs) {
      _startTimes[operationName] = DateTime.now();
    }
  }

  void endOperation(String operationName) {
    if (AppConstants.enablePerformanceLogs && _startTimes.containsKey(operationName)) {
      final startTime = _startTimes[operationName]!;
      final duration = DateTime.now().difference(startTime).inMicroseconds / 1000.0; // milliseconds
      
      _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;
      _operationTimes[operationName] = (_operationTimes[operationName] ?? [])..add(duration);
      
      // Keep only recent measurements to prevent memory bloat
      if (_operationTimes[operationName]!.length > 100) {
        _operationTimes[operationName]!.removeAt(0);
      }
      
      _startTimes.remove(operationName);
      
      // Log slow operations
      if (duration > 100) { // More than 100ms
        developer.log(
          'Slow operation detected: $operationName took ${duration.toStringAsFixed(2)}ms',
          name: AppConstants.debugTag,
        );
      }
    }
  }

  // Image optimization
  Future<Uint8List> optimizeImage(Uint8List imageBytes, {
    int? maxWidth,
    int? maxHeight,
    int quality = AppConstants.imageCompressionQuality,
  }) async {
    startOperation('image_optimization');
    
    try {
      // Use compute for CPU-intensive image processing
      final optimizedBytes = await compute(_processImageInIsolate, {
        'imageBytes': imageBytes,
        'maxWidth': maxWidth ?? AppConstants.previewImageSize,
        'maxHeight': maxHeight ?? AppConstants.previewImageSize,
        'quality': quality,
      });
      
      endOperation('image_optimization');
      return optimizedBytes;
    } catch (e) {
      endOperation('image_optimization');
      rethrow;
    }
  }

  static Future<Uint8List> _processImageInIsolate(Map<String, dynamic> params) async {
    // This would typically use image processing libraries
    // For now, returning the original bytes as placeholder
    return params['imageBytes'] as Uint8List;
  }

  // Memory management
  void _startMemoryCleanup() {
    _memoryCleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performMemoryCleanup();
    });
  }

  void _performMemoryCleanup() {
    startOperation('memory_cleanup');
    
    // Force garbage collection
    if (!kReleaseMode) {
      developer.log('Performing memory cleanup', name: AppConstants.debugTag);
    }
    
    // Clear old performance metrics
    _operationTimes.forEach((key, value) {
      if (value.length > 50) {
        value.removeRange(0, value.length - 50);
      }
    });
    
    // Clear old frame times
    if (_frameTimes.length > 60) { // Keep last 60 frames
      _frameTimes.removeRange(0, _frameTimes.length - 60);
    }
    
    endOperation('memory_cleanup');
  }

  // Frame rate monitoring
  void _startFrameRateMonitoring() {
    _frameCallback = (timeStamp) {
      final now = DateTime.now();
      
      if (_lastFrameTime != null) {
        final frameDuration = now.difference(_lastFrameTime!);
        _frameTimes.add(frameDuration);
        
        // Keep only recent frame times
        if (_frameTimes.length > 60) {
          _frameTimes.removeAt(0);
        }
      }
      
      _lastFrameTime = now;
      _frameCount++;
      
      // Schedule next frame callback
      SchedulerBinding.instance.addPostFrameCallback(_frameCallback!);
    };
    
    SchedulerBinding.instance.addPostFrameCallback(_frameCallback!);
  }

  // Performance monitoring
  void _startPerformanceMonitoring() {
    _performanceMonitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _logPerformanceMetrics();
    });
  }

  void _logPerformanceMetrics() {
    if (!AppConstants.enablePerformanceLogs) return;

    final fps = calculateAverageFPS();
    final memoryUsage = _getMemoryUsage();
    
    developer.log(
      'Performance Metrics - FPS: ${fps.toStringAsFixed(1)}, Memory: ${memoryUsage}MB',
      name: AppConstants.debugTag,
    );
    
    // Log slow operations
    _operationTimes.forEach((operation, times) {
      if (times.isNotEmpty) {
        final avgTime = times.reduce((a, b) => a + b) / times.length;
        if (avgTime > 50) { // Log operations slower than 50ms
          developer.log(
            'Slow operation: $operation - Avg: ${avgTime.toStringAsFixed(2)}ms, Count: ${_operationCounts[operation]}',
            name: AppConstants.debugTag,
          );
        }
      }
    });
  }

  double calculateAverageFPS() {
    if (_frameTimes.isEmpty) return 0.0;
    
    final avgFrameTime = _frameTimes
        .map((duration) => duration.inMicroseconds)
        .reduce((a, b) => a + b) / _frameTimes.length;
    
    return 1000000.0 / avgFrameTime; // Convert to FPS
  }

  double _getMemoryUsage() {
    // This is a simplified memory usage calculation
    // In a real app, you might use more sophisticated methods
    return (_operationTimes.length * 0.1); // Placeholder calculation
  }

  // Database optimization
  Future<void> optimizeDatabase() async {
    startOperation('database_optimization');
    
    try {
      // Import local database here when available
      // await LocalDatabase().optimizeDatabase();
      // await LocalDatabase().clearOldMessages();
    } catch (e) {
      developer.log('Database optimization failed: $e', name: AppConstants.debugTag);
    }
    
    endOperation('database_optimization');
  }

  // Network optimization
  void optimizeNetworkRequests() {
    // Configure HTTP client for better performance
    // This would typically involve setting connection pooling,
    // timeouts, and other network optimizations
  }

  // UI optimization methods
  Widget optimizeListView({
    required IndexedWidgetBuilder itemBuilder,
    required int itemCount,
    ScrollController? controller,
    EdgeInsets? padding,
  }) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      // Enable performance optimizations
      cacheExtent: 500.0, // Cache items outside viewport
      addAutomaticKeepAlives: false, // Don't keep items alive unnecessarily
      addRepaintBoundaries: true, // Add repaint boundaries for performance
    );
  }

  // Image caching optimization
  void preloadImages(List<String> imageUrls, BuildContext context) {
    for (final url in imageUrls.take(10)) { // Limit preloading
      precacheImage(NetworkImage(url), context);
    }
  }

  // Memory pressure handling
  void handleMemoryPressure() {
    if (!kReleaseMode) {
      developer.log('Handling memory pressure', name: AppConstants.debugTag);
    }
    
    // Clear image cache
    imageCache.clear();
    imageCache.clearLiveImages();
    
    // Force garbage collection
    _performMemoryCleanup();
    
    // Clear old performance data
    _operationTimes.clear();
    _operationCounts.clear();
    _frameTimes.clear();
  }

  // Battery optimization
  void optimizeForBattery() {
    // Reduce frame rate when app is in background
    // Pause unnecessary background tasks
    // Reduce network polling frequency
  }

  // Performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    stats['fps'] = calculateAverageFPS();
    stats['memory_usage'] = _getMemoryUsage();
    stats['operation_counts'] = Map.from(_operationCounts);
    
    final operationAvgs = <String, double>{};
    _operationTimes.forEach((operation, times) {
      if (times.isNotEmpty) {
        operationAvgs[operation] = times.reduce((a, b) => a + b) / times.length;
      }
    });
    stats['operation_averages'] = operationAvgs;
    
    return stats;
  }

  // Lazy loading helper
  Future<T> lazyLoad<T>(Future<T> Function() loader, String cacheKey) async {
    // Implement caching logic here
    return await loader();
  }

  // Background task optimization
  void scheduleBackgroundTask(String taskName, Function task) {
    // Schedule task to run when app is idle
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (AppConstants.enablePerformanceLogs) {
        startOperation('background_task_$taskName');
      }
      
      try {
        await task();
      } finally {
        if (AppConstants.enablePerformanceLogs) {
          endOperation('background_task_$taskName');
        }
      }
    });
  }

  // Animation optimization
  AnimationController createOptimizedAnimationController({
    required Duration duration,
    required TickerProvider vsync,
    double? value,
  }) {
    return AnimationController(
      duration: duration,
      vsync: vsync,
      value: value,
    )..addStatusListener((status) {
      // Dispose of animation resources when animation completes
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        // Optional cleanup logic
      }
    });
  }
}

// Extension methods for performance optimization
extension PerformanceExtensions on Widget {
  Widget withPerformanceTracking(String operationName) {
    return _PerformanceTrackingWidget(
      operationName: operationName,
      child: this,
    );
  }
}

class _PerformanceTrackingWidget extends StatefulWidget {
  final String operationName;
  final Widget child;

  const _PerformanceTrackingWidget({
    required this.operationName,
    required this.child,
  });

  @override
  State<_PerformanceTrackingWidget> createState() => _PerformanceTrackingWidgetState();
}

class _PerformanceTrackingWidgetState extends State<_PerformanceTrackingWidget> {
  @override
  void initState() {
    super.initState();
    PerformanceService().startOperation('widget_${widget.operationName}');
  }

  @override
  void dispose() {
    PerformanceService().endOperation('widget_${widget.operationName}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}