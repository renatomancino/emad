import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/core/dipendenze.dart';
import 'package:cenato/core/tema/tema.dart';
import 'package:cenato/data/finto/dipendenze_finte.dart';
import 'package:cenato/domain/modelli/piano_alimentare.dart';
import 'package:cenato/domain/modelli/alimento.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/domain/repository/alimenti_repository.dart';
import 'package:cenato/domain/repository/file_csv.dart';
import 'package:cenato/presentation/nutrizionista/piano/importa_piano_page.dart';
import 'package:cenato/presentation/nutrizionista/piano/piano_editor_page.dart';

/// Scheda "[MC] Importazione del piano da file CSV": RF_GP_10, RF_GP_11,
/// UC_GP_5, SC_GP_3. File finti, repository in memoria.

/// File finto: restituisce [prossimo] a ogni scelta e conta i salvataggi.
class _FileFinto implements FileCsv {
  _FileFinto([String? contenuto]) {
    if (contenuto != null) usa(contenuto);
  }

  FileScelto? prossimo;
  int modelliSalvati = 0;

  void usa(String contenuto) => prossimo = FileScelto(
    nome: 'piano.csv',
    bytes: Uint8List.fromList(utf8.encode(contenuto)),
  );

  @override
  Future<FileScelto?> scegli() async => prossimo;

  @override
  Future<bool> salvaModello() async {
    modelliSalvati++;
    return true;
  }
}

/// Repository che risponde dalla cache dopo un secondo, come una rete lenta.
class _CacheLenta implements AlimentiRepository {
  _CacheLenta(this._vero);

  final AlimentiRepository _vero;

  @override
  Future<List<Alimento>> cercaInCache(String testo) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return _vero.cercaInCache(testo);
  }

  @override
  Future<RisultatoRicerca> cerca(
    String testo, {
    bool anchePerOnline = false,
    void Function(RisultatoRicerca)? alRisultatoDallaCache,
  }) => _vero.cerca(testo, anchePerOnline: anchePerOnline);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _h = 'giorno;pasto;alimento;quantita_g;note\n';

/// Tutti gli alimenti sono nel catalogo finto: si abbinano da soli.
const _valido =
    '${_h}Lun;Colazione;Latte parzialmente scremato;200;\n'
    'Lun;Pranzo;Riso bianco;80;a crudo\n'
    'Mar;Cena;Mela;150;\n';

/// Tre righe errate (3, 5, 6) e due buone.
const _conErrori =
    '${_h}Lun;Colazione;Latte parzialmente scremato;200;\n'
    'Lun;Colazione;Mela;tre;\n'
    'Lun;Pranzo;Riso bianco;80;\n'
    'Lundì;Pranzo;Mela;100;\n'
    'Lun;Cena;;150;\n';

