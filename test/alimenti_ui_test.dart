import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/core/tema/tema.dart';
import 'package:cenato/data/alimenti_repository.dart';
import 'package:cenato/data/finto/alimenti_cache_in_memoria.dart';
import 'package:cenato/data/finto/dipendenze_finte.dart';
import 'package:cenato/data/finto/fonte_alimenti_online_finta.dart';
import 'package:cenato/domain/modelli/alimento.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/domain/repository/alimenti_repository.dart';
import 'package:cenato/domain/repository/pazienti_repository.dart';
import 'package:cenato/main.dart';
import 'package:cenato/presentation/nutrizionista/alimenti/alimento_personalizzato_page.dart';
import 'package:cenato/presentation/nutrizionista/alimenti/ricerca_alimento.dart';

import 'font_reali.dart';

/// Repository che fallisce le prime [daFallire] ricerche, poi si comporta
/// come quello vero (per provare "Riprova").
class _ConErrori implements AlimentiRepository {
  _ConErrori(this._vero, this.daFallire);

  final AlimentiRepository _vero;
  int daFallire;

  @override
  Future<RisultatoRicerca> cerca(String testo, {bool anchePerOnline = false}) {
    if (daFallire > 0) {
      daFallire--;
      throw const ErroreOperazione('Connessione non riuscita.', codice: 'rete');
    }
    return _vero.cerca(testo, anchePerOnline: anchePerOnline);
  }

  @override
  Future<Alimento> scegli(Alimento a) => _vero.scegli(a);

  @override
  Future<Alimento> creaPersonalizzato({
    required String nome,
    required double kcal100g,
    required double proteine100g,
    required double carboidrati100g,
    required double grassi100g,
    String? marca,
  }) => _vero.creaPersonalizzato(
    nome: nome,
    kcal100g: kcal100g,
    proteine100g: proteine100g,
    carboidrati100g: carboidrati100g,
    grassi100g: grassi100g,
    marca: marca,
  );

  @override
  Future<List<Alimento>> recenti({int limite = 10}) =>
      _vero.recenti(limite: limite);

  @override
  Future<List<Alimento>> preferiti() => _vero.preferiti();

  @override
  Future<void> impostaPreferito(Alimento a, bool p) =>
      _vero.impostaPreferito(a, p);
}

