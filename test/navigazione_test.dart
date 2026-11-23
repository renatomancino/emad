import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/core/router/rotte.dart';
import 'package:cenato/core/router/router.dart';
import 'package:cenato/core/dipendenze.dart';
import 'package:cenato/data/finto/auth_repository_finto.dart';
import 'package:cenato/data/finto/pazienti_repository_finto.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/main.dart';

/// Scheda "Tema, navigazione e schermate base dei due ruoli":
/// navigazione con ruolo simulato (AuthRepositoryFinto, nessun database).
void main() {
  Future<AuthRepositoryFinto> avvia(WidgetTester tester, {Ruolo? ruolo}) async {
    final auth = AuthRepositoryFinto(ruoloIniziale: ruolo);
    final dati = DatiFinti();
    await tester.pumpWidget(
      CenatoApp(
        dip: Dipendenze(
          auth: auth,
          pazienti: PazientiRepositoryFinto(dati),
          abbonamento: AbbonamentoRepositoryFinto(dati),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('senza sessione mostra l\'accesso', (tester) async {
    await avvia(tester);
    expect(find.text('Cenato · accesso di prova'), findsOneWidget);
  });

  testWidgets('il paziente arriva su Oggi e naviga tra le 4 sezioni', (
    tester,
  ) async {
    await avvia(tester, ruolo: Ruolo.paziente);

    for (final sezione in ['Oggi', 'Dieta', 'Andamento', 'Visite']) {
      expect(
        find.text(sezione),
        findsWidgets,
        reason: 'voce della barra: $sezione',
      );
    }
    expect(find.text('Pasti di oggi e check-in'), findsOneWidget);

    await tester.tap(find.text('Dieta'));
    await tester.pumpAndSettle();
    expect(find.text('Piano e obiettivi'), findsOneWidget);

    await tester.tap(find.text('Andamento'));
    await tester.pumpAndSettle();
    expect(find.text('Peso, aderenza e commenti'), findsOneWidget);

    await tester.tap(find.text('Visite'));
    await tester.pumpAndSettle();
    expect(find.text('Prossima visita'), findsOneWidget);
  });

  testWidgets('il nutrizionista arriva su Pazienti e naviga tra le 3 sezioni', (
    tester,
  ) async {
    await avvia(tester, ruolo: Ruolo.nutrizionista);
    expect(find.text('Elenco, filtri e inviti'), findsOneWidget);

    await tester.tap(find.text('Calendario'));
    await tester.pumpAndSettle();
    expect(find.text('Visite e slot liberi'), findsOneWidget);

    await tester.tap(find.text('Profilo'));
    await tester.pumpAndSettle();
    expect(find.text('Profilo e abbonamento'), findsOneWidget);
    expect(find.text('Dott.ssa Giulia'), findsOneWidget);
  });

  testWidgets('dopo il login il router sceglie la home del ruolo', (
    tester,
  ) async {
    final auth = await avvia(tester);
    auth.simulaAccesso(Ruolo.nutrizionista);
    await tester.pumpAndSettle();
    expect(find.text('Elenco, filtri e inviti'), findsOneWidget);
  });

  testWidgets('il logout dal profilo del paziente torna all\'accesso', (
    tester,
  ) async {
    await avvia(tester, ruolo: Ruolo.paziente);
    await tester.tap(find.byTooltip('Profilo'));
    await tester.pumpAndSettle();
    expect(find.text('Marco'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Esci'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Esci'));
    await tester.pumpAndSettle();
    expect(find.text('Cenato · accesso di prova'), findsOneWidget);
  });

  group('reindirizza (guard)', () {
    test('senza sessione porta all\'accesso, tranne le pagine pubbliche', () {
      final auth = AuthRepositoryFinto();
      expect(reindirizza(auth, Rotte.pazienteOggi), Rotte.accesso);
      expect(reindirizza(auth, Rotte.nutPazienti), Rotte.accesso);
      expect(reindirizza(auth, Rotte.recuperoPassword), isNull);
      expect(reindirizza(auth, Rotte.registrazione), isNull);
    });

    test('ogni ruolo resta nella propria area', () {
      final paziente = AuthRepositoryFinto(ruoloIniziale: Ruolo.paziente);
      final nut = AuthRepositoryFinto(ruoloIniziale: Ruolo.nutrizionista);
      expect(reindirizza(paziente, Rotte.nutPazienti), Rotte.pazienteOggi);
      expect(reindirizza(nut, Rotte.pazienteDieta), Rotte.nutPazienti);
      expect(reindirizza(paziente, Rotte.pazienteVisite), isNull);
      expect(reindirizza(nut, Rotte.nutCalendario), isNull);
    });

    test('con sessione le pagine di accesso portano alla home', () {
      final paziente = AuthRepositoryFinto(ruoloIniziale: Ruolo.paziente);
      expect(reindirizza(paziente, Rotte.accesso), Rotte.pazienteOggi);
    });
  });
}
