import 'package:flutter_test/flutter_test.dart';
import 'package:padel_community_app/app/padel_app.dart';

void main() {
  testWidgets('home screen shows match actions', (tester) async {
    await tester.pumpWidget(const PadelApp());

    expect(find.text('Padel Community'), findsOneWidget);
    expect(find.text('Crea una partita'), findsOneWidget);
    expect(find.text('Trova una partita'), findsOneWidget);
  });
}
