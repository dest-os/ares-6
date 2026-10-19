import 'package:flutter/material.dart';

class NeonContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color glowColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const NeonContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.glowColor = const Color(0xFF00BFFF),
    this.borderWidth = 1.5,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: glowColor.withOpacity(0.7), width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.35),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
