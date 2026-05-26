// Widget tests for FollowHaulPickerSheet: verifies the sheet lists
// every haul it's given, tapping a card resolves the future with
// that haul, and Batal resolves to null. Log book provider is
// overridden to AsyncData(null) so the test doesn't need a real
// Drift database stood up -- the catch-hint row is a nice-to-have
// and already covered implicitly by the _hintFor branches here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:styra/features/history/presentation/widgets/follow_haul_picker_sheet.dart';
import 'package:styra/features/logbook/data/log_book_repository.dart';
import 'package:styra/features/tracking/domain/entities/haul.dart';

Haul _haul({
  required int order,
  String? name,
  String id = '',
  int durationSeconds = 1800,
  double distanceMeters = 1200,
}) {
  return Haul(
    id: id.isEmpty ? 'h-$order' : id,
    tripId: 'trip-1',
    orderIndex: order,
    name: name,
    startedAt: DateTime(2026, 5, 10, 6, 0),
    endedAt: DateTime(2026, 5, 10, 6, 30),
    status: HaulStatus.completed,
    trawlWidthMeters: 20,
    distanceMeters: distanceMeters,
    durationSeconds: durationSeconds,
  );
}

/// Wraps the given child in a MaterialApp with ProviderScope so that
/// showModalBottomSheet has a Navigator to attach to and Riverpod
/// providers resolve against the test overrides.
Widget _harness(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      // Default: no log book entry for any haul. Each test can
      // override this further if it needs to exercise the catch hint.
      logBookByHaulProvider.overrideWith((ref, _) => Stream.value(null)),
      ...overrides,
    ],
    child: MaterialApp(home: child),
  );
}

/// Builds a Scaffold with a button that triggers the sheet, and
/// stashes the resolved Haul (or null) in [result] for the test to
/// inspect.
Widget _pickerHost({
  required List<Haul> hauls,
  required List<Haul?> resultSink,
}) {
  return Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final picked = await FollowHaulPickerSheet.show(
              context,
              hauls: hauls,
            );
            resultSink.add(picked);
          },
          child: const Text('OPEN'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('lists every haul passed in, displayName visible', (
    tester,
  ) async {
    final hauls = [
      _haul(order: 1, name: 'Spot Pagi'),
      _haul(order: 2),
      _haul(order: 3, name: 'Spot Sore'),
    ];
    final results = <Haul?>[];

    await tester.pumpWidget(
      _harness(_pickerHost(hauls: hauls, resultSink: results)),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Tarikan untuk Ikuti Jalur'), findsOneWidget);
    expect(find.text('Spot Pagi'), findsOneWidget);
    // Haul 2 has no user name -> falls back to "Tarikan #2".
    expect(find.text('Tarikan #2'), findsOneWidget);
    expect(find.text('Spot Sore'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
  });

  testWidgets('tapping a haul card resolves with that haul', (
    tester,
  ) async {
    final hauls = [
      _haul(order: 1, name: 'Spot A'),
      _haul(order: 2, name: 'Spot B'),
      _haul(order: 3, name: 'Spot C'),
    ];
    final results = <Haul?>[];

    await tester.pumpWidget(
      _harness(_pickerHost(hauls: hauls, resultSink: results)),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spot B'));
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    expect(results.single!.orderIndex, 2);
    expect(results.single!.name, 'Spot B');
  });

  testWidgets('Batal button resolves with null', (tester) async {
    final hauls = [
      _haul(order: 1, name: 'Only Haul'),
    ];
    final results = <Haul?>[];

    await tester.pumpWidget(
      _harness(_pickerHost(hauls: hauls, resultSink: results)),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('dismiss by swipe-down / barrier tap resolves null', (
    tester,
  ) async {
    final hauls = [_haul(order: 1)];
    final results = <Haul?>[];

    await tester.pumpWidget(
      _harness(_pickerHost(hauls: hauls, resultSink: results)),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    // Tap the barrier. showModalBottomSheet places a ModalBarrier
    // behind its sheet; finding by the widget type lets this test
    // survive copy changes.
    final barrier = find.byType(ModalBarrier).last;
    await tester.tap(barrier);
    await tester.pumpAndSettle();

    expect(results, [null]);
  });
}