void main() {
  void schermoAlto(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
  }

  DipendenzeFinte dipendenze(_FileFinto file) =>
      DipendenzeFinte(ruolo: Ruolo.nutrizionista, fileCsv: file);

  /// Apre la schermata di importazione da una pagina di prova e raccoglie il
  /// risultato con cui si chiude.
  Future<List<RisultatoImportazione?>> apri(
    WidgetTester tester,
    Dipendenze dip,
  ) async {
    final risultati = <RisultatoImportazione?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCenato(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => risultati.add(
              await Navigator.of(context).push<RisultatoImportazione>(
                MaterialPageRoute(builder: (_) => ImportaPianoPage(dip: dip)),
              ),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    return risultati;
  }

  Future<void> scegliFile(WidgetTester tester) async {
    await tester.tap(find.text('Scegli file CSV'));
    await tester.pumpAndSettle();
  }

  /// Il pulsante di conferma è attivo?
  bool puoConfermare(WidgetTester tester) =>
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const Key('crea-bozza')),
              matching: find.byType(FilledButton),
              matchRoot: true,
            ),
          )
          .onPressed !=
      null;

  testWidgets('si può scaricare il modello (RF_GP_10)', (tester) async {
    schermoAlto(tester);
    final file = _FileFinto();
    await apri(tester, dipendenze(file).dip);

    await tester.tap(find.text('Scarica modello CSV'));
    await tester.pumpAndSettle();

    expect(file.modelliSalvati, 1);
    expect(find.textContaining('Modello salvato'), findsOneWidget);
  });

  test('il modello è tra le risorse dell\'app', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dati = await rootBundle.load('assets/modello_piano.csv');
    expect(dati.lengthInBytes, greaterThan(0));
  });

  testWidgets('annullare la scelta del file non cambia nulla', (tester) async {
    schermoAlto(tester);
    await apri(tester, dipendenze(_FileFinto()).dip);
    await scegliFile(tester);

    expect(find.text('Scegli file CSV'), findsOneWidget);
    expect(find.byKey(const Key('crea-bozza')), findsNothing);
  });

  testWidgets('file non valido: spiega e rimanda al modello (flusso 4.2)', (
    tester,
  ) async {
    schermoAlto(tester);
    await apri(tester, dipendenze(_FileFinto('giorno;alimento\nLun;Riso')).dip);
    await scegliFile(tester);

    expect(find.textContaining('Mancano le colonne'), findsOneWidget);
    expect(find.text('Scarica modello CSV'), findsOneWidget);
    expect(find.byKey(const Key('crea-bozza')), findsNothing);
  });

  testWidgets('file valido: anteprima, abbinamento e bozza', (tester) async {
    schermoAlto(tester);
    final finte = dipendenze(_FileFinto(_valido));
    final risultati = await apri(tester, finte.dip);
    await scegliFile(tester);

    expect(find.text('3 righe riconosciute'), findsOneWidget);
    expect(find.text('0 righe con errori'), findsOneWidget);
    expect(find.text('0 alimenti da abbinare'), findsOneWidget);
    // Le note si vedono in anteprima.
    expect(find.textContaining('a crudo'), findsOneWidget);
    // Prima della conferma non si scrive nulla.
    expect(await finte.dip.alimenti.recenti(), isEmpty);

    await tester.tap(find.byKey(const Key('crea-bozza')));
    await tester.pumpAndSettle();

    final esito = risultati.single!;
    expect((esito.righeImportate, esito.righeIgnorate), (3, 0));
    expect(esito.piano.stato, StatoPiano.bozza);
    expect(esito.piano.giorni.map((g) => g.giornoSettimana), [1, 2]);
    // Gli alimenti della bozza hanno l'id della cache: salva_piano lo chiede.
    for (final g in esito.piano.giorni) {
      for (final p in g.pasti) {
        for (final v in p.voci) {
          expect(v.alimento.id, isNotNull, reason: v.alimento.nome);
        }
      }
    }
    // Il piano del paziente non è stato toccato.
    expect(await finte.dip.piani.corrente('p1'), isNull);
  });

  testWidgets('con 3 righe errate non importa finché non si ignorano', (
    tester,
  ) async {
    schermoAlto(tester);
    final risultati = await apri(
      tester,
      dipendenze(_FileFinto(_conErrori)).dip,
    );
    await scegliFile(tester);

    expect(find.text('3 righe con errori'), findsOneWidget);
    for (final n in [3, 5, 6]) {
      expect(find.textContaining('Riga $n'), findsWidgets, reason: 'riga $n');
    }
    expect(puoConfermare(tester), isFalse);

    for (final n in [3, 5, 6]) {
      await tester.tap(find.byKey(Key('ignora-riga-$n')));
      await tester.pumpAndSettle();
    }
    expect(puoConfermare(tester), isTrue);

    await tester.tap(find.byKey(const Key('crea-bozza')));
    await tester.pumpAndSettle();
    final esito = risultati.single!;
    expect((esito.righeImportate, esito.righeIgnorate), (2, 3));
  });

  testWidgets('alimento non trovato: si ignora e la riga resta fuori', (
    tester,
  ) async {
    schermoAlto(tester);
    final risultati = await apri(
      tester,
      dipendenze(
        _FileFinto('${_h}Lun;Cena;Mela;100;\nLun;Cena;Zzqx introvabile;50;\n'),
      ).dip,
    );
    await scegliFile(tester);

    expect(find.text('1 alimento da abbinare'), findsOneWidget);
    expect(find.text('Scegli'), findsOneWidget);
    expect(find.text('Crea'), findsOneWidget);
    expect(puoConfermare(tester), isFalse);

    await tester.tap(find.byKey(const Key('ignora-alimento-zzqx introvabile')));
    await tester.pumpAndSettle();
    expect(puoConfermare(tester), isTrue);
    await tester.tap(find.byKey(const Key('crea-bozza')));
    await tester.pumpAndSettle();
    expect(
      (risultati.single!.righeImportate, risultati.single!.righeIgnorate),
      (1, 1),
    );
  });

  testWidgets('abbinamento a mano con il nome già nella ricerca', (
    tester,
  ) async {
    schermoAlto(tester);
    await apri(tester, dipendenze(_FileFinto('${_h}Lun;Cena;Riso;80;\n')).dip);
    await scegliFile(tester);
    // "Riso" non è identico a "Riso bianco": lo sceglie il nutrizionista.
    expect(find.text('1 alimento da abbinare'), findsOneWidget);

    await tester.tap(find.text('Scegli'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riso bianco').first);
    await tester.pumpAndSettle();

    expect(find.text('0 alimenti da abbinare'), findsOneWidget);
    expect(find.textContaining('Riso bianco'), findsOneWidget);
    expect(puoConfermare(tester), isTrue);
  });

  testWidgets('le ricerche in cache partono insieme (RNF_P_4)', (tester) async {
    schermoAlto(tester);
    final finte = dipendenze(_FileFinto(_valido));
    // Gli alimenti del file sono già in cache, come i dati di prova veri.
    for (final nome in ['Latte parzialmente scremato', 'Riso bianco', 'Mela']) {
      await finte.dip.alimenti.scegli(
        (await finte.dip.alimenti.cerca(nome)).alimenti.first,
      );
    }
    final d = finte.dip;
    await apri(
      tester,
      Dipendenze(
        auth: d.auth,
        pazienti: d.pazienti,
        abbonamento: d.abbonamento,
        collegamento: d.collegamento,
        profilo: d.profilo,
        alimenti: _CacheLenta(d.alimenti),
        obiettivi: d.obiettivi,
        piani: d.piani,
        modelli: d.modelli,
        fileCsv: d.fileCsv,
      ),
    );
    await tester.tap(find.text('Scegli file CSV'));
    await tester.pump();
    // Tre nomi, un secondo a ricerca: in parallelo basta poco più di un
    // secondo, uno alla volta ne servirebbero tre.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();

    expect(find.textContaining('Cerco gli alimenti'), findsNothing);
    expect(find.textContaining('Abbinato a'), findsNWidgets(3));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });

  testWidgets('con un altro file la pagina torna in cima', (tester) async {
    tester.view.physicalSize = const Size(1080, 1600);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final file = _FileFinto(_conErrori);
    await apri(tester, dipendenze(file).dip);
    await scegliFile(tester);

    await tester.scrollUntilVisible(
      find.text('Scegli un altro file'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    ScrollPosition posizione() =>
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(posizione().pixels, greaterThan(0));

    file.usa(_valido);
    await tester.tap(find.text('Scegli un altro file'));
    await tester.pumpAndSettle();

    expect(posizione().pixels, 0);
    expect(find.text('3 righe riconosciute'), findsOneWidget);
  });

  testWidgets('dall\'editor: la bozza si apre e non è ancora assegnata', (
    tester,
  ) async {
    schermoAlto(tester);
    final finte = dipendenze(_FileFinto(_valido));
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCenato(),
        home: PianoEditorPage(
          dip: finte.dip,
          pazienteId: 'p1',
          nomePaziente: 'Marco',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importa da file'));
    await tester.pumpAndSettle();
    await scegliFile(tester);
    await tester.tap(find.byKey(const Key('crea-bozza')));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 righe importate'), findsOneWidget);
    expect(find.text('Latte parzialmente scremato'), findsOneWidget);
    expect(find.byTooltip('Salva e assegna'), findsOneWidget);
    expect(await finte.dip.piani.corrente('p1'), isNull);
  });
}
