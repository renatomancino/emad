import '../domain/modelli/alimento.dart';
import '../domain/repository/pazienti_repository.dart';

/// Il nutrizionista ha già un alimento personalizzato con questo codice.
const erroreCodiceBarreEsistente = ErroreOperazione(
  'Hai già un alimento con questo codice a barre: scansionalo di nuovo per '
  'usarlo.',
  codice: 'codice_barre_esistente',
);

/// Cache degli alimenti del nutrizionista: tabella `alimenti` più recenti e
/// preferiti (RF_GP_3, RF_GP_14). Implementata su Supabase e in memoria.
abstract interface class AlimentiCache {
  /// Alimenti il cui nome contiene [testo]: prima i preferiti, poi i più
  /// recenti, poi in ordine alfabetico. Con il flag `preferito` impostato.
  Future<List<Alimento>> cercaPerNome(String testo, {int limite = 20});

  /// L'alimento con questo codice a barre, se è in cache e l'utente lo vede.
  /// Se ci sono sia quello di Open Food Facts sia uno personalizzato proprio,
  /// vince il personalizzato: il nutrizionista lo ha inserito apposta.
  Future<Alimento?> perCodiceBarre(String codice);

  /// Salva un alimento nella cache e restituisce la copia con `id`.
  /// Quelli di Open Food Facts non si duplicano (stesso codice a barre, o
  /// stesso nome e marca); quelli personalizzati si creano sempre, ma uno
  /// stesso codice a barre si ripete al massimo una volta per nutrizionista
  /// (`ErroreOperazione` con codice `codice_barre_esistente`).
  Future<Alimento> salva(Alimento alimento);

  /// Segna l'alimento come usato adesso dal nutrizionista (recenti).
  Future<void> segnaUso(String alimentoId);

  /// Gli ultimi alimenti usati, dal più recente.
  Future<List<Alimento>> recenti({int limite = 10});

  Future<List<Alimento>> preferiti();

  Future<void> impostaPreferito(String alimentoId, bool preferito);
}
