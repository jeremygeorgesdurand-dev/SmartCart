// Tests widget de l'onboarding (premier lancement) : "Passer" et
// "Commencer" doivent tous deux déclencher le callback et marquer
// onboarding_vu, et naviguer jusqu'au bout doit aussi fonctionner.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartcart/screens/onboarding_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('"Passer" termine l\'onboarding et marque onboarding_vu',
      (tester) async {
    var termine = false;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onTermine: () => termine = true),
    ));

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();

    expect(termine, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_vu'), isTrue);
  });

  testWidgets('naviguer jusqu\'à la dernière slide puis "Commencer" termine',
      (tester) async {
    var termine = false;
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(onTermine: () => termine = true),
    ));

    expect(find.text('Suivant'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Commencer'), findsOneWidget);
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    expect(termine, isTrue);
  });
}
