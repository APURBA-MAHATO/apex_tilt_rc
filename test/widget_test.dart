import 'package:flutter_test/flutter_test.dart';
import 'package:apex_tilt_rc/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ApexTiltApp());
  });
}