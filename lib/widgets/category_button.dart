import 'package:flutter/material.dart';
import 'neon_container.dart';

class CategoryButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const CategoryButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return NeonContainer(
      onTap: onTap,
      borderRadius: isTablet ? 18 : 14,
      padding: EdgeInsets.symmetric(
        vertical: isTablet ? 14 : 10,
        horizontal: isTablet ? 8 : 4,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF00BFFF), size: isTablet ? 34 : 26),
          SizedBox(height: isTablet ? 8 : 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 13 : 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: isTablet ? 8 : 6),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: isTablet ? 28 : 22,
              height: isTablet ? 28 : 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00BFFF), width: 1.5),
                color: Colors.black.withOpacity(0.4),
              ),
              child: Icon(Icons.add, color: const Color(0xFF00BFFF), size: isTablet ? 18 : 14),
            ),
          ),
        ],
      ),
    );
  }
}
