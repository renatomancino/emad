import '../../domain/regole/validazione.dart';
import '../../domain/repository/collegamento_repository.dart';
import '../../domain/repository/pazienti_repository.dart';
import 'auth_repository_finto.dart';

/// Inviti in memoria, per test e ruolo simulato. Codici di prova:
/// `VALIDO01` (valido), `SCADUTO1`, `USATO001`, `REVOCATO1`; ogni altro
/// codice è "non valido".
class CollegamentoRepositoryFinto implements CollegamentoRepository {
  CollegamentoRepositoryFinto(this._auth);

  final AuthRepositoryFinto _auth;

  /// Codici accettati nella sessione (per i test).
  final List<String> accettati = [];

  /// Se impostato, `accetta` fallisce con questo errore (per i test).
  Object? erroreProssimaAccettazione;

  static ErroreOperazione _errore(String codice, String messaggio) =>
      ErroreOperazione(messaggio, codice: codice);

  @override
  Future<AnteprimaInvito> verifica(String codice) async {
    switch (Validazione.normalizzaCodice(codice)) {
      case 'VALIDO01':
        return AnteprimaInvito(
          nomeNutrizionista: 'Dott.ssa Giulia Rinaldi',
          scadenza: DateTime.now().add(const Duration(days: 5)),
        );
      case 'SCADUTO1':
        throw _errore(
          'CN011',
          'Il codice è scaduto: chiedi un nuovo invito al tuo nutrizionista.',
        );
      case 'USATO001':
        throw _errore(
          'CN012',
          'Questo codice è già stato usato: chiedi un nuovo invito al tuo nutrizionista.',
        );
      case 'REVOCATO1':
        throw _errore(
          'CN013',
          'Questo invito è stato annullato dal nutrizionista: chiedine uno nuovo.',
        );
      default:
        throw _errore(
          'CN010',
          'Codice non valido: controlla di averlo scritto bene.',
        );
    }
  }

  @override
  Future<void> accetta(String codice) async {
    final errore = erroreProssimaAccettazione;
    if (errore != null) {
      erroreProssimaAccettazione = null;
      throw errore;
    }
    await verifica(codice);
    accettati.add(Validazione.normalizzaCodice(codice));
    _auth.collega();
  }
}
