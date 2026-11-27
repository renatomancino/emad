import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/core/tema/tema.dart';
import 'package:cenato/data/alimenti_repository.dart';
import 'package:cenato/data/dispositivo/permesso_fotocamera.dart';
import 'package:cenato/data/finto/alimenti_cache_in_memoria.dart';
import 'package:cenato/data/finto/fonte_alimenti_online_finta.dart';
import 'package:cenato/domain/modelli/alimento.dart';
import 'package:cenato/presentation/nutrizionista/alimenti/alimento_personalizzato_page.dart';
import 'package:cenato/presentation/nutrizionista/alimenti/scansione_codice_page.dart';
import 'package:cenato/presentation/nutrizionista/piano/aggiungi_alimento_page.dart';

import 'font_reali.dart';

class _Permesso implements PermessoFotocamera {
  _Permesso(this.valore);

  bool valore;
  int impostazioniAperte = 0;

  @override
  Future<bool> concesso() async => valore;

  @override
  Future<void> apriImpostazioni() async => impostazioniAperte++;
}

/// Fotocamera finta: i test "leggono" un codice o negano il permesso.
class _Fotocamera {
  void Function(String grezzo, bool upcE)? _onLetto;
  void Function(ErroreFotocamera errore)? _onErrore;

  /// Quante volte l'anteprima è stata costruita (= fotocamera aperta).
  int aperture = 0;

  Widget costruisci(
    BuildContext context, {
    required void Function(String grezzo, bool upcE) onLetto,
    required void Function(ErroreFotocamera errore) onErrore,
  }) {
    _onLetto = onLetto;
    _onErrore = onErrore;
    aperture++;
    return const ColoredBox(
      key: ValueKey('anteprima'),
      color: Color(0xFF000000),
    );
  }

  void leggi(String codice, {bool upcE = false}) => _onLetto!(codice, upcE);
  void nega() => _onErrore!(ErroreFotocamera.permessoNegato);
}

