// Unit test untuk [MarkerPickTooltip] flag persistence (PR #32 Phase 1).
//
// Fokus: round-trip SharedPreferences default false → markShown → true.
// Pakai `setMockInitialValues` supaya test deterministik tanpa perlu
// platform channel real.

import 'package:flutter_test/flutter_test.dart';
import 'package:styra/features/map/presentation/widgets/marker_pick_tooltip.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MarkerPickTooltip', () {
    test('hasBeenShown defaults to false on first install', () async {
      expect(await MarkerPickTooltip.hasBeenShown(), isFalse);
    });

    test('markShown persists the flag', () async {
      await MarkerPickTooltip.markShown();
      expect(await MarkerPickTooltip.hasBeenShown(), isTrue);
    });

    test('markShown is idempotent', () async {
      await MarkerPickTooltip.markShown();
      await MarkerPickTooltip.markShown();
      await MarkerPickTooltip.markShown();
      expect(await MarkerPickTooltip.hasBeenShown(), isTrue);
    });

    test('hasBeenShown true survives multiple reads', () async {
      await MarkerPickTooltip.markShown();
      expect(await MarkerPickTooltip.hasBeenShown(), isTrue);
      expect(await MarkerPickTooltip.hasBeenShown(), isTrue);
      expect(await MarkerPickTooltip.hasBeenShown(), isTrue);
    });
  });
}
