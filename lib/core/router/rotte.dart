/// Percorsi delle schermate (NP_1_PAZ e NP_2_NUT, RAD §3.4.5.1).
abstract final class Rotte {
  // Pubbliche (fuori dall'area protetta)
  static const caricamento = '/caricamento';
  static const accesso = '/accesso';
  static const registrazione = '/registrazione';
  static const recuperoPassword = '/recupero-password';

  // Paziente: quattro sezioni nella barra inferiore (RNF_U_6)
  static const pazienteOggi = '/paziente/oggi';
  static const pazienteDieta = '/paziente/dieta';
  static const pazienteAndamento = '/paziente/andamento';
  static const pazienteVisite = '/paziente/visite';
  static const pazienteProfilo = '/paziente/profilo';

  // Nutrizionista
  static const nutPazienti = '/nutrizionista/pazienti';
  static const nutCalendario = '/nutrizionista/calendario';
  static const nutProfilo = '/nutrizionista/profilo';

  static const pubbliche = {accesso, registrazione, recuperoPassword};
}
