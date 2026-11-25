/// Kcal di un grammo di proteine, carboidrati e grassi (fattori di Atwater).
const double kcalPerGrammoProteine = 4;
const double kcalPerGrammoCarboidrati = 4;
const double kcalPerGrammoGrassi = 9;

/// Kcal che derivano dai grammi di macronutrienti (4/4/9 kcal per grammo).
double kcalDaMacro(double proteineG, double carboidratiG, double grassiG) =>
    proteineG * kcalPerGrammoProteine +
    carboidratiG * kcalPerGrammoCarboidrati +
    grassiG * kcalPerGrammoGrassi;

/// Controlli sugli obiettivi (UC_GP_6). I limiti sono costanti in un solo
/// punto; quelli marcati [DA CONFERMARE] si validano con il nutrizionista.
abstract final class ValidazioneObiettivi {
  /// Il database accetta già da 500 a 6000 kcal: l'app è più prudente.
  static const int kcalMin = 800;
  static const int kcalMax = 6000;

  /// Massimo plausibile di ogni macronutriente al giorno, in grammi.
  static const double macroMaxG = 1000;

  /// Scarto tra le kcal indicate e quelle dei macro oltre il quale si mostra
  /// un avviso non bloccante (10 %). [DA CONFERMARE]
  static const double tolleranzaKcal = 0.10;

  /// Legge un numero scritto anche con la virgola ("110,5"); `null` se non lo è.
  static double? leggiNumero(String testo) {
    final t = testo.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final d = double.tryParse(t);
    if (d == null || d.isNaN || d.isInfinite) return null;
    return d;
  }

  /// Le kcal sono un numero intero (la colonna è `integer`).
  static String? kcal(String testo) {
    final n = leggiNumero(testo);
    if (n == null) return 'Inserisci le kcal giornaliere (un numero).';
    if (n != n.roundToDouble()) {
      return 'Le kcal devono essere un numero intero.';
    }
    if (n < kcalMin || n > kcalMax) {
      return 'Le kcal devono essere tra $kcalMin e $kcalMax.';
    }
    return null;
  }

  /// [etichetta] è il nome del nutriente ("Proteine", "Carboidrati", "Grassi").
  /// Un solo decimale, come la colonna `numeric(5,1)`.
  static String? macro(String testo, String etichetta) {
    final n = leggiNumero(testo);
    if (n == null) {
      return 'Inserisci i grammi di ${etichetta.toLowerCase()} (un numero).';
    }
    if (n <= 0 || n > macroMaxG) {
      return '$etichetta: un valore maggiore di 0 e al massimo '
          '${macroMaxG.toInt()} g.';
    }
    final decimi = n * 10;
    if ((decimi - decimi.roundToDouble()).abs() > 1e-9) {
      return '$etichetta: al massimo un decimale.';
    }
    return null;
  }

  /// Avviso (non blocca il salvataggio) se le kcal dei macro differiscono da
  /// quelle indicate di più di [tolleranzaKcal]; `null` se sono coerenti.
  static String? avvisoCoerenza({
    required int kcal,
    required double proteineG,
    required double carboidratiG,
    required double grassiG,
  }) {
    final dalMacro = kcalDaMacro(proteineG, carboidratiG, grassiG);
    final scarto = (dalMacro - kcal).abs() / kcal;
    if (scarto <= tolleranzaKcal) return null;
    final percentuale = (scarto * 100).round();
    return 'Con questi macro le kcal sono circa ${dalMacro.round()}, '
        '$percentuale% di scarto rispetto a $kcal. Puoi salvare comunque.';
  }

  /// Verifica completa su valori già letti; il primo errore, o `null`.
  static String? obiettivi({
    required int kcal,
    required double proteineG,
    required double carboidratiG,
    required double grassiG,
  }) =>
      ValidazioneObiettivi.kcal('$kcal') ??
      macro('$proteineG', 'Proteine') ??
      macro('$carboidratiG', 'Carboidrati') ??
      macro('$grassiG', 'Grassi');
}
