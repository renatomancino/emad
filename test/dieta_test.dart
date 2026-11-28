import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/core/dipendenze.dart';
import 'package:cenato/core/tema/tema.dart';
import 'package:cenato/data/finto/piani_repository_finto.dart';
import 'package:cenato/data/finto/dieta_finta.dart';
import 'package:cenato/data/finto/dipendenze_finte.dart';
import 'package:cenato/domain/modelli/alimento.dart';
import 'package:cenato/domain/modelli/piano_alimentare.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/domain/repository/pazienti_repository.dart'
    show ErroreOperazione;
import 'package:cenato/domain/regole/calcoli_piano.dart';
import 'package:cenato/main.dart';
import 'package:cenato/presentation/nutrizionista/piano/riepilogo_giorno.dart'
    show kcalTesto;
import 'package:cenato/presentation/paziente/dieta_page.dart';

/// Scheda "[MC] Sezione Dieta del paziente": UC_GP_4, RF_GP_8, RF_GP_16,
/// RNF_U_3, RNF_U_6. Solo repository finti: nessun database, nessun
/// dispositivo.

/// Lunedì 23/11/2026: il giorno "oggi" dei test, fisso.
DateTime _lunedi() => DateTime(2026, 11, 23, 9);

const _mela = Alimento(
  id: 't-mela',
  nome: 'Mela',
  kcal100g: 52,
  proteine100g: 0.3,
  carboidrati100g: 14,
  grassi100g: 0.2,
  fonte: FonteAlimento.personalizzato,
);

/// Piano minimo con i soli giorni [giorni], un pasto ciascuno.
PianoAlimentare _pianoGiorni(List<int> giorni) => PianoAlimentare(
  dataInizio: DateTime(2026, 11, 16),
  giorni: [
    for (final g in giorni)
      GiornoPiano(
        giornoSettimana: g,
        pasti: [
          PastoPiano(
            tipo: TipoPasto.merenda,
            voci: [VocePiano(alimento: _mela, quantitaG: 150)],
          ),
        ],
      ),
  ],
);

/// Piani finti che, con [silenzioso], non avvisano i listener.
class _PianiSilenziosi extends PianiRepositoryFinto {
  bool silenzioso = false;

  @override
  void notifyListeners() {
    if (!silenzioso) super.notifyListeners();
  }
}

