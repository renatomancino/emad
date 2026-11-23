import 'package:flutter_test/flutter_test.dart';

import 'package:cenato/domain/modelli/piano.dart';
import 'package:cenato/domain/regole/limiti_piano.dart';

/// RNF_S_3: test sulla regola dei limiti dei piani (RF_GAD_4, RF_GAD_7).
/// Stessi casi di supabase/tests/abbonamento.sql, che prova la regola nel DB.
void main() {
  EsitoLimite invita(
    PianoAbbonamento piano, {
    int attivi = 0,
    int totali = 0,
    int inviti = 0,
  }) => puoInvitare(
    piano: piano,
    pazientiAttivi: attivi,
    pazientiCollegatiTotali: totali,
    invitiInAttesa: inviti,
  );

  group('puoInvitare', () {
    test('Free con 0 pazienti: consentito', () {
      expect(invita(PianoAbbonamento.free), isA<Consentito>());
    });

    test('Free con 1 paziente: bloccato, opzione solo "cambia piano"', () {
      final esito = invita(PianoAbbonamento.free, attivi: 1, totali: 1);
      expect(esito, isA<LimiteRaggiunto>());
      final l = esito as LimiteRaggiunto;
      expect(l.motivo, 'Hai raggiunto il limite del piano Free (1 paziente).');
      expect(l.opzioni, [OpzioneLimite.cambiaPiano]);
    });

    test('Free con 1 paziente archiviato: bloccato (conta a vita)', () {
      expect(
        invita(PianoAbbonamento.free, attivi: 0, totali: 1),
        isA<LimiteRaggiunto>(),
      );
    });

    test('Free con un invito in attesa: bloccato', () {
      expect(invita(PianoAbbonamento.free, inviti: 1), isA<LimiteRaggiunto>());
    });

    test('Start con 4 attivi: consentito', () {
      expect(
        invita(PianoAbbonamento.start, attivi: 4, totali: 4),
        isA<Consentito>(),
      );
    });

    test('Start con 5 attivi: bloccato, propone anche l\'archiviazione', () {
      final esito = invita(PianoAbbonamento.start, attivi: 5, totali: 5);
      expect(esito, isA<LimiteRaggiunto>());
      expect((esito as LimiteRaggiunto).opzioni, [
        OpzioneLimite.cambiaPiano,
        OpzioneLimite.archiviaPaziente,
      ]);
    });

    test('Start: gli archiviati non contano', () {
      expect(
        invita(PianoAbbonamento.start, attivi: 3, totali: 9),
        isA<Consentito>(),
      );
    });

    test('Start: 4 attivi + 1 invito in attesa = pieno', () {
      expect(
        invita(PianoAbbonamento.start, attivi: 4, totali: 4, inviti: 1),
        isA<LimiteRaggiunto>(),
      );
    });

    test('Pro: sempre consentito', () {
      expect(
        invita(PianoAbbonamento.pro, attivi: 500, totali: 800, inviti: 20),
        isA<Consentito>(),
      );
    });
  });

  group('puoRiattivare', () {
    test('Free: riattiva l\'unico paziente archiviato', () {
      expect(
        puoRiattivare(
          piano: PianoAbbonamento.free,
          pazientiAttivi: 0,
          pazientiCollegatiTotali: 1,
        ),
        isA<Consentito>(),
      );
    });

    test('Start al limite: bloccato', () {
      expect(
        puoRiattivare(
          piano: PianoAbbonamento.start,
          pazientiAttivi: 5,
          pazientiCollegatiTotali: 6,
        ),
        isA<LimiteRaggiunto>(),
      );
    });

    test('Start con un posto libero: consentito', () {
      expect(
        puoRiattivare(
          piano: PianoAbbonamento.start,
          pazientiAttivi: 4,
          pazientiCollegatiTotali: 6,
        ),
        isA<Consentito>(),
      );
    });
  });

  group('puoCambiarePiano', () {
    test('da Pro a Start con 6 attivi: bloccato', () {
      expect(
        puoCambiarePiano(
          nuovo: PianoAbbonamento.start,
          pazientiAttivi: 6,
          pazientiCollegatiTotali: 6,
          invitiInAttesa: 0,
        ),
        isA<LimiteRaggiunto>(),
      );
    });

    test('verso Free con 2 pazienti mai collegati: bloccato', () {
      expect(
        puoCambiarePiano(
          nuovo: PianoAbbonamento.free,
          pazientiAttivi: 0,
          pazientiCollegatiTotali: 2,
          invitiInAttesa: 0,
        ),
        isA<LimiteRaggiunto>(),
      );
    });

    test('da Free a Start: consentito', () {
      expect(
        puoCambiarePiano(
          nuovo: PianoAbbonamento.start,
          pazientiAttivi: 1,
          pazientiCollegatiTotali: 1,
          invitiInAttesa: 0,
        ),
        isA<Consentito>(),
      );
    });
  });

  group('Listino (IVA esclusa)', () {
    test('prezzi come in CLAUDE.md', () {
      expect(
        PianoAbbonamento.start.prezzoCent(PeriodoFatturazione.mensile),
        1200,
      );
      expect(
        PianoAbbonamento.start.prezzoCent(PeriodoFatturazione.annuale),
        12000,
      );
      expect(
        PianoAbbonamento.pro.prezzoCent(PeriodoFatturazione.mensile),
        2500,
      );
      expect(
        PianoAbbonamento.pro.prezzoCent(PeriodoFatturazione.annuale),
        25000,
      );
      expect(formattaEuro(12000), '120 €');
    });
  });
}
