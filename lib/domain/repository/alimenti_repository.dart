import '../modelli/alimento.dart';

/// Open Food Facts non risponde, è lento o ha risposto in modo inatteso.
/// Non è un errore dell'utente: la ricerca ripiega sulla cache e lo dice.
class ServizioAlimentiNonDisponibile implements Exception {
  const ServizioAlimentiNonDisponibile([this.dettaglio]);

  final String? dettaglio;

  @override
  String toString() => 'ServizioAlimentiNonDisponibile: ${dettaglio ?? '-'}';
}

/// Servizio esterno di alimenti (Open Food Facts, RNF_IN_1).
abstract interface class FonteAlimentiOnline {
  /// Ricerca per nome. Lancia [ServizioAlimentiNonDisponibile] se il servizio
  /// non è raggiungibile.
  Future<List<Alimento>> cercaPerNome(String testo, {int limite = 10});

  /// Ricerca per codice a barre (riusata dalla scheda barcode).
  Future<Alimento?> perCodiceBarre(String codice);
}

/// Esito di una ricerca (UC_GP_3).
class RisultatoRicerca {
  const RisultatoRicerca({
    required this.alimenti,
    this.onlineNonDisponibile = false,
    this.onlineSaltato = false,
    this.durata = Duration.zero,
  });

  /// Prima gli alimenti già in cache, poi quelli trovati online.
  final List<Alimento> alimenti;

  /// Il servizio online non ha risposto: i risultati vengono dalla cache.
  final bool onlineNonDisponibile;

  /// La cache bastava e non si è chiamato il servizio online
  /// (l'utente può chiedere "Cerca anche online").
  final bool onlineSaltato;

  /// Tempo impiegato dalla ricerca (RNF_P_3: meno di 2 secondi).
  final Duration durata;
}

/// Alimenti del nutrizionista: ricerca con cache, alimenti personalizzati,
/// recenti e preferiti (RF_GP_3, RF_GP_5, RF_GP_14).
abstract interface class AlimentiRepository {
  /// Cerca prima nella cache e poi online. Con [anchePerOnline] chiama sempre
  /// il servizio online, anche se la cache ha già abbastanza risultati.
  Future<RisultatoRicerca> cerca(String testo, {bool anchePerOnline = false});

  /// L'alimento scelto: se viene da Open Food Facts lo salva nella cache con
  /// la fonte, poi lo segna tra i recenti. Restituisce l'alimento con `id`.
  /// Lancia `ErroreOperazione` per un alimento senza tutti i valori.
  Future<Alimento> scegli(Alimento alimento);

  /// Crea un alimento personalizzato (fonte `personalizzato`, RF_GP_5).
  Future<Alimento> creaPersonalizzato({
    required String nome,
    required double kcal100g,
    required double proteine100g,
    required double carboidrati100g,
    required double grassi100g,
    String? marca,
  });

  /// Gli ultimi alimenti usati, dal più recente.
  Future<List<Alimento>> recenti({int limite = 10});

  Future<List<Alimento>> preferiti();

  Future<void> impostaPreferito(Alimento alimento, bool preferito);
}
