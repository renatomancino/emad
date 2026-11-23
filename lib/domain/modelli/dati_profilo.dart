/// Dati modificabili del profilo (UC_GA_3, RF_GA_5).
/// Paziente: nome, altezza, data di nascita, obiettivo.
/// Nutrizionista: nome e titolo.
class DatiProfilo {
  const DatiProfilo({
    required this.nome,
    this.titolo,
    this.altezzaCm,
    this.dataNascita,
    this.obiettivo,
  });

  final String nome;

  /// Solo nutrizionista (es. "Biologa nutrizionista").
  final String? titolo;

  /// Solo paziente collegato.
  final double? altezzaCm;
  final DateTime? dataNascita;
  final String? obiettivo;

  DatiProfilo copiaCon({
    String? nome,
    String? titolo,
    double? altezzaCm,
    DateTime? dataNascita,
    String? obiettivo,
  }) => DatiProfilo(
    nome: nome ?? this.nome,
    titolo: titolo ?? this.titolo,
    altezzaCm: altezzaCm ?? this.altezzaCm,
    dataNascita: dataNascita ?? this.dataNascita,
    obiettivo: obiettivo ?? this.obiettivo,
  );
}
