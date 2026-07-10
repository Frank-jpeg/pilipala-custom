import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('基础 Material 组件可正常渲染', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('PiliPala')),
        ),
      ),
    );

    expect(find.text('PiliPala'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
