import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A reusable widget for displaying student profile pictures with proper caching
/// Supports both direct avatar_url and fallback to initial letter
class StudentAvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String? fullName;
  final double size;
  final Color? backgroundColor;
  final String? heroTag;

  const StudentAvatarWidget({
    super.key,
    this.avatarUrl,
    this.fullName,
    this.size = 50,
    this.backgroundColor,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final widget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.teal.shade600,
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildInitialAvatar(),
                // Caching configuration
                memCacheWidth: (size * 2).toInt(), // Cache at 2x resolution for retina displays
                memCacheHeight: (size * 2).toInt(),
                maxWidthDiskCache: (size * 3).toInt(), // Disk cache at 3x for high quality
                maxHeightDiskCache: (size * 3).toInt(),
              )
            : _buildInitialAvatar(),
      ),
    );

    // Wrap with Hero if heroTag is provided
    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: widget,
      );
    }

    return widget;
  }

  Widget _buildInitialAvatar() {
    final initial = (fullName?.isNotEmpty ?? false)
        ? fullName![0].toUpperCase()
        : '?';

    return Container(
      color: backgroundColor ?? Colors.teal.shade600,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4, // 40% of avatar size
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

