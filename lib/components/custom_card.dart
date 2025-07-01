// components/custom_card.dart
import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final bool isErrorState;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final BorderRadius? borderRadius;

  const CustomCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.isErrorState = false,
    this.padding,
    this.elevation,
    this.borderRadius,
    required String title,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation ?? 4,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
      ),
      color: backgroundColor,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isErrorState
                ? [Colors.red[800]!, Colors.red[600]!]
                : [
                    const Color.fromARGB(
                      255,
                      255,
                      255,
                      255,
                    ), // Lighter shade of white
                    const Color.fromARGB(
                      255,
                      240,
                      240,
                      240,
                    ), // Slightly darker shade of white
                  ],
          ),
          borderRadius: borderRadius ?? BorderRadius.circular(16),
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
