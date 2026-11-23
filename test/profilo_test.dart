import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/data/finto/dipendenze_finte.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/domain/repository/pazienti_repository.dart';
import 'package:cenato/main.dart';

/// Scheda "Profilo ed eliminazione account" (UC_GA_3, UC_GA_5).
void main() {
  Future<DipendenzeFinte> avvia(WidgetTester tester, Ruolo ruolo) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final finte = DipendenzeFinte(ruolo: ruolo);
    await tester.pumpWidget(CenatoApp(dip: finte.dip));
    await tester.pumpAndSettle();
    return finte;
  }

  Future<void> tocca(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> scrivi(
    WidgetTester tester,
    String etichetta,
    String testo,
  ) async {
    await tester.enterText(find.widgetWithText(TextField, etichetta), testo);
  }

  Future<void> apriProfiloPaziente(WidgetTester tester) =>
      tocca(tester, find.byTooltip('Profilo'));

  Future<void> apriProfiloNutrizionista(WidgetTester tester) async {
    await tocca(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profilo'),
      ),
    );
  }

  String testoCampo(WidgetTester tester, String etichetta) => tester
      .widget<TextField>(find.widgetWithText(TextField, etichetta))
      .controller!
      .text;

  group('Modifica del profilo', () {
    testWidgets('paziente: nome, altezza e obiettivo si salvano', (
      tester,
    ) async {
      final finte = await avvia(tester, Ruolo.paziente);
      await apriProfiloPaziente(tester);
      expect(find.text('Altezza (cm)'), findsOneWidget);
      expect(find.text('Il tuo obiettivo'), findsOneWidget);

      await scrivi(tester, 'Nome e cognome', 'Marco E. Esposito');
      await scrivi(tester, 'Altezza (cm)', '178,5');
      await scrivi(tester, 'Il tuo obiettivo', 'Mangiare a orari regolari');
      await tocca(tester, find.text('Salva le modifiche'));

      expect(find.text('Profilo aggiornato.'), findsOneWidget);
      final dati = await finte.profilo.leggi();
      expect(dati.nome, 'Marco E. Esposito');
      expect(dati.altezzaCm, 178.5);
      expect(dati.obiettivo, 'Mangiare a orari regolari');
      expect(
        finte.auth.profilo!.nome,
        'Marco E. Esposito',
      ); // si aggiorna ovunque
    });

    testWidgets('valori non validi: errore sul campo e nulla viene salvato', (
      tester,
    ) async {
      final finte = await avvia(tester, Ruolo.paziente);
      await apriProfiloPaziente(tester);
      await scrivi(tester, 'Nome e cognome', '');
      await scrivi(tester, 'Altezza (cm)', '20');
      await tocca(tester, find.text('Salva le modifiche'));

      expect(find.text('Inserisci il tuo nome.'), findsOneWidget);
      expect(find.textContaining('tra 50 e 250'), findsOneWidget);
      expect((await finte.profilo.leggi()).nome, 'Marco');
    });

    testWidgets(
      'salvataggio fallito: "Riprova" senza perdere ciò che è stato digitato',
      (tester) async {
        final finte = await avvia(tester, Ruolo.paziente);
        await apriProfiloPaziente(tester);
        await scrivi(tester, 'Nome e cognome', 'Marco Rossi');
        finte.profilo.erroreProssimaOperazione = const ErroreOperazione(
          'Connessione non riuscita. Controlla la rete e riprova.',
          codice: 'rete',
        );
        await tocca(tester, find.text('Salva le modifiche'));
        expect(find.byKey(const Key('messaggio-errore')), findsOneWidget);
        expect(testoCampo(tester, 'Nome e cognome'), 'Marco Rossi');

        await tocca(tester, find.text('Riprova'));
        expect(find.text('Profilo aggiornato.'), findsOneWidget);
        expect((await finte.profilo.leggi()).nome, 'Marco Rossi');
      },
    );

    testWidgets(
      'nutrizionista: nome e titolo, accesso a disponibilità e abbonamento',
      (tester) async {
        final finte = await avvia(tester, Ruolo.nutrizionista);
        await apriProfiloNutrizionista(tester);
        expect(find.text('Altezza (cm)'), findsNothing);
        expect(find.text('Il tuo piano'), findsOneWidget); // abbonamento

        await scrivi(
          tester,
          'Titolo (es. biologa nutrizionista)',
          'Biologa nutrizionista',
        );
        await tocca(tester, find.text('Salva le modifiche'));
        expect((await finte.profilo.leggi()).titolo, 'Biologa nutrizionista');

        await tocca(tester, find.byKey(const Key('apri-disponibilita')));
        expect(find.text('Quando ricevi?'), findsOneWidget);
        await tocca(tester, find.byKey(const Key('piu-tardi')));
        expect(find.text('Il tuo piano'), findsOneWidget); // torna al profilo
      },
    );

    testWidgets('il logout dal profilo torna all\'accesso', (tester) async {
      await avvia(tester, Ruolo.nutrizionista);
      await apriProfiloNutrizionista(tester);
      await tocca(tester, find.widgetWithText(OutlinedButton, 'Esci'));
      await tocca(tester, find.widgetWithText(FilledButton, 'Esci'));
      expect(find.widgetWithText(FilledButton, 'Accedi'), findsOneWidget);
    });
  });

  group('Eliminazione account', () {
    testWidgets(
      'paziente: serve scrivere ELIMINA, poi si esce e il profilo è cancellato',
      (tester) async {
        final finte = await avvia(tester, Ruolo.paziente);
        await apriProfiloPaziente(tester);
        await tocca(tester, find.byKey(const Key('apri-elimina-account')));

        expect(find.text('Questa azione è definitiva'), findsOneWidget);
        expect(
          find.textContaining('Account eliminato'),
          findsOneWidget,
        ); // cosa vede il nutrizionista

        FilledButton pulsante() => tester.widget<FilledButton>(
          find.byKey(const Key('conferma-elimina')),
        );
        expect(pulsante().onPressed, isNull);

        await scrivi(tester, 'Scrivi ELIMINA per confermare', 'elimina');
        await tester.pump();
        expect(
          pulsante().onPressed,
          isNull,
          reason: 'va scritto proprio ELIMINA',
        );

        await scrivi(tester, 'Scrivi ELIMINA per confermare', 'ELIMINA');
        await tester.pump();
        expect(pulsante().onPressed, isNotNull);

        await tocca(tester, find.byKey(const Key('conferma-elimina')));
        expect(finte.profilo.eliminato, isTrue);
        expect(
          find.widgetWithText(FilledButton, 'Accedi'),
          findsOneWidget,
        ); // fuori
        expect(
          find.text('Il tuo account e i tuoi dati sono stati eliminati.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('nutrizionista: spiega cosa succede ai pazienti collegati', (
      tester,
    ) async {
      await avvia(tester, Ruolo.nutrizionista);
      await apriProfiloNutrizionista(tester);
      await tocca(tester, find.byKey(const Key('apri-elimina-account')));

      expect(
        find.textContaining('Gli account dei tuoi pazienti restano'),
        findsOneWidget,
      );
      expect(find.textContaining('i pazienti'), findsWidgets);
      // I pazienti di prova (3 attivi + 1 archiviato) sono contati.
      expect(find.textContaining('Hai 4 pazienti'), findsOneWidget);
    });

    testWidgets('errore di rete: "Riprova" e poi l\'account è eliminato', (
      tester,
    ) async {
      final finte = await avvia(tester, Ruolo.paziente);
      await apriProfiloPaziente(tester);
      await tocca(tester, find.byKey(const Key('apri-elimina-account')));
      await scrivi(tester, 'Scrivi ELIMINA per confermare', 'ELIMINA');
      await tester.pump();

      finte.profilo.erroreProssimaOperazione = const ErroreOperazione(
        'Connessione non riuscita.',
        codice: 'rete',
      );
      await tocca(tester, find.byKey(const Key('conferma-elimina')));
      expect(find.byKey(const Key('messaggio-errore')), findsOneWidget);
      expect(finte.profilo.eliminato, isFalse);

      await tocca(tester, find.text('Riprova'));
      expect(finte.profilo.eliminato, isTrue);
    });

    testWidgets('si può annullare', (tester) async {
      final finte = await avvia(tester, Ruolo.paziente);
      await apriProfiloPaziente(tester);
      await tocca(tester, find.byKey(const Key('apri-elimina-account')));
      await tocca(tester, find.widgetWithText(OutlinedButton, 'Annulla'));
      expect(
        find.text('Elimina il mio account'),
        findsOneWidget,
      ); // di nuovo nel profilo
      expect(finte.profilo.eliminato, isFalse);
    });

    testWidgets(
      'un paziente non collegato può eliminare l\'account dalla schermata del codice',
      (tester) async {
        final finte = await avvia(tester, Ruolo.paziente);
        finte.auth.scollega();
        await tester.pumpAndSettle();

        await tocca(
          tester,
          find.byKey(const Key('elimina-account-da-collegamento')),
        );
        expect(find.text('Questa azione è definitiva'), findsOneWidget);
      },
    );
  });
}
