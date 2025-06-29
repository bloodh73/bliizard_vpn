// lib/components/custom_snackbar.dart
import 'package:flutter/material.dart';

class CustomSnackbar {
  static OverlayEntry? _currentOverlayEntry;

  static void show({
    required BuildContext context,
    required String message,
    Color backgroundColor = Colors.grey,
    IconData icon = Icons.info_outline,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Remove any existing snackbar first
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;

    _currentOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top:
            MediaQuery.of(context).padding.top +
            10, // Position at the top, below status bar
        left: 10,
        right: 10,
        child: _CustomSnackbarWidget(
          message: message,
          backgroundColor: backgroundColor,
          icon: icon,
          duration: duration,
          onDismiss: () {
            if (_currentOverlayEntry != null) {
              _currentOverlayEntry!.remove();
              _currentOverlayEntry = null;
            }
          },
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlayEntry!);
  }
}

class _CustomSnackbarWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismiss;

  const _CustomSnackbarWidget({
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_CustomSnackbarWidget> createState() => _CustomSnackbarWidgetState();
}

class _CustomSnackbarWidgetState extends State<_CustomSnackbarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0), // Starts from left
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
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
    return SlideTransition(
      position: _offsetAnimation,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  _controller.reverse().then((_) {
                    widget.onDismiss();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
