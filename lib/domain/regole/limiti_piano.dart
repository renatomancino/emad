import '../modelli/piano.dart';

/// Regola dei limiti dei piani (RF_GAD_4, RF_GAD_7), in un solo punto lato app.
///
/// È la stessa regola di `privato.posti_occupati` nel database
/// (supabase/migrations/003_abbonamento.sql), che resta il controllo che fa
/// fede: l'app la usa per mostrare subito lo stato e i messaggi.
///   Free  = pazienti che hanno accettato un invito (anche archiviati) + inviti in attesa
///   Start = pazienti attivi + inviti in attesa, al massimo 5
///   Pro   = nessun limite

/// Opzioni proposte quando il limite è raggiunto (UC_GI_1, flusso 2.2).
enum OpzioneLimite { cambiaPiano, archiviaPaziente }

sealed class EsitoLimite {
  const EsitoLimite();
}

class Consentito extends EsitoLimite {
  const Consentito();
}

class LimiteRaggiunto extends EsitoLimite {
  const LimiteRaggiunto({required this.motivo, required this.opzioni});

  final String motivo;
  final List<OpzioneLimite> opzioni;
}

/// Posti occupati secondo il piano.
int postiOccupati({
  required PianoAbbonamento piano,
  required int pazientiAttivi,
  required int pazientiCollegatiTotali,
  int invitiInAttesa = 0,
}) {
  final base = piano == PianoAbbonamento.free
      ? pazientiCollegatiTotali
      : pazientiAttivi;
  return base + invitiInAttesa;
}

/// Opzioni proposte al limite: nel Free l'archiviazione non libera posti.
List<OpzioneLimite> opzioniAlLimite(PianoAbbonamento piano) =>
    piano == PianoAbbonamento.free
    ? const [OpzioneLimite.cambiaPiano]
    : const [OpzioneLimite.cambiaPiano, OpzioneLimite.archiviaPaziente];

String messaggioLimite(PianoAbbonamento piano) => switch (piano) {
  PianoAbbonamento.free =>
    'Hai raggiunto il limite del piano Free (1 paziente).',
  _ =>
    'Hai raggiunto il limite del piano ${piano.etichetta} '
        '(${piano.limite} pazienti attivi).',
};

/// "Può invitare?" (RF_GI_1): conta anche gli inviti in attesa.
EsitoLimite puoInvitare({
  required PianoAbbonamento piano,
  required int pazientiAttivi,
  required int pazientiCollegatiTotali,
  required int invitiInAttesa,
}) {
  final limite = piano.limite;
  if (limite == null) return const Consentito();
  final occupati = postiOccupati(
    piano: piano,
    pazientiAttivi: pazientiAttivi,
    pazientiCollegatiTotali: pazientiCollegatiTotali,
    invitiInAttesa: invitiInAttesa,
  );
  if (occupati < limite) return const Consentito();
  return LimiteRaggiunto(
    motivo: messaggioLimite(piano),
    opzioni: opzioniAlLimite(piano),
  );
}

/// "Può riattivare?" (RF_GI_5). Nel Free il paziente archiviato è già
/// contato: si riattiva solo se il totale non supera il limite. In Start
/// serve un posto attivo libero.
EsitoLimite puoRiattivare({
  required PianoAbbonamento piano,
  required int pazientiAttivi,
  required int pazientiCollegatiTotali,
}) {
  final limite = piano.limite;
  if (limite == null) return const Consentito();
  final ok = piano == PianoAbbonamento.free
      ? pazientiCollegatiTotali <= limite
      : pazientiAttivi < limite;
  if (ok) return const Consentito();
  return LimiteRaggiunto(
    motivo: messaggioLimite(piano),
    opzioni: opzioniAlLimite(piano),
  );
}

/// "Può passare a [nuovo]?" (UC_GAD_3): il declassamento è bloccato se i
/// posti occupati superano il nuovo limite.
EsitoLimite puoCambiarePiano({
  required PianoAbbonamento nuovo,
  required int pazientiAttivi,
  required int pazientiCollegatiTotali,
  required int invitiInAttesa,
}) {
  final limite = nuovo.limite;
  if (limite == null) return const Consentito();
  final occupati = postiOccupati(
    piano: nuovo,
    pazientiAttivi: pazientiAttivi,
    pazientiCollegatiTotali: pazientiCollegatiTotali,
    invitiInAttesa: invitiInAttesa,
  );
  if (occupati <= limite) return const Consentito();
  return LimiteRaggiunto(
    motivo:
        'Non puoi passare al piano ${nuovo.etichetta}: occupi $occupati '
        'posti e il limite è $limite.',
    opzioni: nuovo == PianoAbbonamento.free
        ? const []
        : const [OpzioneLimite.archiviaPaziente],
  );
}