void main() {
  /// Schermo alto (come navigazione_test) per vedere un giorno intero.
  void schermoAlto(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  /// Paziente simulato collegato; [conPiano] carica i dati di prova di
  /// `main.dart` (obiettivi sempre, piano se richiesto).
  Future<DipendenzeFinte> dipendenze({bool conPiano = true}) async {
    final finte = DipendenzeFinte(ruolo: Ruolo.paziente);
    await DietaFinta.carica(finte, conPiano: conPiano);
    return finte;
  }

  Future<void> apri(
    WidgetTester tester,
    DipendenzeFinte finte, {
    double scalaTesto = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCenato(),
        home: MediaQuery(
          data: MediaQueryData(
            size: tester.view.physicalSize / tester.view.devicePixelRatio,
            textScaler: TextScaler.linear(scalaTesto),
          ),
          child: DietaPage(dip: finte.dip, adesso: _lunedi),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Come nel mock-up UI_GP_1, la card degli obiettivi è larga quanto la
  // pagina (meno i 16 dp di margine per lato), con il piano e senza.
  for (final conPiano in [true, false]) {
    testWidgets('card degli obiettivi a tutta larghezza '
        '(${conPiano ? 'con' : 'senza'} piano, RNF_U_3)', (tester) async {
      // Schermo largo (900 dp): con il font dei test, più largo di quello
      // vero, su uno schermo stretto il contenuto riempirebbe comunque
      // tutta la riga e il difetto non si vedrebbe.
      schermoAlto(tester);
      tester.view.physicalSize = const Size(2250, 4200);
      await apri(tester, await dipendenze(conPiano: conPiano));
      final pagina =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(
        tester.getSize(find.byKey(const Key('obiettivi-dieta'))).width,
        pagina - 32,
      );
    });
  }

  group('Con piano (UC_GP_4 flusso principale, RF_GP_8, RF_GP_16)', () {
    testWidgets('obiettivi, versione, giorno di oggi, pasti e totali', (
      tester,
    ) async {
      schermoAlto(tester);
      final finte = await dipendenze();
      await apri(tester, finte);

      // Intestazione: versione e data di inizio; data dell'aggiornamento.
      expect(find.textContaining('Piano versione 1 · dal '), findsOneWidget);
      expect(find.byKey(const Key('piano-aggiornato-il')), findsOneWidget);

      // Obiettivi giornalieri (RF_GP_16: visibili al paziente).
      expect(find.text('I tuoi obiettivi giornalieri'), findsOneWidget);
      expect(find.text('2000'), findsOneWidget);
      expect(find.text('110 g'), findsOneWidget);
      expect(find.text('230 g'), findsOneWidget);
      expect(find.text('65 g'), findsOneWidget);

      // Selettore lunedì-domenica con il giorno corrente evidenziato a testo.
      expect(find.text('Lun · oggi'), findsOneWidget);
      for (final g in ['Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']) {
        expect(find.text(g), findsOneWidget, reason: 'pillola $g');
      }
      expect(find.text('Lunedì (oggi)'), findsOneWidget);

      // Pasti con alimenti, quantità, kcal e macro.
      for (final p in ['Colazione', 'Spuntino', 'Pranzo', 'Cena']) {
        expect(find.text(p), findsOneWidget, reason: 'pasto $p');
      }
      expect(find.text('Latte parzialmente scremato'), findsOneWidget);
      expect(find.text('200 g · 92 kcal'), findsOneWidget);
      expect(find.textContaining('Proteine '), findsWidgets);

      // Totale del giorno con i calcoli esistenti, confrontato con l'obiettivo.
      final piano = (await finte.piani.corrente('p1'))!;
      final totale = macroGiorno(piano.giorno(1)!);
      final testoTotale = tester
          .widget<Text>(find.byKey(const Key('totale-kcal')))
          .textSpan!
          .toPlainText();
      expect(
        testoTotale,
        '${kcalTesto(totale.kcal)} kcal  su 2000 di obiettivo',
      );
      expect(find.byKey(const Key('scostamento-kcal')), findsOneWidget);
    });

    testWidgets('alternative chiuse, si aprono solo in consultazione', (
      tester,
    ) async {
      schermoAlto(tester);
      await apri(tester, await dipendenze());

      expect(find.textContaining('Fette biscottate'), findsNothing);
      final pulsanti = find.widgetWithText(TextButton, 'Alternative (1)');
      expect(pulsanti, findsNWidgets(3)); // cereali, pasta, merluzzo
      await tester.tap(pulsanti.first);
      await tester.pumpAndSettle();
      expect(
        find.text('Al posto di Cereali integrali puoi scegliere:'),
        findsOneWidget,
      );
      // 35 g di fette biscottate a 410 kcal/100 g = 143,5 → "144 kcal".
      expect(find.text('• Fette biscottate · 35 g · 144 kcal'), findsOneWidget);
    });

    testWidgets('cambiando giorno cambiano i pasti', (tester) async {
      schermoAlto(tester);
      await apri(tester, await dipendenze());
      expect(find.text('Pasta integrale'), findsOneWidget);
      await tester.tap(find.text('Mer'));
      await tester.pumpAndSettle();
      expect(find.text('Mercoledì'), findsOneWidget);
      expect(find.text('Riso integrale'), findsOneWidget);
      expect(find.text('Petto di pollo'), findsOneWidget);
      expect(find.text('Pasta integrale'), findsNothing);
    });

    testWidgets('le alternative aperte non restano aperte cambiando giorno', (
      tester,
    ) async {
      // Ogni riga ha il proprio stato aperto/chiuso: senza una chiave Flutter
      // lo riusava per posizione e il Mercoledì ereditava quello del Lunedì.
      schermoAlto(tester);
      await apri(tester, await dipendenze());
      await tester.tap(
        find.widgetWithText(TextButton, 'Alternative (1)').first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Al posto di'), findsOneWidget);

      await tester.tap(find.text('Mer'));
      await tester.pumpAndSettle();
      expect(find.text('Mercoledì'), findsOneWidget);
      expect(find.textContaining('Al posto di'), findsNothing);
    });

    testWidgets('macro del pasto con un decimale e unità attaccata', (
      tester,
    ) async {
      // Colazione del lunedì: 200 g di latte e 40 g di cereali. Un decimale
      // come il totale del giorno; lo spazio prima di "g" è indivisibile
      // (U+00A0), così col testo grande il numero non resta senza unità.
      schermoAlto(tester);
      await apri(tester, await dipendenze());
      expect(
        find.text(
          'Proteine 10,4\u00A0g · Carboidrati 38,6\u00A0g · '
          'Grassi 4,8\u00A0g',
        ),
        findsOneWidget,
      );
    });

    testWidgets('nessuna azione di modifica', (tester) async {
      schermoAlto(tester);
      await apri(tester, await dipendenze());
      await tester.tap(
        find.widgetWithText(TextButton, 'Alternative (1)').first,
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byType(PopupMenuButton<Object>), findsNothing);
      expect(find.textContaining('Aggiungi'), findsNothing);
      expect(find.textContaining('Salva'), findsNothing);
      expect(find.textContaining('Elimina'), findsNothing);
      for (final icona in [
        Icons.delete_outline,
        Icons.edit,
        Icons.edit_outlined,
        Icons.add,
        Icons.drag_handle,
      ]) {
        expect(find.byIcon(icona), findsNothing, reason: 'icona $icona');
      }
      // Il pulsante delle alternative dell'editor ha la chiave
      // "alternative-…": qui non deve esserci.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('alternative-'),
        ),
        findsNothing,
      );
      // Unico IconButton: il profilo nell'intestazione.
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byTooltip('Profilo'), findsOneWidget);
    });
  });

  group('Senza piano (UC_GP_4 flusso 2.1)', () {
    testWidgets('stato vuoto e obiettivi comunque visibili', (tester) async {
      schermoAlto(tester);
      await apri(tester, await dipendenze(conPiano: false));
      expect(
        find.text('Il tuo nutrizionista sta preparando il piano'),
        findsOneWidget,
      );
      expect(find.text('Piano e obiettivi'), findsOneWidget);
      expect(find.text('I tuoi obiettivi giornalieri'), findsOneWidget);
      expect(find.text('2000'), findsOneWidget);
      expect(find.byKey(const Key('piano-aggiornato-il')), findsNothing);
    });

    testWidgets('senza obiettivi lo dice, senza errori', (tester) async {
      schermoAlto(tester);
      await apri(tester, DipendenzeFinte(ruolo: Ruolo.paziente));
      expect(
        find.text('Il tuo nutrizionista sta preparando il piano'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Il tuo nutrizionista non ha ancora impostato gli obiettivi.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('usa l\'id della riga pazienti, non l\'id utente (D18)', (
      tester,
    ) async {
      schermoAlto(tester);
      final finte = DipendenzeFinte(ruolo: Ruolo.paziente);
      // Un piano salvato sotto l'id utente finto non è "il piano di Marco".
      await finte.piani.salva('finto-paziente', DietaFinta.piano());
      await apri(tester, finte);
      expect(
        find.text('Il tuo nutrizionista sta preparando il piano'),
        findsOneWidget,
      );
    });

    testWidgets('il piano assegnato poi compare da solo', (tester) async {
      schermoAlto(tester);
      final finte = await dipendenze(conPiano: false);
      await apri(tester, finte);
      await finte.piani.salva('p1', DietaFinta.piano());
      await tester.pumpAndSettle();
      expect(find.textContaining('Piano versione 1'), findsOneWidget);
      expect(find.text('Lun · oggi'), findsOneWidget);
    });
  });

  group('Errori e aggiornamenti', () {
    testWidgets('errore di rete al primo caricamento: "Riprova" funziona', (
      tester,
    ) async {
      schermoAlto(tester);
      final finte = await dipendenze();
      finte.collegamento.nonRaggiungibile = true;
      await apri(tester, finte);
      expect(find.text('Riprova'), findsOneWidget);
      expect(
        find.text('Connessione non riuscita. Controlla la rete e riprova.'),
        findsOneWidget,
      );

      finte.collegamento.nonRaggiungibile = false;
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(find.text('Riprova'), findsNothing);
      expect(find.text('Lun · oggi'), findsOneWidget);
    });

    testWidgets('errore del piano al primo caricamento: "Riprova"', (
      tester,
    ) async {
      schermoAlto(tester);
      final finte = await dipendenze();
      finte.piani.nonRaggiungibile = true;
      await apri(tester, finte);
      expect(find.text('Riprova'), findsOneWidget);
      finte.piani.nonRaggiungibile = false;
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(find.text('Latte parzialmente scremato'), findsOneWidget);
    });

    testWidgets('aggiornamento fallito: resta l\'ultimo piano (flusso 2.2)', (
      tester,
    ) async {
      schermoAlto(tester);
      final finte = await dipendenze();
      await apri(tester, finte);
      finte.piani.nonRaggiungibile = true;

      await tester.fling(
        find.text('Lunedì (oggi)'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Aggiornamento non riuscito: vedi l\'ultimo piano scaricato.',
        ),
        findsOneWidget,
      );
      expect(find.text('Riprova'), findsNothing);
      expect(find.text('Latte parzialmente scremato'), findsOneWidget);
    });

    testWidgets('tira per aggiornare mostra la nuova versione', (tester) async {
      schermoAlto(tester);
      final finte = await dipendenze();
      // Repository che salva SENZA avvisare: come una versione salvata dal
      // nutrizionista su un altro telefono. Solo il refresh manuale la vede.
      final silenziosi = _PianiSilenziosi();
      await silenziosi.salva('p1', DietaFinta.piano());
      silenziosi.silenzioso = true;
      final d = finte.dip;
      final dip = Dipendenze(
        auth: d.auth,
        pazienti: d.pazienti,
        abbonamento: d.abbonamento,
        collegamento: d.collegamento,
        profilo: d.profilo,
        alimenti: d.alimenti,
        obiettivi: d.obiettivi,
        piani: silenziosi,
        modelli: d.modelli,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: temaCenato(),
          home: DietaPage(dip: dip, adesso: _lunedi),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Piano versione 1'), findsOneWidget);

      await silenziosi.salva('p1', _pianoGiorni([1, 2]));
      await tester.pumpAndSettle();
      // Nessun avviso: la pagina mostra ancora la versione 1.
      expect(find.textContaining('Piano versione 1'), findsOneWidget);

      await tester.fling(
        find.text('Lunedì (oggi)'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Piano versione 2'), findsOneWidget);
      expect(find.text('Mela'), findsOneWidget);
    });

    testWidgets('se la nuova versione non ha il giorno scelto, si passa a un '
        'giorno che c\'è', (tester) async {
      schermoAlto(tester);
      final finte = DipendenzeFinte(ruolo: Ruolo.paziente);
      await finte.piani.salva('p1', _pianoGiorni([1, 2]));
      await apri(tester, finte);
      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();
      expect(find.text('Martedì'), findsOneWidget);

      // La versione 2 non ha più il martedì.
      await finte.piani.salva('p1', _pianoGiorni([1, 4]));
      await tester.pumpAndSettle();
      expect(find.text('Questo piano non ha giorni.'), findsNothing);
      expect(find.text('Lunedì (oggi)'), findsOneWidget);
      expect(find.text('Gio'), findsOneWidget);
      expect(find.text('Mar'), findsNothing);
    });

    testWidgets('nuovi obiettivi si vedono subito', (tester) async {
      schermoAlto(tester);
      final finte = await dipendenze();
      await apri(tester, finte);
      await finte.obiettivi.imposta(
        'p1',
        kcal: 1800,
        proteineG: 100,
        carboidratiG: 200,
        grassiG: 60,
      );
      await tester.pumpAndSettle();
      expect(find.text('1800'), findsOneWidget);
      expect(find.textContaining('su 1800 di obiettivo'), findsOneWidget);
    });
  });

  group('Accessibilità (RNF_U_3)', () {
    testWidgets('aree di tocco e contrasto', (tester) async {
      schermoAlto(tester);
      final maniglia = tester.ensureSemantics();
      await apri(tester, await dipendenze());
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      maniglia.dispose();
    });

    testWidgets('testo al 200%: nessun overflow, con e senza piano', (
      tester,
    ) async {
      schermoAlto(tester);
      await apri(tester, await dipendenze(), scalaTesto: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('I tuoi obiettivi giornalieri'), findsOneWidget);

      await apri(tester, await dipendenze(conPiano: false), scalaTesto: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('Schermo stretto (RNF_U_3)', () {
    testWidgets('320 dp e testo al 200%: nessun overflow, con e senza piano', (
      tester,
    ) async {
      // 800 / 2,5 = 320 dp di larghezza, come il test degli strumenti del piano.
      tester.view.physicalSize = const Size(800, 4200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await apri(tester, await dipendenze(), scalaTesto: 2);
      expect(tester.takeException(), isNull);
      // Con il testo al 200% il pulsante è sotto il bordo: prima si scorre.
      final alternative = find.widgetWithText(TextButton, 'Alternative (1)');
      await tester.scrollUntilVisible(find.text('Cereali integrali'), 200);
      await tester.ensureVisible(alternative.first);
      await tester.pumpAndSettle();
      await tester.tap(alternative.first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await apri(tester, await dipendenze(conPiano: false), scalaTesto: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('Navigazione (RNF_U_6, NP_1_PAZ)', () {
    testWidgets('dalla barra inferiore si apre la Dieta con il piano', (
      tester,
    ) async {
      schermoAlto(tester);
      final finte = await dipendenze();
      await tester.pumpWidget(CenatoApp(dip: finte.dip));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dieta'));
      await tester.pumpAndSettle();
      // Il piano di prova copre tutta la settimana: qualunque giorno sia oggi
      // c'è la pillola "· oggi".
      expect(find.textContaining('· oggi'), findsOneWidget);
      expect(find.text('I tuoi obiettivi giornalieri'), findsOneWidget);
      expect(find.text('Colazione'), findsOneWidget);
    });
  });

  group('Repository del collegamento: mioPazienteId', () {
    test('collegato → id della riga pazienti; scollegato → null', () async {
      final finte = DipendenzeFinte(ruolo: Ruolo.paziente);
      expect(await finte.collegamento.mioPazienteId(), 'p1');
      finte.auth.scollega();
      expect(await finte.collegamento.mioPazienteId(), isNull);
    });

    test('rete assente → ErroreOperazione', () async {
      final finte = DipendenzeFinte(ruolo: Ruolo.paziente)
        ..collegamento.nonRaggiungibile = true;
      expect(
        finte.collegamento.mioPazienteId(),
        throwsA(isA<ErroreOperazione>()),
      );
    });
  });

  group('Dati di prova della Dieta', () {
    test(
      'piano valido per salva_piano, 7 giorni, obiettivi del mock-up',
      () async {
        expect(problemiDelPiano(DietaFinta.piano()), isEmpty);
        final finte = DipendenzeFinte(ruolo: Ruolo.paziente);
        await DietaFinta.carica(finte);
        final piano = (await finte.piani.corrente('p1'))!;
        expect(piano.giorni.map((g) => g.giornoSettimana), [
          1,
          2,
          3,
          4,
          5,
          6,
          7,
        ]);
        expect((await finte.obiettivi.corrente('p1'))!.kcal, 2000);
      },
    );

    test('senza piano: solo obiettivi', () async {
      final finte = DipendenzeFinte(ruolo: Ruolo.paziente);
      await DietaFinta.carica(finte, conPiano: false);
      expect(await finte.piani.corrente('p1'), isNull);
      expect(await finte.obiettivi.corrente('p1'), isNotNull);
    });
  });
}
