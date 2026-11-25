/// Controlli sui valori di un alimento per 100 g (RF_GP_5), usati dal modulo
/// dell'alimento personalizzato e dal repository. Messaggi in italiano.
abstract final class ValidazioneAlimento {
  /// Massimo di kcal per 100 g (il grasso puro ne ha circa 900).
  static const double kcalMax = 900;

  /// Massimo di ogni macronutriente per 100 g di alimento.
  static const double macroMax = 100;

  static const int lunghezzaMassimaNome = 200;

  /// Legge un numero scritto anche con la virgola ("12,5"); `null` se non lo è.
  static double? leggiNumero(String testo) {
    final t = testo.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final d = double.tryParse(t);
    if (d == null || d.isNaN || d.isInfinite) return null;
    return d;
  }

  static String? nome(String testo) {
    final t = testo.trim();
    if (t.isEmpty) return 'Inserisci il nome dell\'alimento.';
    if (t.length > lunghezzaMassimaNome) {
      return 'Il nome può avere al massimo $lunghezzaMassimaNome caratteri.';
    }
    return null;
  }

  static String? kcal(String testo) {
    final n = leggiNumero(testo);
    if (n == null) return 'Inserisci le kcal per 100 g (un numero).';
    if (n < 0 || n > kcalMax) {
      return 'Le kcal per 100 g devono essere tra 0 e ${kcalMax.toInt()}.';
    }
    return null;
  }

  /// [etichetta] è il nome del nutriente ("Proteine", "Grassi", ...).
  static String? macro(String testo, String etichetta) {
    final n = leggiNumero(testo);
    if (n == null) {
      return 'Inserisci i grammi di ${etichetta.toLowerCase()} (un numero).';
    }
    if (n < 0 || n > macroMax) {
      return '$etichetta: valore tra 0 e ${macroMax.toInt()} g per 100 g.';
    }
    return null;
  }

  /// Proteine, carboidrati e grassi insieme non superano i 100 g su 100 g
  /// (con una piccola tolleranza per gli arrotondamenti).
  static String? somma(double proteine, double carboidrati, double grassi) {
    if (proteine + carboidrati + grassi > macroMax + 0.5) {
      return 'Proteine, carboidrati e grassi insieme non possono superare '
          '${macroMax.toInt()} g su 100 g.';
    }
    return null;
  }

  /// Controllo completo sui valori già letti; il primo errore, o `null`.
  static String? alimento({
    required String nome,
    required double kcal100g,
    required double proteine100g,
    required double carboidrati100g,
    required double grassi100g,
  }) {
    final errorNome = ValidazioneAlimento.nome(nome);
    if (errorNome != null) return errorNome;
    final errorKcal = ValidazioneAlimento.kcal(kcal100g.toString());
    if (errorKcal != null) return errorKcal;
    for (final (etichetta, valore) in [
      ('Proteine', proteine100g),
      ('Carboidrati', carboidrati100g),
      ('Grassi', grassi100g),
    ]) {
      final e = macro(valore.toString(), etichetta);
      if (e != null) return e;
    }
    return somma(proteine100g, carboidrati100g, grassi100g);
  }
}
