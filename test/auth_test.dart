import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/core/costanti/informativa.dart';
import 'package:cenato/data/finto/dipendenze_finte.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/domain/regole/validazione.dart';
import 'package:cenato/domain/repository/auth_repository.dart';
import 'package:cenato/domain/repository/pazienti_repository.dart';
import 'package:cenato/main.dart';
import 'package:cenato/presentation/comuni/componenti.dart';

/// Schede della fase 1: Registrazione con consenso, Accesso e recupero
/// password, Accettazione invito. Flussi delle schermate con dati finti.
void main() {
  Future<DipendenzeFinte> avvia(WidgetTester tester, {Ruolo? ruolo}) async {
    // Schermo alto: l'informativa e la casella del consenso restano visibili.
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final finte = DipendenzeFinte(ruolo: ruolo);
    await tester.pumpWidget(CenatoApp(dip: finte.dip));
    await tester.pumpAndSettle();
    return finte;
  }

  Future<void> scrivi(
    WidgetTester tester,
    String etichetta,
    String testo,
  ) async {
    await tester.enterText(find.widgetWithText(TextField, etichetta), testo);
  }

  Future<void> tocca(WidgetTester tester, Finder f) async {
    // Come farebbe l'utente: scorre fino al pulsante prima di toccarlo.
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> compilaModulo(
    WidgetTester tester, {
    String nome = 'Giulia Rinaldi',
    String email = 'giulia@studio.it',
    String password = 'Cenato2026',
    String? conferma,
    String? codice,
  }) async {
    if (codice != null) await scrivi(tester, 'Codice di invito', codice);
    await scrivi(tester, 'Nome e cognome', nome);
    await scrivi(tester, 'Email', email);
    await scrivi(tester, 'Password', password);
    await scrivi(tester, 'Ripeti la password', conferma ?? password);
  }

  Future<void> vaiARegistrazione(WidgetTester tester) =>
      tocca(tester, find.text('Non hai un account? Registrati'));

  group('Validazione', () {
    test('email', () {
      expect(Validazione.email(''), isNotNull);
      expect(Validazione.email('senza-chiocciola'), isNotNull);
      expect(Validazione.email('a@b'), isNotNull);
      expect(Validazione.email(' mario@esempio.it '), isNull);
    });

    test('password: almeno 8 caratteri con lettere e numeri', () {
      expect(Validazione.password('corta1'), contains('almeno 8'));
      expect(
        Validazione.password('soloLettereQui'),
        contains('lettera e un numero'),
      );
      expect(Validazione.password('12345678'), contains('lettera e un numero'));
      expect(Validazione.password('Cenato2026'), isNull);
    });

    test('conferma password', () {
      expect(Validazione.conferma('Cenato2026', 'Cenato2027'), isNotNull);
      expect(Validazione.conferma('Cenato2026', 'Cenato2026'), isNull);
    });

    test('codice di invito: si normalizza e se ne controlla il formato', () {
      expect(Validazione.normalizzaCodice(' ab cd 2345 '), 'ABCD2345');
      expect(Validazione.codiceInvito(''), isNotNull);
      expect(Validazione.codiceInvito('AB'), isNotNull);
      expect(Validazione.codiceInvito('ab-cd!'), isNotNull);
      expect(Validazione.codiceInvito('jxqnbv5j'), isNull);
    });

    test('altezza facoltativa tra 50 e 250 cm', () {
      expect(Validazione.altezzaCm(''), isNull);
      expect(Validazione.altezzaCm('178,5'), isNull);
      expect(Validazione.altezzaCm('20'), isNotNull);
      expect(Validazione.altezzaCm('abc'), isNotNull);
    });
  });

  group('Registrazione', () {
    testWidgets(
      'nutrizionista: 3 passi, consenso salvato con versione, poi disponibilità',
      (tester) async {
        final finte = await avvia(tester);
        await vaiARegistrazione(tester);
        expect(find.text('Passo 1 di 3'), findsOneWidget);

        await tocca(tester, find.byKey(const Key('ruolo-nutrizionista')));
        expect(find.text('Passo 2 di 3'), findsOneWidget);
        expect(
          find.text('Codice di invito'),
          findsNothing,
        ); // solo per il paziente
        await compilaModulo(tester);
        await tocca(tester, find.text('Continua'));

        expect(find.text('Passo 3 di 3'), findsOneWidget);
        expect(find.text(Informativa.titolo), findsOneWidget);

        // Senza consenso non si prosegue e si spiega perché.
        await tocca(tester, find.text('Crea account'));
        expect(find.byKey(const Key('consenso-obbligatorio')), findsOneWidget);
        expect(finte.auth.ultimaEmail, isNull);

        await tocca(tester, find.byKey(const Key('casella-consenso')));
        await tocca(tester, find.text('Crea account'));
        expect(finte.auth.ultimaEmail, 'giulia@studio.it');
        expect(finte.auth.ultimaVersioneInformativa, Informativa.versione);

        // Subito dopo: passo disponibilità (segnaposto) e "Più tardi".
        expect(find.text('Quando ricevi?'), findsOneWidget);
        await tocca(tester, find.byKey(const Key('piu-tardi')));
        expect(find.text('Elenco, filtri e inviti'), findsOneWidget);
      },
    );

    testWidgets('campi vuoti o non validi: errore sul campo giusto', (
      tester,
    ) async {
      await avvia(tester);
      await vaiARegistrazione(tester);
      await tocca(tester, find.byKey(const Key('ruolo-nutrizionista')));

      await tocca(tester, find.text('Continua'));
      expect(find.text('Inserisci il tuo nome.'), findsOneWidget);
      expect(find.text('Inserisci la tua email.'), findsOneWidget);
      expect(find.text('Scegli una password.'), findsOneWidget);
      expect(find.text('Passo 2 di 3'), findsOneWidget);

      await compilaModulo(
        tester,
        email: 'non-valida',
        password: 'corta',
        conferma: 'altra',
      );
      await tocca(tester, find.text('Continua'));
      expect(find.text('Questa email non sembra valida.'), findsOneWidget);
      expect(find.text('Usa almeno 8 caratteri.'), findsOneWidget);
      expect(find.text('Le due password non coincidono.'), findsOneWidget);
      expect(find.text('Passo 2 di 3'), findsOneWidget);
    });

    testWidgets(
      'email già registrata: si torna al modulo con l\'errore sull\'email',
      (tester) async {
        final finte = await avvia(tester);
        await vaiARegistrazione(tester);
        await tocca(tester, find.byKey(const Key('ruolo-nutrizionista')));
        await compilaModulo(tester);
        await tocca(tester, find.text('Continua'));
        await tocca(tester, find.byKey(const Key('casella-consenso')));

        finte.auth.erroreProssimaOperazione = const ErroreAuth(
          'Esiste già un account con questa email.',
          codice: 'user_already_exists',
        );
        await tocca(tester, find.text('Crea account'));

        expect(find.text('Passo 2 di 3'), findsOneWidget);
        expect(
          find.text('Esiste già un account con questa email.'),
          findsOneWidget,
        );
        // I dati inseriti non si perdono.
        expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Email'))
              .controller!
              .text,
          'giulia@studio.it',
        );
      },
    );

    testWidgets(
      'rete assente: messaggio con "Riprova", senza perdere il consenso',
      (tester) async {
        final finte = await avvia(tester);
        await vaiARegistrazione(tester);
        await tocca(tester, find.byKey(const Key('ruolo-nutrizionista')));
        await compilaModulo(tester);
        await tocca(tester, find.text('Continua'));
        await tocca(tester, find.byKey(const Key('casella-consenso')));

        finte.auth.erroreProssimaOperazione = const ErroreAuth(
          'Connessione non riuscita. Controlla la rete e riprova.',
          codice: 'rete',
        );
        await tocca(tester, find.text('Crea account'));
        expect(find.byKey(const Key('messaggio-errore')), findsOneWidget);
        expect(find.text('Passo 3 di 3'), findsOneWidget);

        await tocca(tester, find.text('Riprova'));
        expect(finte.auth.ultimaEmail, 'giulia@studio.it');
        expect(find.text('Quando ricevi?'), findsOneWidget);
      },
    );

    testWidgets('email da confermare: "Controlla la tua email"', (
      tester,
    ) async {
      final finte = await avvia(tester);
      finte.auth.sessioneDopoRegistrazione = false;
      await vaiARegistrazione(tester);
      await tocca(tester, find.byKey(const Key('ruolo-nutrizionista')));
      await compilaModulo(tester);
      await tocca(tester, find.text('Continua'));
      await tocca(tester, find.byKey(const Key('casella-consenso')));
      await tocca(tester, find.text('Crea account'));

      expect(find.text('Controlla la tua email'), findsOneWidget);
      expect(find.textContaining('giulia@studio.it'), findsOneWidget);
      await tocca(tester, find.byKey(const Key('vai-all-accesso')));
      expect(find.widgetWithText(FilledButton, 'Accedi'), findsOneWidget);
    });

    testWidgets(
      'paziente: codice verificato, "Sei stato invitato da", poi collegato e su Oggi',
      (tester) async {
        final finte = await avvia(tester);
        await vaiARegistrazione(tester);
        await tocca(tester, find.byKey(const Key('ruolo-paziente')));
        expect(find.text('Codice di invito'), findsOneWidget);

        await compilaModulo(
          tester,
          nome: 'Marco Esposito',
          email: 'marco@esempio.it',
          codice: 'valido01',
        );
        await tocca(tester, find.text('Continua'));
        expect(
          find.text('Passo 3 di 3'),
          findsOneWidget,
        ); // al massimo 3 schermate (RNF_U_4)
        expect(
          find.text('Sei stato invitato da Dott.ssa Giulia Rinaldi.'),
          findsOneWidget,
        );

        await tocca(tester, find.byKey(const Key('casella-consenso')));
        await tocca(tester, find.text('Crea account'));

        expect(finte.collegamento.accettati, ['VALIDO01']);
        expect(
          find.text('Il tuo nutrizionista sta preparando il piano'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'paziente: codice scaduto, usato, revocato o sbagliato hanno messaggi distinti',
      (tester) async {
        await avvia(tester);
        await vaiARegistrazione(tester);
        await tocca(tester, find.byKey(const Key('ruolo-paziente')));

        final casi = {
          'SCADUTO1': 'Il codice è scaduto',
          'USATO001': 'già stato usato',
          'REVOCATO1': 'annullato dal nutrizionista',
          'SBAGLIAT': 'Codice non valido',
        };
        for (final e in casi.entries) {
          await compilaModulo(
            tester,
            nome: 'Marco',
            email: 'm@esempio.it',
            codice: e.key,
          );
          await tocca(tester, find.text('Continua'));
          expect(find.textContaining(e.value), findsOneWidget, reason: e.key);
          expect(
            find.text('Passo 2 di 3'),
            findsOneWidget,
            reason: 'resta nel modulo: ${e.key}',
          );
        }
      },
    );

    testWidgets('si torna indietro tra i passi', (tester) async {
      await avvia(tester);
      await vaiARegistrazione(tester);
      await tocca(tester, find.byKey(const Key('ruolo-nutrizionista')));
      await tocca(tester, find.byTooltip('Indietro'));
      expect(find.text('Passo 1 di 3'), findsOneWidget);
      await tocca(tester, find.byTooltip('Indietro'));
      expect(find.widgetWithText(FilledButton, 'Accedi'), findsOneWidget);
    });
  });

  group('Accesso e recupero password', () {
    testWidgets(
      'credenziali errate: messaggio e "Password dimenticata?" in evidenza',
      (tester) async {
        final finte = await avvia(tester);
        finte.auth.erroreProssimaOperazione = const ErroreAuth(
          'Email o password non corretti.',
          codice: 'invalid_credentials',
        );
        await scrivi(tester, 'Email', 'marco@esempio.it');
        await scrivi(tester, 'Password', 'sbagliata1');
        await tocca(tester, find.widgetWithText(FilledButton, 'Accedi'));

        expect(find.text('Email o password non corretti.'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Password dimenticata?'),
          findsOneWidget,
        );
        // L'email resta nel campo.
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Email'))
              .controller!
              .text,
          'marco@esempio.it',
        );
      },
    );

    testWidgets('campi vuoti: errore sul campo', (tester) async {
      await avvia(tester);
      await tocca(tester, find.widgetWithText(FilledButton, 'Accedi'));
      expect(find.text('Inserisci la tua email.'), findsOneWidget);
      expect(find.text('Inserisci la password.'), findsOneWidget);
    });

    testWidgets('rete assente: "Riprova" e poi si entra', (tester) async {
      final finte = await avvia(tester);
      finte.auth.erroreProssimaOperazione = const ErroreAuth(
        'Connessione non riuscita.',
        codice: 'rete',
      );
      await scrivi(tester, 'Email', 'nut@studio.it');
      await scrivi(tester, 'Password', 'Cenato2026');
      await tocca(tester, find.widgetWithText(FilledButton, 'Accedi'));
      await tocca(tester, find.text('Riprova'));
      expect(find.text('Elenco, filtri e inviti'), findsOneWidget);
    });

    testWidgets('logout riporta all\'accesso', (tester) async {
      final finte = await avvia(tester, ruolo: Ruolo.nutrizionista);
      await finte.auth.esci();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Accedi'), findsOneWidget);
    });

    testWidgets('recupero password: stessa conferma e richiesta inviata', (
      tester,
    ) async {
      final finte = await avvia(tester);
      await tocca(tester, find.text('Password dimenticata?'));
      expect(find.text('Hai dimenticato la password?'), findsOneWidget);

      await tocca(tester, find.text('Invia il link'));
      expect(find.text('Inserisci la tua email.'), findsOneWidget);
      expect(finte.auth.richiesteReset, isEmpty);

      await scrivi(tester, 'Email', 'chiunque@esempio.it');
      await tocca(tester, find.text('Invia il link'));
      expect(find.byKey(const Key('recupero-inviato')), findsOneWidget);
      expect(
        find.textContaining('Se l\'indirizzo è registrato'),
        findsOneWidget,
      );
      expect(finte.auth.richiesteReset, ['chiunque@esempio.it']);
    });

    testWidgets('recupero password: rete assente con "Riprova"', (
      tester,
    ) async {
      final finte = await avvia(tester);
      await tocca(tester, find.text('Password dimenticata?'));
      finte.auth.erroreProssimaOperazione = const ErroreAuth(
        'Connessione non riuscita.',
        codice: 'rete',
      );
      await scrivi(tester, 'Email', 'a@esempio.it');
      await tocca(tester, find.text('Invia il link'));
      expect(find.byKey(const Key('messaggio-errore')), findsOneWidget);
      await tocca(tester, find.text('Riprova'));
      expect(find.byKey(const Key('recupero-inviato')), findsOneWidget);
    });

    testWidgets('rientro dal link: nuova password e poi la home', (
      tester,
    ) async {
      final finte = await avvia(tester, ruolo: Ruolo.paziente);
      finte.auth.simulaRecuperoPassword();
      await tester.pumpAndSettle();
      expect(find.text('Scegli una nuova password'), findsOneWidget);

      await scrivi(tester, 'Nuova password', 'Nuova2026x');
      await scrivi(tester, 'Ripeti la password', 'Diversa2026');
      await tocca(tester, find.text('Salva la password'));
      expect(find.text('Le due password non coincidono.'), findsOneWidget);

      await scrivi(tester, 'Ripeti la password', 'Nuova2026x');
      await tocca(tester, find.text('Salva la password'));
      expect(
        find.text('Il tuo nutrizionista sta preparando il piano'),
        findsOneWidget,
      );
    });
  });

  group('Accettazione invito', () {
    testWidgets(
      'paziente non collegato: schermata del codice con messaggi distinti',
      (tester) async {
        final finte = await avvia(tester, ruolo: Ruolo.paziente);
        finte.auth.scollega(); // come dopo uno scollegamento
        await tester.pumpAndSettle();
        expect(find.text('Collegati al tuo nutrizionista'), findsOneWidget);

        await scrivi(tester, 'Codice di invito', 'USATO001');
        await tocca(tester, find.text('Verifica il codice'));
        expect(find.textContaining('già stato usato'), findsOneWidget);

        await scrivi(tester, 'Codice di invito', 'ab');
        await tocca(tester, find.text('Verifica il codice'));
        expect(find.textContaining('da 6 a 12'), findsOneWidget);
        expect(finte.collegamento.accettati, isEmpty);
      },
    );

    testWidgets(
      'codice valido: "Sei stato invitato da", conferma e sezione Oggi',
      (tester) async {
        final finte = await avvia(tester, ruolo: Ruolo.paziente);
        finte.auth.scollega();
        await tester.pumpAndSettle();

        await scrivi(tester, 'Codice di invito', 'valido01');
        await tocca(tester, find.text('Verifica il codice'));
        expect(
          find.text('Sei stato invitato da Dott.ssa Giulia Rinaldi.'),
          findsOneWidget,
        );

        await tocca(tester, find.text('Conferma e collegati'));
        expect(finte.collegamento.accettati, ['VALIDO01']);
        expect(
          find.text('Il tuo nutrizionista sta preparando il piano'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'rete assente alla conferma: "Riprova" senza perdere il codice',
      (tester) async {
        final finte = await avvia(tester, ruolo: Ruolo.paziente);
        finte.auth.scollega();
        await tester.pumpAndSettle();
        await scrivi(tester, 'Codice di invito', 'VALIDO01');
        await tocca(tester, find.text('Verifica il codice'));

        finte.collegamento.erroreProssimaAccettazione = const ErroreOperazione(
          'Connessione non riuscita.',
          codice: 'rete',
        );
        await tocca(tester, find.text('Conferma e collegati'));
        expect(find.byKey(const Key('messaggio-errore')), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.widgetWithText(TextField, 'Codice di invito'),
              )
              .controller!
              .text,
          'VALIDO01',
        );

        await tocca(tester, find.text('Riprova'));
        expect(
          find.text('Il tuo nutrizionista sta preparando il piano'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'dopo lo scollegamento il paziente torna alla schermata del codice',
      (tester) async {
        await avvia(tester, ruolo: Ruolo.paziente);
        await tocca(tester, find.byTooltip('Profilo'));
        await tocca(tester, find.text('Interrompi il collegamento'));
        await tocca(tester, find.widgetWithText(FilledButton, 'Interrompi'));
        expect(find.text('Collegati al tuo nutrizionista'), findsOneWidget);
      },
    );

    testWidgets('il nutrizionista non vede la schermata del codice', (
      tester,
    ) async {
      await avvia(tester, ruolo: Ruolo.nutrizionista);
      expect(find.text('Collegati al tuo nutrizionista'), findsNothing);
    });
  });

  group('Aspetto su telefono stretto e testo grande', () {
    // 320 dp di larghezza e testo di sistema al 200% (RNF_U_3).
    Future<void> avviaStretto(WidgetTester tester) async {
      tester.view.physicalSize = const Size(640, 1600);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(CenatoApp(dip: DipendenzeFinte().dip));
      await tester.pumpAndSettle();
    }

    testWidgets('accesso: marchio tonale e nessun overflow', (tester) async {
      await avviaStretto(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(IconaTonale), findsOneWidget);
      expect(find.text('Accedi'), findsWidgets);
    });

    testWidgets('registrazione: i tre passi senza overflow', (tester) async {
      await avviaStretto(tester);
      await vaiARegistrazione(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(IconaTonale), findsNWidgets(2));

      await tocca(tester, find.byKey(const Key('ruolo-nutrizionista')));
      await compilaModulo(tester);
      expect(tester.takeException(), isNull);

      await tocca(tester, find.text('Continua'));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('casella-consenso')), findsOneWidget);
    });

    testWidgets('recupero password: nessun overflow', (tester) async {
      await avviaStretto(tester);
      await tocca(tester, find.text('Password dimenticata?'));
      expect(tester.takeException(), isNull);
    });
  });
}
