/// Ruolo dell'utente (Entity Utente, RAD §3.4.3). Scelto alla registrazione
/// (UC_GA_1) e non modificabile dopo.
enum Ruolo {
  nutrizionista,
  paziente;

  /// Valore usato nel database (enum `ruolo_utente`).
  String get valoreDb => name;

  /// Etichetta da mostrare nell'interfaccia.
  String get etichetta => switch (this) {
    Ruolo.nutrizionista => 'Nutrizionista',
    Ruolo.paziente => 'Paziente',
  };

  static Ruolo? daDb(String? valore) {
    for (final r in Ruolo.values) {
      if (r.valoreDb == valore) return r;
    }
    return null;
  }
}

/// Profilo dell'utente autenticato (tabella `profili`).
class Profilo {
  const Profilo({required this.id, required this.ruolo, required this.nome});

  final String id;
  final Ruolo ruolo;
  final String nome;

  /// Crea il profilo da una riga della tabella `profili`.
  /// Restituisce `null` se il ruolo non è riconosciuto.
  static Profilo? daRiga(Map<String, dynamic> riga) {
    final ruolo = Ruolo.daDb(riga['ruolo'] as String?);
    if (ruolo == null) return null;
    return Profilo(
      id: riga['id'] as String,
      ruolo: ruolo,
      nome: (riga['nome'] as String?) ?? '',
    );
  }
}
