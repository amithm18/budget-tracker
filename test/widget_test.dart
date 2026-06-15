import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_splitter/main.dart';

void main() {
  testWidgets('HomePage renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const BudgetSplitterApp());

    expect(find.text('SplitWise'), findsOneWidget);
    expect(find.text('Split Smarter,\nStress Less.'), findsOneWidget);
    expect(find.text('Create a Group'), findsOneWidget);
    expect(find.text('View Expenses'), findsOneWidget);
  });
}