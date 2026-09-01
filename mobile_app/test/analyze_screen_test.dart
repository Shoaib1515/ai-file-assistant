import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/analyze_screen.dart';
import 'package:mobile_app/widgets/missing_values_chart.dart';

void main() {
  testWidgets('Analyze screen shows the empty selection prompt', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AnalyzeScreen()));

    expect(find.text('Select a file from Home to see its analysis.'), findsOneWidget);
    expect(find.text('Missing values by column'), findsNothing);
  });

  testWidgets('Missing values chart renders the highest issue columns', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MissingValuesChart(
            missingByColumn: const {
              'Age': {'total_missing': 3},
              'Email': {'total_missing': 8},
              'City': {'total_missing': 1},
            },
          ),
        ),
      ),
    );

    expect(find.text('Missing values by column'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
  });
}
