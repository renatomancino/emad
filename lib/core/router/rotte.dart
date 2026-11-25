/// Percorsi delle schermate (NP_1_PAZ e NP_2_NUT, RAD §3.4.5.1).
abstract final class Rotte {
  // Pubbliche (fuori dall'area protetta)
  static const caricamento = '/caricamento';
  static const accesso = '/accesso';
  static const registrazione = '/registrazione';
  static const recuperoPassword = '/recupero-password';

  /// Dopo il rientro dal link di reimpostazione password (UC_GA_4).
  static const nuovaPassword = '/nuova-password';

  /// Eliminazione dell'account (UC_GA_5): per tutti i ruoli.
  static const eliminaAccount = '/elimina-account';

  // Paziente: quattro sezioni nella barra inferiore (RNF_U_6)
  static const pazienteOggi = '/paziente/oggi';
  static const pazienteDieta = '/paziente/dieta';
  static const pazienteAndamento = '/paziente/andamento';
  static const pazienteVisite = '/paziente/visite';
  static const pazienteProfilo = '/paziente/profilo';
  static const pazienteCollegamento = '/paziente/collegamento';

  // Nutrizionista
  static const nutPazienti = '/nutrizionista/pazienti';
  static const nutInvito = '/nutrizionista/pazienti/invito';
  static const nutCalendario = '/nutrizionista/calendario';
  static const nutDisponibilita = '/nutrizionista/disponibilita';
  static const nutProfilo = '/nutrizionista/profilo';
  static const nutAlimenti = '/nutrizionista/profilo/alimenti';
  static const nutAlimentoNuovo = '/nutrizionista/profilo/alimenti/nuovo';

  static const pubbliche = {accesso, registrazione, recuperoPassword};
}
