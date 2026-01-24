import 'package:flutter/material.dart';
import 'package:another_iptv_player/services/tv_detection_service.dart';

/// A focus traversal wrapper for TV navigation sections.
/// Wraps content in a FocusTraversalGroup with configurable traversal order.
class TvFocusScope extends StatelessWidget {
  /// The child widget to wrap
  final Widget child;

  /// Whether this scope uses horizontal traversal (for rows of items)
  /// If false, uses vertical traversal (for lists/columns)
  final bool horizontal;

  /// Optional policy for focus traversal
  final FocusTraversalPolicy? policy;

  /// Whether this scope should be skipped in traversal
  final bool skipTraversal;

  /// Whether this scope should be a focus scope (creates a new focus scope)
  final bool isScope;

  /// Callback when this group receives focus
  final VoidCallback? onFocusGained;

  const TvFocusScope({
    super.key,
    required this.child,
    this.horizontal = true,
    this.policy,
    this.skipTraversal = false,
    this.isScope = false,
    this.onFocusGained,
  });

  @override
  Widget build(BuildContext context) {
    final isTV = TvDetectionService().isAndroidTV;

    // On non-TV devices, just return the child
    if (!isTV) {
      return child;
    }

    // Determine the traversal policy
    final traversalPolicy = policy ??
        (horizontal
            ? ReadingOrderTraversalPolicy()
            : ReadingOrderTraversalPolicy());

    if (isScope) {
      return FocusScope(
        skipTraversal: skipTraversal,
        child: FocusTraversalGroup(
          policy: traversalPolicy,
          child: child,
        ),
      );
    }

    return FocusTraversalGroup(
      policy: traversalPolicy,
      child: child,
    );
  }
}

/// A row-specific focus scope for horizontal D-pad navigation (e.g., category content)
class TvHorizontalFocusRow extends StatefulWidget {
  final Widget child;
  final bool autofocus;
  final ScrollController? scrollController;

  const TvHorizontalFocusRow({
    super.key,
    required this.child,
    this.autofocus = false,
    this.scrollController,
  });

  @override
  State<TvHorizontalFocusRow> createState() => _TvHorizontalFocusRowState();
}

class _TvHorizontalFocusRowState extends State<TvHorizontalFocusRow> {
  @override
  Widget build(BuildContext context) {
    final isTV = TvDetectionService().isAndroidTV;

    if (!isTV) {
      return widget.child;
    }

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: widget.child,
    );
  }
}

/// A vertical focus scope for navigating between category rows
class TvVerticalFocusColumn extends StatelessWidget {
  final Widget child;

  const TvVerticalFocusColumn({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isTV = TvDetectionService().isAndroidTV;

    if (!isTV) {
      return child;
    }

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: child,
    );
  }
}

/// Focus memory widget that remembers and restores focus position.
/// Useful for when navigating back to a screen.
class TvFocusMemory extends StatefulWidget {
  final Widget child;
  final String memoryKey;

  const TvFocusMemory({
    super.key,
    required this.child,
    required this.memoryKey,
  });

  @override
  State<TvFocusMemory> createState() => _TvFocusMemoryState();
}

class _TvFocusMemoryState extends State<TvFocusMemory> {
  static final Map<String, FocusNode?> _focusMemory = {};

  @override
  void initState() {
    super.initState();
    // Restore focus after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreFocus();
    });
  }

  void _restoreFocus() {
    final savedFocus = _focusMemory[widget.memoryKey];
    if (savedFocus != null && savedFocus.canRequestFocus) {
      savedFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          // Save the current primary focus when this scope gains focus
          final currentFocus = FocusManager.instance.primaryFocus;
          if (currentFocus != null) {
            _focusMemory[widget.memoryKey] = currentFocus;
          }
        }
      },
      child: widget.child,
    );
  }

  /// Clear saved focus for a specific key
  static void clearMemory(String key) {
    _focusMemory.remove(key);
  }

  /// Clear all saved focus memory
  static void clearAllMemory() {
    _focusMemory.clear();
  }
}

/// A widget that auto-focuses the first focusable child when built.
class TvAutoFocusFirst extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const TvAutoFocusFirst({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<TvAutoFocusFirst> createState() => _TvAutoFocusFirstState();
}

class _TvAutoFocusFirstState extends State<TvAutoFocusFirst> {
  final FocusScopeNode _scopeNode = FocusScopeNode();

  @override
  void initState() {
    super.initState();
    if (widget.enabled && TvDetectionService().isAndroidTV) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusFirst();
      });
    }
  }

  @override
  void dispose() {
    _scopeNode.dispose();
    super.dispose();
  }

  void _focusFirst() {
    // Find the first focusable descendant and focus it
    final focusScope = FocusScope.of(context);
    focusScope.requestFocus();
    focusScope.nextFocus();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: _scopeNode,
      child: widget.child,
    );
  }
}
