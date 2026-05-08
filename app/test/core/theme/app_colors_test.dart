import 'package:flutter_test/flutter_test.dart';
import 'package:langgeng_sea/core/theme/app_colors.dart';

void main() {
  group('AppColors.colorForHaul', () {
    test('returns first color for index 1', () {
      expect(AppColors.colorForHaul(1), AppColors.haulColors.first);
    });

    test('cycles through palette when index exceeds length', () {
      final length = AppColors.haulColors.length;
      expect(
        AppColors.colorForHaul(length + 1),
        AppColors.haulColors.first,
      );
    });

    test('provides deterministic color for same index', () {
      expect(AppColors.colorForHaul(3), AppColors.colorForHaul(3));
    });
  });
}
