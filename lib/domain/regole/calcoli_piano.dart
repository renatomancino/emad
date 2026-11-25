import '../modelli/alimento.dart';
import '../modelli/obiettivi.dart';
import '../modelli/piano_alimentare.dart';

/// Calcoli del piano (RF_GP_2, RF_GP_16): funzioni pure, le usa l'editor e
/// le deve usare ogni schermata che mostra kcal e macro di un piano.
///
/// Le costanti marcate [DA CONFERMARE] sono in questo solo punto.

/// Scarto dall'obiettivo (in valore relativo) oltre il quale un totale è
/// "fuori obiettivo": 10 %. [DA CONFERMARE]
const double tolleranzaScostamento = 0.10;

/// Quantità tipiche per inserire una voce con pochi tocchi (RF_GP_15).
const List<int> quantitaRapideG = [50, 100, 150, 200];

/// Quantità massima accettata dall'app per una voce, in grammi (il database
/// ne accetta fino a 10000). [DA CONFERMARE]
const double quantitaMaxG = 5000;

/// Un decimale, come le colonne `numeric(x,1)` del database.
double arrotonda1(double v) => (v * 10).roundToDouble() / 10;

/// Kcal e macro di [quantitaG] grammi di [alimento] (valori per 100 g).
/// Arrotondati a un decimale come fa `salva_piano` nel database, così i
/// totali mostrati prima di salvare coincidono con quelli salvati.
/// Un alimento senza tutti i valori non ha macro: [Macro.zero].
Macro macroVoce(Alimento alimento, double quantitaG) {
  if (!alimento.completo || quantitaG <= 0) return Macro.zero;
  double v(double per100g) => arrotonda1(per100g * quantitaG / 100);
  return Macro(
    kcal: v(alimento.kcal100g!),
    proteineG: v(alimento.proteine100g!),
    carboidratiG: v(alimento.carboidrati100g!),
    grassiG: v(alimento.grassi100g!),
  );
}

/// Quanto cambia scegliendo l'alternativa al posto della voce originale
/// (positivo = più kcal/macro dell'originale).
Macro differenzaAlternativa(VocePiano voce, AlternativaPiano alternativa) =>
    macroVoce(alternativa.alimento, alternativa.quantitaG) -
    macroVoce(voce.alimento, voce.quantitaG);

/// Nome di un modello (pasto salvato o piano modello): da 1 a 120 caratteri,
/// come il vincolo della tabella `modelli_piano`.
const int lunghezzaMassimaNomeModello = 120;

String? validaNomeModello(String testo) {
  final t = testo.trim();
  if (t.isEmpty) return 'Dai un nome al modello.';
  if (t.length > lunghezzaMassimaNomeModello) {
    return 'Il nome può avere al massimo $lunghezzaMassimaNomeModello '
        'caratteri.';
  }
  return null;
}

Macro macroPasto(PastoPiano pasto) =>
    [for (final v in pasto.voci) macroVoce(v.alimento, v.quantitaG)]
        .fold(Macro.zero, (a, b) => a + b);

Macro macroGiorno(GiornoPiano giorno) =>
    giorno.pasti.map(macroPasto).fold(Macro.zero, (a, b) => a + b);

/// Posizione di un totale rispetto all'obiettivo.
enum StatoScostamento { inLinea, sopra, sotto }

/// Scarto di un valore dal suo obiettivo.
class ScostamentoValore {
  const ScostamentoValore({required this.totale, required this.obiettivo});

  final double totale;
  final double obiettivo;

  double get assoluto => totale - obiettivo;

  /// Scarto relativo (0,03 = +3 %); 0 se l'obiettivo è zero.
  double get relativo => obiettivo == 0 ? 0 : assoluto / obiettivo;

  StatoScostamento get stato {
    if (relativo.abs() <= tolleranzaScostamento + 1e-9) {
      return StatoScostamento.inLinea;
    }
    return relativo > 0 ? StatoScostamento.sopra : StatoScostamento.sotto;
  }
}

