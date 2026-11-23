import '../../domain/modelli/dati_profilo.dart';
import '../../domain/repository/profilo_repository.dart';
import 'auth_repository_finto.dart';

/// Profilo in memoria, per test e ruolo simulato.
class ProfiloRepositoryFinto extends ProfiloRepository {
  ProfiloRepositoryFinto(this._auth)
    : _dati = DatiProfilo(nome: _auth.profilo?.nome ?? 'Utente di prova');

  final AuthRepositoryFinto _auth;
  DatiProfilo _dati;

  /// Se impostato, la prossima operazione fallisce con questo errore.
  Object? erroreProssimaOperazione;

  /// `true` dopo `eliminaAccount` (per i test).
  bool eliminato = false;

  void _lanciaSeImpostato() {
    final e = erroreProssimaOperazione;
    if (e != null) {
      erroreProssimaOperazione = null;
      throw e;
    }
  }

  @override
  Future<DatiProfilo> leggi() async => _dati;

  @override
  Future<void> salva(DatiProfilo dati) async {
    _lanciaSeImpostato();
    _dati = dati;
    _auth.rinomina(dati.nome);
    notifyListeners();
  }

  @override
  Future<void> eliminaAccount() async {
    _lanciaSeImpostato();
    eliminato = true;
    await _auth.chiudiSessioneLocale();
  }
}
