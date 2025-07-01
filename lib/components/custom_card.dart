// components/custom_card.dart
import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final bool isErrorState;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final BorderRadius? borderRadius;
  final String? title;

  const CustomCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.isErrorState = false,
    this.padding,
    this.elevation,
    this.borderRadius,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the base colors for the gradient
    final Color startColor = isErrorState
        ? Theme.of(context).colorScheme.error.withOpacity(0.9)
        : Theme.of(context).colorScheme.surface;
    final Color endColor = isErrorState
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.surface.withOpacity(
            0.95,
          ); // Slightly less opaque for subtle shine

    final Color borderColor = isErrorState
        ? Theme.of(context).colorScheme.errorContainer
        : Colors.grey.shade300; // Softer border for non-error state

    final BorderRadius effectiveBorderRadius =
        borderRadius ??
        BorderRadius.circular(15); // Slightly larger radius for a modern look

    return Card(
      elevation: elevation ?? 6, // Increased elevation for a more lifted look
      shape: RoundedRectangleBorder(
        borderRadius: effectiveBorderRadius,
        side: BorderSide(color: borderColor, width: 0.8), // Subtle border
      ),
      color:
          backgroundColor, // This will be overridden by BoxDecoration gradient
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [startColor, endColor],
          ),
          borderRadius: effectiveBorderRadius,
          boxShadow: [
            BoxShadow(
              color:
                  (isErrorState
                          ? Theme.of(context).colorScheme.error
                          : Colors.grey.shade300)
                      .withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding:
            padding ??
            const EdgeInsets.all(
              18,
            ), // Increased padding for more breathing room
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: TextStyle(
                  fontSize: 19, // Slightly larger title
                  fontWeight: FontWeight.bold,
                  color: isErrorState
                      ? Theme.of(context).colorScheme.onError
                      : Theme.of(context).colorScheme.onSurface,
                  fontFamily: 'SM',
                ),
              ),
              const SizedBox(height: 12), // More space after title
            ],
            child,
          ],
        ),
      ),
    );
  }
}
