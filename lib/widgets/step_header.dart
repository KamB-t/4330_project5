import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "STEP 1 OF 3 · UPLOAD" label with a three-segment progress bar.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, required this.label});

  final int step;
  final String label;

  static const _total = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP $step OF $_total  ·  ${label.toUpperCase()}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.tanDeep,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 1; i <= _total; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? AppColors.tan : AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < _total) const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}
