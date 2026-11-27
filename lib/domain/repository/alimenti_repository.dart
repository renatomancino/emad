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

  /// Ricerca per codice a barre (RF_GP_4): `null` se il prodotto non c'è o
  /// non ha un nome. Lancia [ServizioAlimentiNonDisponibile] se il servizio
  /// non è raggiungibile.
  Future<Alimento?> perCodiceBarre(String codice);
}

/// Esito della ricerca di un codice a barre letto dalla fotocamera
/// (UC_GP_3, SC_GP_2, SD_2).
sealed class EsitoCodiceBarre {
  const EsitoCodiceBarre(this.codice);

  /// Codice normalizzato (vedi `CodiceBarre.normalizza`).
  final String codice;
}

/// Prodotto con tutti i valori: si può aggiungere al pasto.
final class CodiceTrovato extends EsitoCodiceBarre {
  const CodiceTrovato(super.codice, this.alimento, {required this.daCache});

  final Alimento alimento;

  /// Era già nella cache: Open Food Facts non è stato chiamato.
  final bool daCache;
}

/// Open Food Facts conosce il prodotto ma non ha tutti i valori: non va in
/// cache come completo, si propone l'inserimento a mano (D9).
final class CodiceIncompleto extends EsitoCodiceBarre {
  const CodiceIncompleto(super.codice, this.alimento);

  final Alimento alimento;
}

/// Né la cache né Open Food Facts conoscono il codice (UC_GP_3, flusso 2.1).
final class CodiceNonTrovato extends EsitoCodiceBarre {
  const CodiceNonTrovato(super.codice);
}

/// Open Food Facts non ha risposto (UC_GP_3, flusso 2.2).
final class CodiceServizioNonDisponibile extends EsitoCodiceBarre {
  const CodiceServizioNonDisponibile(super.codice);
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
  ///
  /// Se la cache ha risultati e si deve ancora attendere il servizio online,
  /// [alRisultatoDallaCache] li riceve subito: con un servizio lento non si
  /// aspetta (RNF_P_3, UC_GP_3: nessun blocco dell'editor).
  Future<RisultatoRicerca> cerca(
    String testo, {
    bool anchePerOnline = false,
    void Function(RisultatoRicerca dallaCache)? alRisultatoDallaCache,
  });

  /// L'alimento scelto: se viene da Open Food Facts lo salva nella cache con
  /// la fonte, poi lo segna tra i recenti. Restituisce l'alimento con `id`.
  /// Lancia `ErroreOperazione` per un alimento senza tutti i valori.
  Future<Alimento> scegli(Alimento alimento);

  /// Cerca un codice a barre già normalizzato: prima nella cache (se c'è,
  /// Open Food Facts non si chiama), poi online. Non salva nulla: si salva con
  /// [scegli] quando il nutrizionista aggiunge l'alimento (RF_GP_4).
  /// Lancia `ErroreOperazione` se la cache non è raggiungibile.
  Future<EsitoCodiceBarre> perCodiceBarre(String codice);

  /// Crea un alimento personalizzato (fonte `personalizzato`, RF_GP_5), con
  /// il codice a barre se viene da una scansione senza risultato.
  Future<Alimento> creaPersonalizzato({
    required String nome,
    required double kcal100g,
    required double proteine100g,
    required double carboidrati100g,
    required double grassi100g,
    String? marca,
    String? codiceBarre,
  });

  /// Gli ultimi alimenti usati, dal più recente.
  Future<List<Alimento>> recenti({int limite = 10});

  Future<List<Alimento>> preferiti();

  Future<void> impostaPreferito(Alimento alimento, bool preferito);
}
