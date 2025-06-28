// custom_snackbar.dart
import 'package:flutter/material.dart';

class CustomSnackbar {
  static void show({
    required BuildContext context,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Color backgroundColor = const Color(0xFFED6E6E),
    Color textColor = Colors.white,
    IconData icon = Icons.error_outline,
    Duration duration = const Duration(seconds: 4),
    Curve animationCurve = Curves.fastOutSlowIn,
    double elevation = 6.0,
    double borderRadius = 16.0,
    double iconSize = 24.0,
    bool showProgressBar = false,
    Color progressBarColor = Colors.white,
  }) {
    final overlay = Overlay.of(context);
    final controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: overlay,
    );

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 0,
        right: 0,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: controller, curve: animationCurve)),
          child: FadeTransition(
            opacity: controller,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      backgroundColor.withOpacity(0.9),
                      backgroundColor.withOpacity(0.95),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          color: textColor.withOpacity(0.9),
                          size: iconSize,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (actionLabel != null)
                          TextButton(
                            onPressed: () {
                              controller.reverse().then((_) {
                                OverlayEntry(
                                  builder: (context) {
                                    return Container();
                                  },
                                );
                                onActionPressed?.call();
                              });
                            },
                            child: Text(
                              actionLabel,
                              style: TextStyle(
                                color: textColor.withOpacity(0.9),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (showProgressBar)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: LinearProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressBarColor,
                          ),
                          backgroundColor: progressBarColor.withOpacity(0.2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    controller.forward();
    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      controller.reverse().then((_) => overlayEntry.remove());
    });
  }

  // Variants for different types of messages
  static void error({
    required BuildContext context,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    show(
      context: context,
      message: message,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      backgroundColor: const Color(0xFFED6E6E),
      icon: Icons.error_outline,
      duration: Duration(seconds: 50),
    );
  }

  static void success({
    required BuildContext context,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    show(
      context: context,
      message: message,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      backgroundColor: const Color(0xFF66BB6A),
      icon: Icons.check_circle_outline,
    );
  }

  static void warning({
    required BuildContext context,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    show(
      context: context,
      message: message,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      backgroundColor: const Color(0xFFFFA726),
      icon: Icons.warning_amber_outlined,
      showProgressBar: true,
    );
  }

  static void info({
    required BuildContext context,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    show(
      context: context,
      message: message,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      backgroundColor: const Color(0xFF42A5F5),
      icon: Icons.info_outline,
    );
  }
}
