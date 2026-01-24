import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_iptv_player/services/tv_detection_service.dart';
import 'package:another_iptv_player/utils/tv_key_handler.dart';

/// A wrapper widget that makes any card focusable for TV/D-pad navigation.
/// Provides visual focus indicators and handles Enter/Select key activation.
class FocusableCard extends StatefulWidget {
  /// The child widget to wrap
  final Widget child;

  /// Called when the card is activated (Enter/Select pressed or tapped)
  final VoidCallback? onActivate;

  /// Called when the card receives focus
  final VoidCallback? onFocusGained;

  /// Called when the card loses focus
  final VoidCallback? onFocusLost;

  /// Optional FocusNode to use (will create one internally if not provided)
  final FocusNode? focusNode;

  /// Whether to automatically request focus when widget is first built
  final bool autofocus;

  /// Border radius for the focus indicator
  final BorderRadius? borderRadius;

  /// Width of the focus border
  final double focusBorderWidth;

  /// Color of the focus border (defaults to accent color)
  final Color? focusBorderColor;

  /// Scale factor when focused (1.0 = no scale)
  final double focusScale;

  /// Duration of the focus animation
  final Duration animationDuration;

  /// Whether to show a glow effect when focused
  final bool showFocusGlow;

  /// Whether to enable focus handling (set to false for non-TV modes)
  final bool enableFocus;

  const FocusableCard({
    super.key,
    required this.child,
    this.onActivate,
    this.onFocusGained,
    this.onFocusLost,
    this.focusNode,
    this.autofocus = false,
    this.borderRadius,
    this.focusBorderWidth = 3.0,
    this.focusBorderColor,
    this.focusScale = 1.05,
    this.animationDuration = const Duration(milliseconds: 150),
    this.showFocusGlow = true,
    this.enableFocus = true,
  });

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus != _hasFocus) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });

      if (_hasFocus) {
        widget.onFocusGained?.call();
      } else {
        widget.onFocusLost?.call();
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (TvKeyHandler.isSelectKey(event)) {
      widget.onActivate?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Check if we should enable TV focus mode
    final isTV = TvDetectionService().isAndroidTV;
    final shouldEnableFocus = widget.enableFocus && isTV;

    if (!shouldEnableFocus) {
      // On non-TV devices, just return the child with tap handling
      return GestureDetector(
        onTap: widget.onActivate,
        child: widget.child,
      );
    }

    final theme = Theme.of(context);
    final borderColor = widget.focusBorderColor ?? theme.colorScheme.primary;
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(8);

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () {
          _focusNode.requestFocus();
          widget.onActivate?.call();
        },
        child: AnimatedContainer(
          duration: widget.animationDuration,
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..scale(_hasFocus ? widget.focusScale : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: _hasFocus ? borderColor : Colors.transparent,
              width: widget.focusBorderWidth,
            ),
            boxShadow: _hasFocus && widget.showFocusGlow
                ? [
                    BoxShadow(
                      color: borderColor.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A wrapper that provides TV-aware focus handling for any widget.
/// Simpler than FocusableCard - no visual indicators, just focus management.
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onActivate;
  final FocusNode? focusNode;
  final bool autofocus;

  const TvFocusable({
    super.key,
    required this.child,
    this.onActivate,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (TvKeyHandler.isSelectKey(event)) {
      widget.onActivate?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isTV = TvDetectionService().isAndroidTV;

    if (!isTV) {
      return GestureDetector(
        onTap: widget.onActivate,
        child: widget.child,
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () {
          _focusNode.requestFocus();
          widget.onActivate?.call();
        },
        child: widget.child,
      ),
    );
  }
}
