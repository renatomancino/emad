import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/core/tema/tema.dart';
import 'package:cenato/data/supabase/supabase_auth_repository.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/presentation/comuni/controlli.dart';
import 'package:cenato/presentation/comuni/stati_view.dart';

Widget _inApp(Widget figlio) => MaterialApp(
  theme: temaCenato(),
  home: Scaffold(body: figlio),
);

void main() {
  group('Widget comuni', () {
    testWidgets(
      'ErroreView mostra il messaggio e "Riprova" richiama l\'azione',
      (tester) async {
        var tentativi = 0;
        await tester.pumpWidget(
          _inApp(
            ErroreView(messaggio: 'Rete assente', onRiprova: () => tentativi++),
          ),
        );
        expect(find.text('Rete assente'), findsOneWidget);
        await tester.tap(find.text('Riprova'));
        expect(tentativi, 1);
      },
    );

    testWidgets('StatoVuotoView mostra l\'azione solo se c\'è', (tester) async {
      var toccato = false;
      await tester.pumpWidget(
        _inApp(
          StatoVuotoView(
            icona: Icons.groups,
            titolo: 'Nessun paziente',
            messaggio: 'Invita il primo paziente.',
            etichettaAzione: 'Invita',
            onAzione: () => toccato = true,
          ),
        ),
      );
      await tester.tap(find.text('Invita'));
      expect(toccato, isTrue);
    });

    testWidgets('CaricamentoView mostra l\'indicatore', (tester) async {
      await tester.pumpWidget(_inApp(const CaricamentoView()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Caricamento in corso…'), findsOneWidget);
    });

    testWidgets('PulsantePrimario è disattivato mentre è in corso', (
      tester,
    ) async {
      await tester.pumpWidget(
        _inApp(
          PulsantePrimario(etichetta: 'Salva', onPressed: () {}, inCorso: true),
        ),
      );
      final pulsante = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(pulsante.onPressed, isNull);
    });

    testWidgets('i pulsanti rispettano l\'area di tocco minima di 48 dp', (
      tester,
    ) async {
      await tester.pumpWidget(
        _inApp(
          Center(
            child: OutlinedButton(onPressed: () {}, child: const Text('Ok')),
          ),
        ),
      );
      final dimensione = tester.getSize(find.byType(OutlinedButton));
      expect(dimensione.height, greaterThanOrEqualTo(areaToccoMinima));
    });
  });

  group('Profilo e ruolo', () {
    test('Profilo.daRiga legge il ruolo dal database', () {
      final p = Profilo.daRiga({
        'id': 'x',
        'ruolo': 'nutrizionista',
        'nome': 'Giulia',
      });
      expect(p?.ruolo, Ruolo.nutrizionista);
      expect(
        Profilo.daRiga({'id': 'x', 'ruolo': 'admin', 'nome': 'X'}),
        isNull,
      );
    });

    test('gli errori di Supabase Auth hanno un messaggio in italiano', () {
      expect(
        SupabaseAuthRepository.messaggioPer('invalid_credentials', '400'),
        startsWith('Email o password non corretti'),
      );
      expect(
        SupabaseAuthRepository.messaggioPer(
          'over_email_send_rate_limit',
          '429',
        ),
        startsWith('Troppi tentativi'),
      );
      expect(
        SupabaseAuthRepository.messaggioPer(null),
        contains('Connessione'),
      );
    });
  });
}
