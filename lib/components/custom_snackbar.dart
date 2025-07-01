// lib/components/custom_snackbar.dart
import 'package:flutter/material.dart';

class CustomSnackbar {
  static OverlayEntry? _currentOverlayEntry;

  static void show({
    required BuildContext context,
    required String message,
    Color backgroundColor = Colors.grey, // Default can be adjusted
    IconData icon = Icons.info_outline,
    Duration duration = const Duration(seconds: 3),
  }) {
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;

    // Determine appropriate text/icon color based on background
    final Color foregroundColor =
        ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
        ? Colors.white
        : Colors.black; // Or specific theme colors

    _currentOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 10,
        right: 10,
        child: _CustomSnackbarWidget(
          message: message,
          backgroundColor: backgroundColor,
          icon: icon,
          duration: duration,
          foregroundColor: foregroundColor, // Pass foreground color
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
  final Color foregroundColor; // New property
  final VoidCallback onDismiss;

  const _CustomSnackbarWidget({
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.duration,
    required this.foregroundColor, // Required
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
      begin: const Offset(0.0, -1.5),
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
              Icon(
                widget.icon,
                color: widget.foregroundColor,
              ), // Use foregroundColor
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: widget.foregroundColor, // Use foregroundColor
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SM', // Ensure custom font is used
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: widget.foregroundColor,
                ), // Use foregroundColor
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
