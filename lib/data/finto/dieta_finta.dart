import '../../domain/modelli/alimento.dart';
import '../../domain/modelli/piano_alimentare.dart';
import 'dipendenze_finte.dart';

/// Dati fittizi della sezione Dieta per provare l'app senza Supabase
/// (`--dart-define=CENATO_RUOLO_FINTO=paziente`). Valori presi dal mock-up
/// UI_GP_1 del RAD; nessun dato reale.
///
/// Non sono caricati da `DipendenzeFinte` (che usano anche i test, dove il
/// primo salvataggio deve restare "versione 1"): li carica solo `main.dart`.
abstract final class DietaFinta {
  /// Id della riga `pazienti` di Marco, il paziente simulato (vedi
  /// `CollegamentoRepositoryFinto.pazienteId`).
  static const pazienteId = 'p1';

  static const _latte = Alimento(
    id: 'demo-latte',
    nome: 'Latte parzialmente scremato',
    kcal100g: 46,
    proteine100g: 3.4,
    carboidrati100g: 4.9,
    grassi100g: 1.6,
    fonte: FonteAlimento.personalizzato,
  );
  static const _cereali = Alimento(
    id: 'demo-cereali',
    nome: 'Cereali integrali',
    kcal100g: 370,
    proteine100g: 9,
    carboidrati100g: 72,
    grassi100g: 4,
    fonte: FonteAlimento.personalizzato,
  );
  static const _fette = Alimento(
    id: 'demo-fette',
    nome: 'Fette biscottate',
    kcal100g: 410,
    proteine100g: 11,
    carboidrati100g: 72,
    grassi100g: 6,
    fonte: FonteAlimento.personalizzato,
  );
  static const _yogurt = Alimento(
    id: 'demo-yogurt',
    nome: 'Yogurt bianco',
    kcal100g: 61,
    proteine100g: 3.5,
    carboidrati100g: 4.7,
    grassi100g: 3.3,
    fonte: FonteAlimento.personalizzato,
  );
  static const _pasta = Alimento(
    id: 'demo-pasta',
    nome: 'Pasta integrale',
    kcal100g: 350,
    proteine100g: 13,
    carboidrati100g: 66,
    grassi100g: 2.5,
    fonte: FonteAlimento.personalizzato,
  );
  static const _riso = Alimento(
    id: 'demo-riso',
    nome: 'Riso integrale',
    kcal100g: 360,
    proteine100g: 7.5,
    carboidrati100g: 77,
    grassi100g: 2.7,
    fonte: FonteAlimento.personalizzato,
  );
  static const _insalata = Alimento(
    id: 'demo-insalata',
    nome: 'Insalata mista',
    kcal100g: 20,
    proteine100g: 1.5,
    carboidrati100g: 3,
    grassi100g: 0.2,
    fonte: FonteAlimento.personalizzato,
  );
  static const _olio = Alimento(
    id: 'demo-olio',
    nome: 'Olio extravergine di oliva',
    kcal100g: 899,
    proteine100g: 0,
    carboidrati100g: 0,
    grassi100g: 99.9,
    fonte: FonteAlimento.personalizzato,
  );
  static const _pesce = Alimento(
    id: 'demo-pesce',
    nome: 'Merluzzo al forno',
    kcal100g: 82,
    proteine100g: 18,
    carboidrati100g: 0,
    grassi100g: 0.7,
    fonte: FonteAlimento.personalizzato,
  );
  static const _pollo = Alimento(
    id: 'demo-pollo',
    nome: 'Petto di pollo',
    kcal100g: 110,
    proteine100g: 23,
    carboidrati100g: 0,
    grassi100g: 1.2,
    fonte: FonteAlimento.personalizzato,
  );
  static const _verdure = Alimento(
    id: 'demo-verdure',
    nome: 'Verdure cotte',
    kcal100g: 30,
    proteine100g: 2,
    carboidrati100g: 5,
    grassi100g: 0.3,
    fonte: FonteAlimento.personalizzato,
  );
  static const _pane = Alimento(
    id: 'demo-pane',
    nome: 'Pane integrale',
    kcal100g: 240,
    proteine100g: 8.5,
    carboidrati100g: 45,
    grassi100g: 2,
    fonte: FonteAlimento.personalizzato,
  );

