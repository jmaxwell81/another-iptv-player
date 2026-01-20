import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:another_iptv_player/services/failed_domain_cache.dart';

/// A wrapper around CachedNetworkImage that checks the failed domain cache
/// before attempting to load an image, avoiding unnecessary network requests
/// to domains that are known to be down.
class SmartCachedImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final double? width;
  final double? height;

  const SmartCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  @override
  State<SmartCachedImage> createState() => _SmartCachedImageState();
}

class _SmartCachedImageState extends State<SmartCachedImage> {
  final FailedDomainCache _domainCache = FailedDomainCache();
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _checkDomain();
  }

  @override
  void didUpdateWidget(SmartCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _checkDomain();
    }
  }

  void _checkDomain() {
    setState(() {
      _isBlocked = _domainCache.isDomainBlocked(widget.imageUrl);
    });
  }

  @override
  Widget build(BuildContext context) {
    // If the domain is blocked, show error widget directly without trying to load
    if (_isBlocked || widget.imageUrl.isEmpty) {
      return widget.errorWidget?.call(context, widget.imageUrl, 'Domain blocked') ??
          _buildDefaultErrorWidget(context);
    }

    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: widget.placeholder,
      errorWidget: (context, url, error) {
        // Mark domain as failed when we get an error
        if (error.toString().contains('SocketException') ||
            error.toString().contains('Failed host lookup') ||
            error.toString().contains('Connection refused') ||
            error.toString().contains('Connection timed out')) {
          _domainCache.markDomainFailed(url);
        }
        return widget.errorWidget?.call(context, url, error) ??
            _buildDefaultErrorWidget(context);
      },
    );
  }

  Widget _buildDefaultErrorWidget(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}

/// Extension to easily replace CachedNetworkImage with SmartCachedImage
extension SmartCachedImageExtension on String {
  /// Check if this URL's domain is known to be down
  bool get isDomainBlocked => FailedDomainCache().isDomainBlocked(this);
}
