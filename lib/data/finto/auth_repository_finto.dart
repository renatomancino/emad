import '../../domain/modelli/profilo.dart';
import '../../domain/repository/auth_repository.dart';

/// [AuthRepository] in memoria, senza Supabase.
///
/// Serve ai test e a provare la navigazione con un ruolo simulato
/// (scheda "Tema, navigazione e schermate base"): avvia l'app con
/// `flutter run --dart-define=CENATO_RUOLO_FINTO=paziente` oppure
/// `=nutrizionista`. Non salva nulla e accetta qualunque password.
class AuthRepositoryFinto extends AuthRepository {
  AuthRepositoryFinto({Ruolo? ruoloIniziale})
    : _profilo = ruoloIniziale == null ? null : _profiloFinto(ruoloIniziale),
      _collegato = ruoloIniziale != null;

  Profilo? _profilo;
  bool _collegato;
  bool _primoAccesso = false;
  bool _inRecupero = false;
  String? _codicePendente;

  /// Ultimi dati usati alla registrazione (per i test).
  String? ultimaVersioneInformativa;
  String? ultimaEmail;

  /// Se è `false`, `registra` simula "Confirm email" attivo (nessuna sessione).
  bool sessioneDopoRegistrazione = true;

  /// Errore da lanciare alla prossima registrazione o accesso (per i test).
  ErroreAuth? erroreProssimaOperazione;

  /// Email per cui la richiesta di reset è stata fatta (per i test).
  final List<String> richiesteReset = [];

  static Profilo _profiloFinto(Ruolo ruolo) => Profilo(
    id: 'finto-${ruolo.name}',
    ruolo: ruolo,
    nome: ruolo == Ruolo.nutrizionista ? 'Dott.ssa Giulia' : 'Marco',
  );

  @override
  bool get inCaricamento => false;

  @override
  Profilo? get profilo => _profilo;

  @override
  bool get collegato => _collegato;

  @override
  String? get codiceInvitoPendente => _codicePendente;

  @override
  bool get primoAccesso => _primoAccesso;

  @override
  bool get inRecuperoPassword => _inRecupero;

  /// Simula l'accesso con un ruolo (usato dai test e dalla prova).
  void simulaAccesso(Ruolo ruolo, {bool collegato = true}) {
    _profilo = _profiloFinto(ruolo);
    _collegato = collegato;
    notifyListeners();
  }

  /// Simula l'apertura del link di reimpostazione password.
  void simulaRecuperoPassword() {
    _profilo ??= _profiloFinto(Ruolo.paziente);
    _inRecupero = true;
    notifyListeners();
  }

  void _lanciaSeImpostato() {
    final e = erroreProssimaOperazione;
    if (e != null) {
      erroreProssimaOperazione = null;
      throw e;
    }
  }

  @override
  Future<bool> registra({
    required String email,
    required String password,
    required Ruolo ruolo,
    required String nome,
    required String versioneInformativa,
    String? codiceInvito,
  }) async {
    _lanciaSeImpostato();
    ultimaVersioneInformativa = versioneInformativa;
    ultimaEmail = email;
    if (!sessioneDopoRegistrazione) return false;
    _primoAccesso = ruolo == Ruolo.nutrizionista;
    _codicePendente = codiceInvito;
    _collegato = ruolo == Ruolo.nutrizionista;
    _profilo = Profilo(id: 'finto-$email', ruolo: ruolo, nome: nome);
    notifyListeners();
    return true;
  }

  @override
  Future<void> accedi({required String email, required String password}) async {
    _lanciaSeImpostato();
    final ruolo = email.startsWith('nut')
        ? Ruolo.nutrizionista
        : Ruolo.paziente;
    simulaAccesso(ruolo);
  }

  @override
  Future<void> esci() async {
    _profilo = null;
    _collegato = false;
    _primoAccesso = false;
    _inRecupero = false;
    notifyListeners();
  }

  @override
  Future<void> recuperaPassword({required String email}) async {
    _lanciaSeImpostato();
    richiesteReset.add(email);
  }

  @override
  Future<void> impostaNuovaPassword(String password) async {
    _lanciaSeImpostato();
    _inRecupero = false;
    notifyListeners();
  }

  @override
  Future<void> aggiornaCollegamento() async {
    // Nel finto l'accettazione imposta il collegamento tramite [collega].
    notifyListeners();
  }

  /// Chiamato dal repository finto dei collegamenti dopo l'accettazione.
  void collega() {
    _collegato = true;
    _codicePendente = null;
    notifyListeners();
  }

  /// Simula lo scollegamento del paziente.
  void scollega() {
    _collegato = false;
    notifyListeners();
  }

  /// Cambia il nome del profilo simulato (dopo la modifica del profilo).
  void rinomina(String nome) {
    final p = _profilo;
    if (p == null) return;
    _profilo = Profilo(id: p.id, ruolo: p.ruolo, nome: nome);
    notifyListeners();
  }

  @override
  Future<void> ricaricaProfilo() async => notifyListeners();

  @override
  Future<void> chiudiSessioneLocale() => esci();

  @override
  void concludiOnboarding() {
    _primoAccesso = false;
    notifyListeners();
  }
}
