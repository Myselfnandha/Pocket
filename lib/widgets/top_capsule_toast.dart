import 'dart:ui';
import 'package:flutter/material.dart';

class TopCapsuleToast {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    String? title,
    String? message,
    String? subtitle,
    String? amountText,
    String? categoryIcon,
    bool isSuccess = true,
    Widget? icon,
    Color? accentColor,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    // Dismiss any existing toast
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    final effectiveTitle = title ?? message ?? '';
    final effectiveSubtitle = subtitle ?? amountText;
    final effectiveIcon = icon ?? (categoryIcon != null ? Text(categoryIcon, style: const TextStyle(fontSize: 18)) : null);
    final effectiveAccent = accentColor ?? (isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFFF5252));

    entry = OverlayEntry(
      builder: (context) => _TopCapsuleToastWidget(
        title: effectiveTitle,
        subtitle: effectiveSubtitle,
        icon: effectiveIcon,
        accentColor: effectiveAccent,
        duration: duration,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
            if (_currentEntry == entry) {
              _currentEntry = null;
            }
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static OverlayEntry? _currentBottomEntry;

  static void showBottom(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3500),
    Color accentColor = const Color(0xFF4CAF50),
    Widget? icon,
  }) {
    // Dismiss any existing bottom toast cleanly
    try {
      _currentBottomEntry?.remove();
    } catch (_) {}
    _currentBottomEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _BottomCapsuleToastWidget(
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        accentColor: accentColor,
        duration: duration,
        icon: icon,
        onDismiss: () {
          try {
            if (entry.mounted) {
              entry.remove();
              if (_currentBottomEntry == entry) {
                _currentBottomEntry = null;
              }
            }
          } catch (_) {}
        },
      ),
    );

    _currentBottomEntry = entry;
    overlay.insert(entry);
  }
}

class _TopCapsuleToastWidget extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget? icon;
  final Color accentColor;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopCapsuleToastWidget({
    required this.title,
    this.subtitle,
    this.icon,
    required this.accentColor,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopCapsuleToastWidget> createState() => _TopCapsuleToastWidgetState();
}

class _TopCapsuleToastWidgetState extends State<_TopCapsuleToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnimation = Tween<double>(begin: -60.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    // Auto-dismiss timer
    Future.delayed(widget.duration, () {
      if (mounted && !_isDismissing) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: topPadding + kToolbarHeight + 8,
      left: 16,
      right: 16,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(
                opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -4) {
                _dismiss();
              }
            },
            onTap: _dismiss,
            child: Align(
              alignment: Alignment.topCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xDD1E1E1E)
                          : const Color(0xEEFFFFFF),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.22),
                          blurRadius: 16,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: widget.icon,
                          ),
                          const SizedBox(width: 10),
                        ] else ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.accentColor.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomCapsuleToastWidget extends StatefulWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color accentColor;
  final Duration duration;
  final Widget? icon;
  final VoidCallback onDismiss;

  const _BottomCapsuleToastWidget({
    required this.message,
    this.actionLabel,
    this.onAction,
    required this.accentColor,
    required this.duration,
    this.icon,
    required this.onDismiss,
  });

  @override
  State<_BottomCapsuleToastWidget> createState() => _BottomCapsuleToastWidgetState();
}

class _BottomCapsuleToastWidgetState extends State<_BottomCapsuleToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDismissing = false;
  var _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    // Auto-dismiss countdown
    Future.delayed(widget.duration, () {
      if (mounted && !_isDismissing && !_isCancelled) {
        _dismissToast();
      }
    });
  }

  void _dismissToast() {
    if (_isDismissing) return;
    _isDismissing = true;
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _isCancelled = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 96,
      left: 20,
      right: 20,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: child,
              ),
            );
          },
          child: Dismissible(
            key: const Key('bottom_capsule_toast_dismiss'),
            direction: DismissDirection.down,
            onDismissed: (_) => widget.onDismiss(),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E24).withValues(alpha: 0.94)
                          : const Color(0xFF212126).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          widget.icon!,
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (widget.actionLabel != null && widget.onAction != null) ...[
                          const SizedBox(width: 14),
                          InkWell(
                            onTap: () {
                              _isCancelled = true;
                              _dismissToast();
                              widget.onAction!();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: widget.accentColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: widget.accentColor.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: widget.accentColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
