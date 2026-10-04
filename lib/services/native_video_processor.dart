import 'dart:io';
import 'package:flutter/services.dart';

class NativeVideoProcessor {
  static const MethodChannel _channel = MethodChannel('com.trell.lifestyle/video_processor');

  /// Process video with native MediaCodec/MediaMuxer engine
  static Future<String> processVideo({
    required String inputPath,
    required String outputPath,
    String? musicPath,
    required String filterName,
    required double startSeconds,
    required double endSeconds,
    required double origAudioVol,
    required double musicVol,
  }) async {
    try {
      final String resultPath = await _channel.invokeMethod('processVideo', {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'musicPath': musicPath,
        'filterName': filterName,
        'startMs': (startSeconds * 1000).round(),
        'endMs': (endSeconds * 1000).round(),
        'origAudioVol': origAudioVol,
        'musicVol': musicVol,
      });
      return resultPath;
    } on PlatformException catch (e) {
      throw Exception('Video processing failed: ${e.message}');
    }
  }

  /// Query video metadata (duration, width, height, audio track presence)
  static Future<Map<String, dynamic>> getMediaMetadata(String inputPath) async {
    try {
      final Map<dynamic, dynamic> res = await _channel.invokeMethod('getMediaMetadata', {
        'inputPath': inputPath,
      });
      return Map<String, dynamic>.from(res);
    } on PlatformException catch (e) {
      throw Exception('Failed to read media metadata: ${e.message}');
    }
  }
}
