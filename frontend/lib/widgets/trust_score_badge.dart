/// Trust Score Badge Widget

import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:lendloop/core/constants/app_colors.dart';

class TrustScoreBadge extends StatelessWidget {
  final double score;
  final bool showLabel;
  final double size;

  const TrustScoreBadge({
    super.key,
    required this.score,
    this.showLabel = true,
    this.size = 60,
  });

  Color get _color {
    if (score >= 75) return AppColors.trustHigh;
    if (score >= 40) return AppColors.trustMedium;
    return AppColors.trustLow;
  }

  String get _label {
    if (score >= 75) return 'Trusted';
    if (score >= 40) return 'Moderate';
    return 'New';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularPercentIndicator(
          radius: size / 2,
          lineWidth: 4,
          percent: (score / 100).clamp(0.0, 1.0),
          center: Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              fontSize: size * 0.25,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
          progressColor: _color,
          backgroundColor: _color.withOpacity(0.15),
          animation: true,
          animationDuration: 800,
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color),
            ),
          ),
        ],
      ],
    );
  }
}