/// Scostamento di un giorno da tutti gli obiettivi (RF_GP_16).
class Scostamento {
  const Scostamento({
    required this.kcal,
    required this.proteine,
    required this.carboidrati,
    required this.grassi,
  });

  final ScostamentoValore kcal;
  final ScostamentoValore proteine;
  final ScostamentoValore carboidrati;
  final ScostamentoValore grassi;

  /// Tutti i valori sono entro la tolleranza.
  bool get inLinea => [
    kcal,
    proteine,
    carboidrati,
    grassi,
  ].every((s) => s.stato == StatoScostamento.inLinea);
}

Scostamento scostamento(Macro totale, Obiettivi obiettivi) => Scostamento(
  kcal: ScostamentoValore(
    totale: totale.kcal,
    obiettivo: obiettivi.kcal.toDouble(),
  ),
  proteine: ScostamentoValore(
    totale: totale.proteineG,
    obiettivo: obiettivi.proteineG,
  ),
  carboidrati: ScostamentoValore(
    totale: totale.carboidratiG,
    obiettivo: obiettivi.carboidratiG,
  ),
  grassi: ScostamentoValore(
    totale: totale.grassiG,
    obiettivo: obiettivi.grassiG,
  ),
);

/// Controllo della quantità scritta dall'utente (UC_GP_2, flusso 4.1).
/// Accetta la virgola; restituisce il messaggio o `null`.
String? validaQuantita(String testo) {
  final t = testo.trim().replaceAll(',', '.');
  if (t.isEmpty) return 'Inserisci la quantità in grammi.';
  final n = double.tryParse(t);
  if (n == null || n.isNaN || n.isInfinite) {
    return 'Inserisci un numero, per esempio 150.';
  }
  if (n <= 0) return 'La quantità deve essere maggiore di zero.';
  if (n > quantitaMaxG) {
    return 'La quantità può essere al massimo ${quantitaMaxG.toInt()} g.';
  }
  if ((n * 10 - (n * 10).roundToDouble()).abs() > 1e-9) {
    return 'Usa al massimo un decimale.';
  }
  return null;
}

/// Quantità già validata da [validaQuantita], come numero.
double leggiQuantita(String testo) =>
    double.parse(testo.trim().replaceAll(',', '.'));

/// Che cosa impedisce di salvare un piano.
enum TipoProblema { pianoSenzaGiorni, giornoSenzaPasti, pastoSenzaAlimenti }

class ProblemaPiano {
  const ProblemaPiano({
    required this.tipo,
    required this.messaggio,
    this.giorno,
    this.chiavePasto,
  });

  final TipoProblema tipo;
  final String messaggio;
  final int? giorno;
  final String? chiavePasto;
}

/// Problemi che bloccano il salvataggio (UC_GP_1, flusso di errore 8.1):
/// piano senza giorni, giorno senza pasti, pasto senza alimenti.
List<ProblemaPiano> problemiDelPiano(PianoAlimentare piano) {
  if (piano.giorni.isEmpty) {
    return const [
      ProblemaPiano(
        tipo: TipoProblema.pianoSenzaGiorni,
        messaggio: 'Il piano non ha giorni: aggiungi almeno un giorno.',
      ),
    ];
  }
  final problemi = <ProblemaPiano>[];
  for (final g in piano.giorni) {
    final nome = GiorniSettimana.nome(g.giornoSettimana);
    if (g.pasti.isEmpty) {
      problemi.add(
        ProblemaPiano(
          tipo: TipoProblema.giornoSenzaPasti,
          messaggio: '$nome non ha pasti: aggiungili o togli il giorno.',
          giorno: g.giornoSettimana,
        ),
      );
    }
    for (final p in g.pasti) {
      if (p.voci.isEmpty) {
        problemi.add(
          ProblemaPiano(
            tipo: TipoProblema.pastoSenzaAlimenti,
            messaggio:
                '$nome, ${p.tipo.etichetta.toLowerCase()}: pasto senza '
                'alimenti. Completalo o eliminalo.',
            giorno: g.giornoSettimana,
            chiavePasto: p.chiave,
          ),
        );
      }
    }
  }
  return problemi;
}
