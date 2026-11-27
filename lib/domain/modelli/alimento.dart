/// Origine di un alimento nella tabella `alimenti` (tipo `fonte_alimento`).
enum FonteAlimento {
  openFoodFacts('open_food_facts'),
  personalizzato('personalizzato');

  const FonteAlimento(this.valoreDb);

  /// Valore salvato nel database.
  final String valoreDb;

  static FonteAlimento daDb(String valore) => values.firstWhere(
    (f) => f.valoreDb == valore,
    orElse: () => FonteAlimento.personalizzato,
  );
}

/// Alimento con i valori nutrizionali per 100 g (RF_GP_3, RF_GP_5).
///
/// I valori sono facoltativi perché Open Food Facts a volte non li ha: un
/// alimento è [completo] solo con kcal e tutti e tre i macro. Solo quelli
/// completi vanno nella cache (`alimenti`), che richiede tutti i valori.
class Alimento {
  const Alimento({
    this.id,
    required this.nome,
    this.marca,
    this.codiceBarre,
    this.kcal100g,
    this.proteine100g,
    this.carboidrati100g,
    this.grassi100g,
    required this.fonte,
    this.preferito = false,
  });

  /// Identificativo nella cache; `null` per un risultato non ancora salvato.
  final String? id;
  final String nome;
  final String? marca;
  final String? codiceBarre;
  final double? kcal100g;
  final double? proteine100g;
  final double? carboidrati100g;
  final double? grassi100g;
  final FonteAlimento fonte;
  final bool preferito;

  bool get completo =>
      kcal100g != null &&
      proteine100g != null &&
      carboidrati100g != null &&
      grassi100g != null;

  Alimento copyWith({String? id, bool? preferito, String? codiceBarre}) =>
      Alimento(
        id: id ?? this.id,
        nome: nome,
        marca: marca,
        codiceBarre: codiceBarre ?? this.codiceBarre,
        kcal100g: kcal100g,
        proteine100g: proteine100g,
        carboidrati100g: carboidrati100g,
        grassi100g: grassi100g,
        fonte: fonte,
        preferito: preferito ?? this.preferito,
      );

  /// Riga della tabella `alimenti`. I numeri arrivano come `num` o come testo.
  factory Alimento.daRiga(Map<String, dynamic> riga, {bool preferito = false}) {
    double? numero(Object? v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };
    return Alimento(
      id: riga['id'] as String?,
      nome: riga['nome'] as String,
      marca: riga['marca'] as String?,
      codiceBarre: riga['codice_barre'] as String?,
      kcal100g: numero(riga['kcal_100g']),
      proteine100g: numero(riga['proteine_100g']),
      carboidrati100g: numero(riga['carboidrati_100g']),
      grassi100g: numero(riga['grassi_100g']),
      fonte: FonteAlimento.daDb(riga['fonte'] as String),
      preferito: preferito,
    );
  }

  /// Colonne da scrivere in `alimenti`. Solo per alimenti [completo].
  Map<String, dynamic> perInserimento({String? creatoDa}) {
    assert(completo, 'Un alimento incompleto non va salvato nella cache');
    return {
      'nome': nome,
      'marca': marca,
      'codice_barre': codiceBarre,
      'kcal_100g': kcal100g,
      'proteine_100g': proteine100g,
      'carboidrati_100g': carboidrati100g,
      'grassi_100g': grassi100g,
      'fonte': fonte.valoreDb,
      'creato_da': creatoDa,
    };
  }
}
