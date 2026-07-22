import 'dart:io';
import 'package:flutter/material.dart';
import 'package:recovery_tool/core/service/thumbnail_service.dart';

class VideoThumbnail extends StatelessWidget {
  final String videoPath;
  final IconData fallbackIcon;
  final Color fallbackColor;

  const VideoThumbnail({
    super.key,
    required this.videoPath,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: ThumbnailService().getVideoThumbnail(videoPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
          return Image.file(
            File(snapshot.data!),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          );
        }

        // Show a loading indicator or fallback while processing
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildFallback(),
            if (snapshot.connectionState == ConnectionState.waiting)
              Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fallbackColor.withValues(alpha: 0.5)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Icon(
        fallbackIcon,
        color: fallbackColor.withValues(alpha: 0.2),
        size: 32,
      ),
    );
  }
}
