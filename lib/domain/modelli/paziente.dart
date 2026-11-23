/// Stati del paziente (SCD_3, RF_GI_6).
enum StatoPaziente {
  invitato('Invitato'),
  attivo('Attivo'),
  archiviato('Archiviato');

  const StatoPaziente(this.etichetta);

  final String etichetta;

  static StatoPaziente daDb(String? valore) => StatoPaziente.values.firstWhere(
    (s) => s.name == valore,
    orElse: () => StatoPaziente.invitato,
  );
}

/// Riga dell'elenco pazienti del nutrizionista (UC_GI_3).
class PazienteElenco {
  const PazienteElenco({
    required this.id,
    required this.nome,
    required this.stato,
    this.dataCollegamento,
    this.archiviatoDalPaziente = false,
  });

  final String id;
  final String nome;
  final StatoPaziente stato;
  final DateTime? dataCollegamento;

  /// `true` se il paziente si è scollegato da solo (UC_GI_5): per seguirlo
  /// di nuovo serve un nuovo invito, non la riattivazione.
  final bool archiviatoDalPaziente;
}

/// Stati di un invito (SCD_1).
enum StatoInvito {
  creato('In attesa'),
  utilizzato('Usato'),
  scaduto('Scaduto'),
  revocato('Revocato');

  const StatoInvito(this.etichetta);

  final String etichetta;

  static StatoInvito daDb(String? valore) => StatoInvito.values.firstWhere(
    (s) => s.name == valore,
    orElse: () => StatoInvito.scaduto,
  );
}

/// Invito creato dal nutrizionista (UC_GI_1).
class Invito {
  const Invito({
    required this.id,
    required this.codice,
    required this.stato,
    required this.scadenza,
    this.nome,
  });

  final String id;
  final String codice;
  final StatoInvito stato;
  final DateTime scadenza;

  /// Nome indicato dal nutrizionista (facoltativo).
  final String? nome;

  /// Un invito "creato" ma oltre la scadenza è di fatto scaduto (SCD_1).
  StatoInvito statoEffettivo(DateTime adesso) =>
      stato == StatoInvito.creato && scadenza.isBefore(adesso)
      ? StatoInvito.scaduto
      : stato;
}
