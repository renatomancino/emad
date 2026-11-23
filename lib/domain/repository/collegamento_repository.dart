/// Anteprima di un invito valido: "Sei stato invitato da NOME" (UC_GI_2,
/// passo 3).
class AnteprimaInvito {
  const AnteprimaInvito({
    required this.nomeNutrizionista,
    required this.scadenza,
  });

  final String nomeNutrizionista;
  final DateTime scadenza;
}

/// Verifica e accettazione del codice di invito da parte del paziente
/// (UC_GI_2, RF_GI_2). Le due operazioni lanciano `ErroreOperazione` con
/// `codice` CN010 (non valido), CN011 (scaduto), CN012 (già usato),
/// CN013 (revocato), CN001 (il nutrizionista ha raggiunto il limite) o
/// CN008 (già collegato).
abstract class CollegamentoRepository {
  /// Controlla il codice SENZA bisogno di essere registrati.
  Future<AnteprimaInvito> verifica(String codice);

  /// Collega il paziente autenticato al nutrizionista (RPC `accetta_invito`).
  Future<void> accetta(String codice);
}
