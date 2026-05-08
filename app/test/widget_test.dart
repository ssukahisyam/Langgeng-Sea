import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:langgeng_sea/app.dart';
import 'package:langgeng_sea/core/constants/app_strings.dart';

void main() {
  testWidgets('App boots and shows the Map tab', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: LangengSeaApp()),
    );

    // Let initial frames settle. Avoid pumpAndSettle (google_fonts may fetch).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(AppStrings.startTrawl), findsOneWidget);
    expect(find.text(AppStrings.readyToSail), findsOneWidget);
  });

  testWidgets('Bottom nav shows 4 tabs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: LangengSeaApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(AppStrings.tabMap), findsOneWidget);
    expect(find.text(AppStrings.tabHistory), findsOneWidget);
    expect(find.text(AppStrings.tabDashboard), findsOneWidget);
    expect(find.text(AppStrings.tabSettings), findsOneWidget);
  });
}
