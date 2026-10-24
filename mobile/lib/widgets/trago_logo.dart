import 'package:flutter/material.dart';
import '../theme/trago_theme.dart';

class TragoLogo extends StatelessWidget {
  final bool showTagline;
  final double fontSize;

  const TragoLogo({
    super.key,
    this.showTagline = true,
    this.fontSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'TRAGO',
              style: TextStyle(
                color: TragoColors.navy,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 2),
            _CoralExclamationMark(height: fontSize * 0.92),
          ],
        ),
        if (showTagline) ...[
          const SizedBox(height: 3),
          const Text(
            'A Nova Rota da Importação Global',
            style: TextStyle(
              color: TragoColors.navy,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ],
    );
  }
}

class _CoralExclamationMark extends StatelessWidget {
  final double height;

  const _CoralExclamationMark({required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: height * 0.36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: height * 0.72,
            width: height * 0.34,
            decoration: BoxDecoration(
              color: TragoColors.coral,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.send_rounded,
              size: height * 0.25,
              color: Colors.white,
            ),
          ),
          Container(
            height: height * 0.2,
            width: height * 0.22,
            decoration: const BoxDecoration(
              color: TragoColors.coral,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