class _Contesto {
  final online = FonteAlimentiOnlineFinta();
  final cache = AlimentiCacheInMemoria();
  late final AlimentiRepositoryImpl repo = AlimentiRepositoryImpl(
    cache: cache,
    online: online,
  );
  final scelti = <Alimento>[];
  final creazioni = <String>[];
  final link = <Uri>[];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await caricaFontReali();
  });

  Future<_Contesto> monta(
    WidgetTester tester, {
    AlimentiRepository Function(_Contesto)? repository,
    double scala = 1,
    Size dimensione = const Size(390, 844),
  }) async {
    tester.view.physicalSize = dimensione * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = scala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = _Contesto();
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCenato(),
        home: Scaffold(
          body: RicercaAlimento(
            repository: repository?.call(c) ?? c.repo,
            onScelto: c.scelti.add,
            onCreaPersonalizzato: (testo) async => c.creazioni.add(testo),
            apriLink: (uri) async => c.link.add(uri),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  /// Scrive nel campo e aspetta il debounce (400 ms) e la risposta.
  Future<void> cerca(WidgetTester tester, String testo) async {
    await tester.enterText(find.byType(TextField), testo);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  group('Ricerca alimenti', () {
    testWidgets('l\'attribuzione ODbL è sempre visibile e apre il link', (
      tester,
    ) async {
      final c = await monta(tester);
      expect(find.text('Dati: Open Food Facts (ODbL)'), findsOneWidget);
      await tester.tap(find.text('Dati: Open Food Facts (ODbL)'));
      await tester.pump();
      expect(c.link.single.host, contains('openfoodfacts.org'));
    });

    testWidgets('cerco "pane": risultati con kcal e macro per 100 g', (
      tester,
    ) async {
      await monta(tester);
      await cerca(tester, 'pane');
      expect(find.text('Pane integrale'), findsOneWidget);
      expect(find.textContaining('247 kcal'), findsOneWidget);
      expect(find.textContaining('P 9 g'), findsWidgets);
      expect(find.textContaining('C 41,2 g'), findsOneWidget);
      expect(find.textContaining('G 3,4 g'), findsOneWidget);
      expect(find.textContaining('per 100 g'), findsWidgets);
    });

    testWidgets('digitando di seguito parte una sola ricerca online', (
      tester,
    ) async {
      final c = await monta(tester);
      for (final t in ['p', 'pa', 'pan', 'pane']) {
        await tester.enterText(find.byType(TextField), t);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(c.online.chiamate, 1);
    });

    testWidgets('alimento con dati incompleti: segnalato, non si sceglie', (
      tester,
    ) async {
      final c = await monta(tester);
      await cerca(tester, 'senza dati');
      expect(find.text('Dati incompleti'), findsOneWidget);
      await tester.tap(find.text('Prodotto senza dati'));
      await tester.pumpAndSettle();
      expect(find.text('Completa a mano'), findsOneWidget);
      expect(c.scelti, isEmpty);
      await tester.tap(find.text('Completa a mano'));
      await tester.pumpAndSettle();
      expect(c.creazioni, ['Prodotto senza dati']);
    });

    testWidgets('scegliere salva in cache e restituisce l\'alimento', (
      tester,
    ) async {
      final c = await monta(tester);
      await cerca(tester, 'pane');
      await tester.tap(find.text('Pane integrale'));
      await tester.pumpAndSettle();
      expect(c.scelti.single.nome, 'Pane integrale');
      expect(c.scelti.single.id, isNotNull);
      expect(c.scelti.single.fonte, FonteAlimento.openFoodFacts);
      expect(
        (await c.cache.cercaPerNome('pane integrale')).single.id,
        c.scelti.single.id,
      );
    });

    testWidgets('a campo vuoto si vedono i recenti', (tester) async {
      await monta(tester);
      await cerca(tester, 'pane');
      await tester.tap(find.text('Pane integrale'));
      await tester.pumpAndSettle();
      await cerca(tester, '');
      expect(find.text('Usati di recente'), findsOneWidget);
      expect(find.text('Pane integrale'), findsOneWidget);
    });

    testWidgets('la stella aggiunge e toglie dai preferiti', (tester) async {
      await monta(tester);
      await cerca(tester, 'pane');
      await tester.tap(find.byTooltip('Aggiungi ai preferiti').first);
      await tester.pumpAndSettle();
      await cerca(tester, '');
      expect(find.text('Preferiti'), findsOneWidget);
      await tester.tap(find.byTooltip('Togli dai preferiti').first);
      await tester.pumpAndSettle();
      expect(find.text('Preferiti'), findsNothing);
    });

    testWidgets('servizio online spento: si dice e si usa la cache', (
      tester,
    ) async {
      final c = await monta(tester);
      await cerca(tester, 'pane');
      await tester.tap(find.text('Pane integrale'));
      await tester.pumpAndSettle();
      c.online.nonDisponibile = true;
      await cerca(tester, 'pan'); // testo diverso: il campo rilancia la ricerca
      expect(
        find.textContaining('Open Food Facts non risponde'),
        findsOneWidget,
      );
      expect(find.text('Pane integrale'), findsOneWidget);
      expect(find.text('Pane bianco'), findsNothing);
    });

    testWidgets('nessun risultato: propone l\'alimento personalizzato', (
      tester,
    ) async {
      final c = await monta(tester);
      await cerca(tester, 'xyzxyz');
      expect(find.text('Crea alimento personalizzato'), findsWidgets);
      await tester.tap(find.text('Crea alimento personalizzato').first);
      await tester.pumpAndSettle();
      expect(c.creazioni, ['xyzxyz']);
    });

    testWidgets('errore: "Riprova" conserva il testo e rifà la ricerca', (
      tester,
    ) async {
      await monta(tester, repository: (c) => _ConErrori(c.repo, 1));
      await cerca(tester, 'pane');
      expect(find.text('Riprova'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'pane',
      );
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(find.text('Pane integrale'), findsOneWidget);
    });

    testWidgets('cache piena: "Cerca anche online" chiama il servizio', (
      tester,
    ) async {
      final c = await monta(tester);
      for (var i = 0; i < 5; i++) {
        await c.repo.creaPersonalizzato(
          nome: 'Pane casalingo $i',
          kcal100g: 250,
          proteine100g: 8,
          carboidrati100g: 49,
          grassi100g: 1.5,
        );
      }
      await cerca(tester, 'pane');
      expect(c.online.chiamate, 0);
      await tester.tap(find.text('Cerca anche online'));
      await tester.pumpAndSettle();
      expect(c.online.chiamate, 1);
    });

    testWidgets('320 dp e testo al 200%: nessun overflow', (tester) async {
      final c = await monta(tester, scala: 2, dimensione: const Size(320, 640));
      await c.repo.creaPersonalizzato(
        nome: 'Pane casalingo con nome decisamente molto lungo ' * 2,
        kcal100g: 250,
        proteine100g: 8,
        carboidrati100g: 49,
        grassi100g: 1.5,
        marca: 'Marca con un nome altrettanto lungo',
      );
      await cerca(tester, 'pane');
      expect(tester.takeException(), isNull);
      await cerca(tester, 'xyzxyz');
      expect(tester.takeException(), isNull);
      expect(find.text('Dati: Open Food Facts (ODbL)'), findsOneWidget);
    });
  });

  group('Alimento personalizzato', () {
    Future<_Contesto> apriForm(
      WidgetTester tester, {
      String nome = '',
      double scala = 1,
      Size dimensione = const Size(390, 844),
    }) async {
      tester.view.physicalSize = dimensione * 2;
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = scala;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final c = _Contesto();
      await tester.pumpWidget(
        MaterialApp(
          theme: temaCenato(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final creato = await Navigator.of(context).push<Alimento>(
                    MaterialPageRoute(
                      builder: (_) => AlimentoPersonalizzatoPage(
                        repository: c.repo,
                        nomeIniziale: nome,
                      ),
                    ),
                  );
                  if (creato != null) c.scelti.add(creato);
                },
                child: const Text('Apri'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();
      return c;
    }

    Future<void> scrivi(WidgetTester tester, String etichetta, String testo) =>
        tester.enterText(find.widgetWithText(TextField, etichetta), testo);

    testWidgets('campi vuoti: messaggi chiari e nulla viene salvato', (
      tester,
    ) async {
      final c = await apriForm(tester);
      await tester.ensureVisible(find.text('Salva alimento'));
      await tester.tap(find.text('Salva alimento'));
      await tester.pumpAndSettle();
      expect(find.text('Inserisci il nome dell\'alimento.'), findsOneWidget);
      expect(find.textContaining('Inserisci le kcal'), findsOneWidget);
      expect(await c.repo.recenti(), isEmpty);
    });

    testWidgets('accetta la virgola, salva, restituisce e si ritrova', (
      tester,
    ) async {
      final c = await apriForm(tester, nome: 'Torta della nonna');
      expect(find.text('Torta della nonna'), findsOneWidget);
      await scrivi(tester, 'Calorie (kcal) per 100 g', '380');
      await scrivi(tester, 'Proteine (g) per 100 g', '6,5');
      await scrivi(tester, 'Carboidrati (g) per 100 g', '52');
      await scrivi(tester, 'Grassi (g) per 100 g', '16,2');
      await tester.ensureVisible(find.text('Salva alimento'));
      await tester.tap(find.text('Salva alimento'));
      await tester.pumpAndSettle();

      final creato = c.scelti.single;
      expect(creato.nome, 'Torta della nonna');
      expect(creato.proteine100g, 6.5);
      expect(creato.grassi100g, 16.2);
      expect(creato.fonte, FonteAlimento.personalizzato);
      expect((await c.repo.cerca('torta')).alimenti.single.id, creato.id);
    });

    testWidgets('valori fuori limite: errore sul campo', (tester) async {
      await apriForm(tester, nome: 'Prova');
      await scrivi(tester, 'Calorie (kcal) per 100 g', '1200');
      await scrivi(tester, 'Proteine (g) per 100 g', '5');
      await scrivi(tester, 'Carboidrati (g) per 100 g', '5');
      await scrivi(tester, 'Grassi (g) per 100 g', '5');
      await tester.ensureVisible(find.text('Salva alimento'));
      await tester.tap(find.text('Salva alimento'));
      await tester.pumpAndSettle();
      expect(find.textContaining('tra 0 e 900'), findsOneWidget);
    });

    testWidgets('320 dp e testo al 200%: nessun overflow', (tester) async {
      await apriForm(
        tester,
        nome: 'Nome molto lungo ' * 5,
        scala: 2,
        dimensione: const Size(320, 640),
      );
      expect(tester.takeException(), isNull);
      // A testo grande il pulsante sta in fondo: si scorre fin lì.
      await tester.scrollUntilVisible(
        find.text('Salva alimento'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Salva alimento'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Percorso nell\'app del nutrizionista', () {
    testWidgets('Profilo → Alimenti → ricerca → alimento personalizzato', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final finte = DipendenzeFinte(ruolo: Ruolo.nutrizionista);
      await tester.pumpWidget(CenatoApp(dip: finte.dip));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profilo'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('apri-alimenti')));
      await tester.tap(find.byKey(const Key('apri-alimenti')));
      await tester.pumpAndSettle();
      expect(find.text('Dati: Open Food Facts (ODbL)'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'pane');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('Pane integrale'), findsOneWidget);
      expect(finte.alimentiOnline.chiamate, 1);

      await tester.enterText(find.byType(TextField), 'xyzxyz');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crea alimento personalizzato').first);
      await tester.pumpAndSettle();
      expect(find.text('Salva alimento'), findsOneWidget);
      expect(find.text('xyzxyz'), findsOneWidget);
    });
  });
}