class _Contesto {
  final online = FonteAlimentiOnlineFinta();
  final cache = AlimentiCacheInMemoria();
  late final repo = AlimentiRepositoryImpl(cache: cache, online: online);
  final fotocamera = _Fotocamera();
  late final permesso = _Permesso(true);
  final risultati = <RisultatoScansione?>[];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await caricaFontReali();
  });

  final anteprima = find.byKey(const ValueKey('anteprima'));

  Future<_Contesto> monta(
    WidgetTester tester, {
    bool permesso = true,
    double scala = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = scala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = _Contesto()..permesso.valore = permesso;
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCenato(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final r = await Navigator.of(context)
                      .push<RisultatoScansione>(
                        MaterialPageRoute(
                          builder: (_) => ScansioneCodicePage(
                            repository: c.repo,
                            permesso: c.permesso,
                            anteprima: c.fotocamera.costruisci,
                            apriLink: (_) async {},
                          ),
                        ),
                      );
                  c.risultati.add(r);
                },
                child: const Text('Apri'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
    return c;
  }

  group('Permesso della fotocamera (RNF_IN_3, UC_GP_3 flusso 1.1)', () {
    testWidgets('senza permesso si spiega a cosa serve prima di chiederlo', (
      tester,
    ) async {
      final c = await monta(tester, permesso: false);
      expect(find.text('Serve la fotocamera'), findsOneWidget);
      expect(anteprima, findsNothing, reason: 'fotocamera non ancora aperta');
      await tester.tap(find.text('Consenti fotocamera'));
      await tester.pumpAndSettle();
      expect(anteprima, findsOneWidget);
      expect(c.fotocamera.aperture, 1);
    });

    testWidgets('con il permesso già dato si apre subito la fotocamera', (
      tester,
    ) async {
      await monta(tester);
      expect(find.text('Serve la fotocamera'), findsNothing);
      expect(anteprima, findsOneWidget);
      expect(find.text('Cerca per nome'), findsOneWidget);
    });

    testWidgets('permesso negato: ricerca per nome e impostazioni', (
      tester,
    ) async {
      final c = await monta(tester, permesso: false);
      await tester.tap(find.text('Consenti fotocamera'));
      await tester.pumpAndSettle();
      c.fotocamera.nega();
      await tester.pumpAndSettle();
      expect(find.text('Fotocamera non consentita'), findsOneWidget);
      expect(anteprima, findsNothing);
      await tester.tap(find.text('Apri impostazioni'));
      expect(c.permesso.impostazioniAperte, 1);
      await tester.tap(find.text('Cerca per nome'));
      await tester.pumpAndSettle();
      expect(c.risultati.single!.cercaPerNome, isTrue);
    });

    testWidgets('tornando dalle impostazioni con il permesso, si riparte', (
      tester,
    ) async {
      final c = await monta(tester);
      c.fotocamera.nega();
      await tester.pumpAndSettle();
      c.permesso.valore = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(anteprima, findsOneWidget);
    });
  });

  group('Lettura del codice (RF_GP_4, SC_GP_2, SD_2)', () {
    testWidgets('prodotto noto: nome e valori per 100 g, poi "Aggiungi al '
        'pasto" lo salva in cache con il codice', (tester) async {
      final c = await monta(tester);
      c.fotocamera.leggi('8000000000095');
      await tester.pumpAndSettle();
      expect(
        anteprima,
        findsNothing,
        reason: 'fotocamera chiusa dopo la lettura',
      );
      expect(find.text('Yogurt greco'), findsOneWidget);
      expect(find.text('97 kcal'), findsOneWidget);
      expect(find.text('9 g'), findsOneWidget);
      expect(find.text('3,9 g'), findsOneWidget);
      expect(find.text('5 g'), findsOneWidget);
      expect(find.text('Dati: Open Food Facts (ODbL)'), findsOneWidget);

      await tester.tap(find.text('Aggiungi al pasto'));
      await tester.pumpAndSettle();
      final scelto = c.risultati.single!.alimento!;
      expect(scelto.id, isNotNull);
      expect(scelto.codiceBarre, '8000000000095');
      expect(scelto.fonte, FonteAlimento.openFoodFacts);
      expect((await c.cache.perCodiceBarre('8000000000095'))!.id, scelto.id);
    });

    testWidgets('letture ripetute dello stesso codice: una sola ricerca', (
      tester,
    ) async {
      final c = await monta(tester);
      c.online.ritardo = const Duration(milliseconds: 200);
      c.fotocamera
        ..leggi('8000000000095')
        ..leggi('8000000000095')
        ..leggi('8000000000095');
      await tester.pumpAndSettle();
      expect(c.online.chiamateCodice, 1);
      // "Scansiona un altro" riapre la fotocamera; lo stesso codice subito
      // dopo si ignora ancora.
      await tester.tap(find.text('Scansiona un altro prodotto'));
      await tester.pumpAndSettle();
      expect(c.fotocamera.aperture, 2);
      c.fotocamera.leggi('8000000000095');
      await tester.pumpAndSettle();
      expect(c.online.chiamateCodice, 1);
      expect(anteprima, findsOneWidget);
    });

    testWidgets('lettura sporca (cifra di controllo errata): si continua a '
        'inquadrare', (tester) async {
      final c = await monta(tester);
      c.fotocamera.leggi('8000000000096');
      await tester.pumpAndSettle();
      expect(anteprima, findsOneWidget);
      expect(c.online.chiamateCodice, 0);
    });

    testWidgets('codice già in cache: non si chiama Open Food Facts', (
      tester,
    ) async {
      final c = await monta(tester);
      final trovato = await c.online.perCodiceBarre('8000000000095');
      await c.repo.scegli(trovato!);
      c.online.chiamateCodice = 0;
      c.fotocamera.leggi('8000000000095');
      await tester.pumpAndSettle();
      expect(find.text('Yogurt greco'), findsOneWidget);
      expect(c.online.chiamateCodice, 0);
    });

    testWidgets('prodotto sconosciuto: messaggio e "Inserisci a mano" con il '
        'codice già scritto', (tester) async {
      final c = await monta(tester);
      c.fotocamera.leggi('8000000000132');
      await tester.pumpAndSettle();
      expect(find.text('Prodotto non trovato'), findsOneWidget);
      expect(find.textContaining('8000000000132'), findsOneWidget);
      await tester.tap(find.text('Inserisci a mano'));
      await tester.pumpAndSettle();
      expect(find.byType(AlimentoPersonalizzatoPage), findsOneWidget);
      expect(find.text('Codice a barre: 8000000000132'), findsOneWidget);

      final campi = find.byType(TextField);
      await tester.enterText(campi.at(0), 'Yogurt della latteria');
      await tester.enterText(campi.at(2), '80');
      await tester.enterText(campi.at(3), '4');
      await tester.enterText(campi.at(4), '6');
      await tester.enterText(campi.at(5), '3,5');
      await tester.ensureVisible(find.text('Salva alimento'));
      await tester.tap(find.text('Salva alimento'));
      await tester.pumpAndSettle();

      final creato = c.risultati.single!.alimento!;
      expect(creato.fonte, FonteAlimento.personalizzato);
      expect(creato.codiceBarre, '8000000000132');
      // La prossima scansione lo trova tra i propri.
      expect((await c.repo.perCodiceBarre('8000000000132')), isA<Object>());
      expect((await c.cache.perCodiceBarre('8000000000132'))!.id, creato.id);
    });

    testWidgets('dati incompleti: "Inserisci a mano" precompila nome e valori '
        'noti', (tester) async {
      final c = await monta(tester);
      c.fotocamera.leggi('8000000000125');
      await tester.pumpAndSettle();
      expect(find.text('Dati nutrizionali incompleti'), findsOneWidget);
      await tester.tap(find.text('Inserisci a mano'));
      await tester.pumpAndSettle();
      final campi = find.byType(TextField);
      String valore(int i) =>
          tester.widget<TextField>(campi.at(i)).controller!.text;
      expect(valore(0), 'Prodotto senza dati');
      expect(valore(2), '', reason: 'le kcal mancano');
      expect(valore(3), '5');
      expect(valore(4), '10');
      expect(valore(5), '2');
      expect(find.text('Codice a barre: 8000000000125'), findsOneWidget);
    });

    testWidgets('Open Food Facts non risponde: "Riprova" senza riscansionare', (
      tester,
    ) async {
      final c = await monta(tester);
      c.online.nonDisponibile = true;
      c.fotocamera.leggi('8000000000095');
      await tester.pumpAndSettle();
      expect(find.text('Open Food Facts non risponde'), findsOneWidget);
      expect(find.text('Inserisci a mano'), findsOneWidget);
      c.online.nonDisponibile = false;
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(find.text('Yogurt greco'), findsOneWidget);
      expect(c.fotocamera.aperture, 1);
    });

    testWidgets('con il testo ingrandito niente esce dallo schermo', (
      tester,
    ) async {
      final c = await monta(tester, scala: 1.6);
      c.fotocamera.leggi('8000000000095');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Aggiungi al pasto'));
      expect(find.text('Aggiungi al pasto'), findsOneWidget);
    });
  });

  group('Ingresso dalla ricerca dell\'editor', () {
    testWidgets('icona nel campo di ricerca; "Cerca per nome" torna al campo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final c = _Contesto();
      final chiamate = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('it.unisa.cenato/fotocamera'),
        (call) async {
          chiamate.add(call.method);
          return call.method == 'permessoConcesso' ? false : null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('it.unisa.cenato/fotocamera'),
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: temaCenato(),
          home: AggiungiAlimentoPage(alimenti: c.repo),
        ),
      );
      await tester.pumpAndSettle();
      final icona = find.byTooltip('Scansiona il codice a barre');
      expect(icona, findsOneWidget);
      await tester.tap(icona);
      await tester.pumpAndSettle();
      // Il canale nativo dice che il permesso non c'è ancora.
      expect(find.byType(ScansioneCodicePage), findsOneWidget);
      expect(find.text('Serve la fotocamera'), findsOneWidget);
      expect(chiamate, ['permessoConcesso']);
      await tester.tap(find.text('Cerca per nome'));
      await tester.pumpAndSettle();
      expect(find.byType(ScansioneCodicePage), findsNothing);
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.focusNode!.hasFocus, isTrue);
    });
  });
}
