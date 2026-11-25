import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/core/tema/tema.dart';

/// Rapporto di contrasto WCAG tra due colori.
double _contrasto(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final chiaro = la > lb ? la : lb;
  final scuro = la > lb ? lb : la;
  return (chiaro + 0.05) / (scuro + 0.05);
}

void main() {
  group('Tema Cenato', () {
    test('i titoli usano Plus Jakarta Sans e il testo Inter', () {
      final testo = temaCenato().textTheme;
      expect(testo.titleLarge!.fontFamily, fontTitoli);
      expect(testo.headlineSmall!.fontFamily, fontTitoli);
      expect(testo.bodyMedium!.fontFamily, fontTesto);
      expect(testo.labelLarge!.fontFamily, fontTesto);
      expect(fontTitoli, 'PlusJakartaSans');
      expect(fontTesto, 'Inter');
    });

    test('CenatoColori è registrato nel tema', () {
      expect(temaCenato().extension<CenatoColori>(), isNotNull);
    });

    test('palette: contrasto AA per il testo (almeno 4,5:1)', () {
      const c = CenatoColori.chiaro;
      final coppie = <String, double>{
        'testo/superficie': _contrasto(c.testo, c.superficie),
        'testo/sfondo': _contrasto(c.testo, c.sfondo),
        'testoSecondario/superficie': _contrasto(
          c.testoSecondario,
          c.superficie,
        ),
        'testoSecondario/sfondo': _contrasto(c.testoSecondario, c.sfondo),
        'sulPrimario/primario': _contrasto(c.sulPrimario, c.primario),
        'primario/primarioTonale': _contrasto(c.primario, c.primarioTonale),
        'primario/superficie': _contrasto(c.primario, c.superficie),
        'errore/superficie': _contrasto(c.errore, c.superficie),
        'avviso/avvisoTonale': _contrasto(c.avviso, c.avvisoTonale),
      };
      coppie.forEach((nome, rapporto) {
        expect(rapporto, greaterThanOrEqualTo(4.5), reason: nome);
      });
    });

    test('semaforo: colori del RAD invariati e visibili (almeno 3:1)', () {
      const c = CenatoColori.chiaro;
      expect(c.semaforoVerde, const Color(0xFF2E7D4F));
      expect(c.semaforoGiallo, const Color(0xFFB7791F));
      expect(c.semaforoRosso, const Color(0xFFC0392B));
      for (final colore in [
        c.semaforoVerde,
        c.semaforoGiallo,
        c.semaforoRosso,
      ]) {
        expect(_contrasto(colore, c.superficie), greaterThanOrEqualTo(3));
      }
    });

    test(
      'il bordo dei campi ha almeno 3:1 sulla superficie e sullo sfondo',
      () {
        const c = CenatoColori.chiaro;
        expect(_contrasto(c.bordoCampo, c.superficie), greaterThanOrEqualTo(3));
        // I campi di ricerca stanno direttamente sullo sfondo della pagina.
        expect(_contrasto(c.bordoCampo, c.sfondo), greaterThanOrEqualTo(3));
      },
    );

    test('le card non hanno bordo e hanno raggio 20', () {
      final forma = temaCenato().cardTheme.shape! as RoundedRectangleBorder;
      expect(forma.borderRadius, BorderRadius.circular(20));
      expect(forma.side, BorderSide.none);
    });

    testWidgets('context.colori legge la palette dal tema attivo', (
      tester,
    ) async {
      const personalizzato = Color(0xFF123456);
      late CenatoColori letti;
      await tester.pumpWidget(
        MaterialApp(
          theme: temaCenato().copyWith(
            extensions: [
              CenatoColori.chiaro.copyWith(primario: personalizzato),
            ],
          ),
          home: Builder(
            builder: (context) {
              letti = context.colori;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(letti.primario, personalizzato);
    });

    testWidgets('context.colori senza estensione usa la palette chiara', (
      tester,
    ) async {
      late CenatoColori letti;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              letti = context.colori;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(letti.primario, CenatoColori.chiaro.primario);
    });
  });
}