  /// Piano di una settimana intera, così qualunque sia il giorno della prova
  /// "oggi" è nel piano. Lunedì come il mock-up; il mercoledì e il sabato
  /// cambiano pranzo e cena per vedere che i giorni sono diversi.
  static PianoAlimentare piano() {
    PastoPiano colazione() => PastoPiano(
      tipo: TipoPasto.colazione,
      orario: '08:00',
      voci: [
        VocePiano(alimento: _latte, quantitaG: 200),
        VocePiano(
          alimento: _cereali,
          quantitaG: 40,
          alternative: const [
            AlternativaPiano(alimento: _fette, quantitaG: 35),
          ],
        ),
      ],
    );
    PastoPiano spuntino() => PastoPiano(
      tipo: TipoPasto.spuntino,
      orario: '10:30',
      voci: [VocePiano(alimento: _yogurt, quantitaG: 125)],
    );
    PastoPiano pranzoPasta() => PastoPiano(
      tipo: TipoPasto.pranzo,
      orario: '13:00',
      voci: [
        VocePiano(
          alimento: _pasta,
          quantitaG: 80,
          alternative: const [AlternativaPiano(alimento: _riso, quantitaG: 80)],
        ),
        VocePiano(alimento: _insalata, quantitaG: 150),
        VocePiano(alimento: _olio, quantitaG: 10),
      ],
    );
    PastoPiano pranzoRiso() => PastoPiano(
      tipo: TipoPasto.pranzo,
      orario: '13:00',
      voci: [
        VocePiano(alimento: _riso, quantitaG: 80),
        VocePiano(alimento: _verdure, quantitaG: 200),
        VocePiano(alimento: _olio, quantitaG: 10),
      ],
    );
    PastoPiano cenaPesce() => PastoPiano(
      tipo: TipoPasto.cena,
      orario: '20:00',
      voci: [
        VocePiano(
          alimento: _pesce,
          quantitaG: 150,
          alternative: const [
            AlternativaPiano(alimento: _pollo, quantitaG: 120),
          ],
        ),
        VocePiano(alimento: _verdure, quantitaG: 200),
        VocePiano(alimento: _pane, quantitaG: 50),
      ],
    );
    PastoPiano cenaPollo() => PastoPiano(
      tipo: TipoPasto.cena,
      orario: '20:00',
      voci: [
        VocePiano(alimento: _pollo, quantitaG: 150),
        VocePiano(alimento: _insalata, quantitaG: 150),
        VocePiano(alimento: _pane, quantitaG: 50),
      ],
    );

    final oggi = DateTime.now();
    return PianoAlimentare(
      dataInizio: DateTime(
        oggi.year,
        oggi.month,
        oggi.day,
      ).subtract(const Duration(days: 7)),
      giorni: [
        for (final g in GiorniSettimana.tutti)
          GiornoPiano(
            giornoSettimana: g,
            pasti: [
              colazione(),
              spuntino(),
              if (g == 3 || g == 6) pranzoRiso() else pranzoPasta(),
              if (g == 3 || g == 6) cenaPollo() else cenaPesce(),
            ],
          ),
      ],
    );
  }

  /// Carica gli obiettivi (sempre: senza piano restano visibili, RF_GP_16)
  /// e, se [conPiano], salva il piano come versione corrente. Si passa dai
  /// repository finti, che assegnano gli id e validano come `salva_piano`.
  static Future<void> carica(
    DipendenzeFinte finte, {
    bool conPiano = true,
  }) async {
    await finte.obiettivi.imposta(
      pazienteId,
      kcal: 2000,
      proteineG: 110,
      carboidratiG: 230,
      grassiG: 65,
    );
    if (conPiano) await finte.piani.salva(pazienteId, piano());
  }
}
