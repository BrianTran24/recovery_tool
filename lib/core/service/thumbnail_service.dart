import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final Map<String, Future<String?>> _processing = {};

  Future<String?> getVideoThumbnail(String videoPath) async {
    // 1. Create a unique cache key based on path
    final key = md5.convert(utf8.encode(videoPath)).toString();
    final tempDir = await getTemporaryDirectory();
    final cachePath = p.join(tempDir.path, 'thumbnails', '$key.jpg');

    final cacheFile = File(cachePath);
    if (await cacheFile.exists()) {
      return cachePath;
    }

    // 2. Prevent duplicate processing
    if (_processing.containsKey(videoPath)) {
      return _processing[videoPath];
    }

    final future = _extractFrame(videoPath, cachePath);
    _processing[videoPath] = future;
    
    try {
      final result = await future;
      return result;
    } finally {
      _processing.remove(videoPath);
    }
  }

  Future<String?> _extractFrame(String videoPath, String outputPath) async {
    final player = Player();
    try {
      // Ensure directory exists
      final dir = Directory(p.dirname(outputPath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Open without auto-play
      await player.open(Media(videoPath), play: false);
      
      // Wait for video to be ready and seek to 1 second (or start if shorter)
      // Note: In media_kit, screenshot captures the current frame.
      // We might need a small delay or wait for a state change.
      await player.stream.completed.first.timeout(
        const Duration(seconds: 2), 
        onTimeout: () => false
      );

      // Seek to 1s to get a more representative frame than just black
      await player.seek(const Duration(seconds: 1));
      
      // Give it a moment to decode the frame after seek
      await Future.delayed(const Duration(milliseconds: 500));

      final success = await player.screenshot();
      if (success != null) {
        await File(outputPath).writeAsBytes(success);
        return outputPath;
      }
    } catch (e) {
      debugPrint('Error extracting thumbnail for $videoPath: $e');
    } finally {
      await player.dispose();
    }
    return null;
  }
}
