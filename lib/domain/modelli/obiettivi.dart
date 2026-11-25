/// Obiettivi nutrizionali giornalieri di un paziente (RF_GP_16, UC_GP_6).
///
/// A ogni modifica si salva una nuova riga: le precedenti formano lo storico.
/// Cambiare gli obiettivi non altera i piani già assegnati; cambia solo lo
/// scostamento mostrato nell'editor.
class Obiettivi {
  const Obiettivi({
    required this.kcal,
    required this.proteineG,
    required this.carboidratiG,
    required this.grassiG,
    required this.dal,
    this.id,
  });

  final String? id;
  final int kcal;
  final double proteineG;
  final double carboidratiG;
  final double grassiG;

  /// Giorno da cui valgono (colonna `data_inizio`).
  final DateTime dal;

  /// Stessi valori nutrizionali (la data non conta).
  bool haStessiValori(Obiettivi altri) =>
      kcal == altri.kcal &&
      proteineG == altri.proteineG &&
      carboidratiG == altri.carboidratiG &&
      grassiG == altri.grassiG;

  @override
  String toString() =>
      'Obiettivi($kcal kcal, P $proteineG, C $carboidratiG, G $grassiG)';
}
