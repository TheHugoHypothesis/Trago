import 'package:flutter/material.dart';
import '../theme/trago_theme.dart';

class AccountBadge extends StatelessWidget {
  final bool isOrganization;

  const AccountBadge({super.key, required this.isOrganization});

  @override
  Widget build(BuildContext context) {
    final label = isOrganization ? 'PJ' : 'PF';
    final bgColor = isOrganization ? TragoColors.navy : TragoColors.mintLight;
    final textColor = isOrganization ? Colors.white : TragoColors.mint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
