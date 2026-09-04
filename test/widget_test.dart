import 'package:flutter_test/flutter_test.dart';
import 'package:wellness_intelligence/main.dart';

void main() {
  testWidgets('999 Wellness Intelligence launches', (tester) async {
    await tester.pumpWidget(const WellnessIntelligenceApp());

    expect(find.text('999 WELLNESS'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });
}
