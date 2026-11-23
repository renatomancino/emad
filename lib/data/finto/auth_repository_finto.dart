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
    : _profilo = ruoloIniziale == null ? null : _profiloFinto(ruoloIniziale);

  Profilo? _profilo;

  static Profilo _profiloFinto(Ruolo ruolo) => Profilo(
    id: 'finto-${ruolo.name}',
    ruolo: ruolo,
    nome: ruolo == Ruolo.nutrizionista ? 'Dott.ssa Giulia' : 'Marco',
  );

  @override
  bool get inCaricamento => false;

  @override
  Profilo? get profilo => _profilo;

  /// Simula l'accesso con un ruolo (usato dai test e dalla prova).
  void simulaAccesso(Ruolo ruolo) {
    _profilo = _profiloFinto(ruolo);
    notifyListeners();
  }

  @override
  Future<bool> registra({
    required String email,
    required String password,
    required Ruolo ruolo,
    required String nome,
  }) async {
    _profilo = Profilo(id: 'finto-$email', ruolo: ruolo, nome: nome);
    notifyListeners();
    return true;
  }

  @override
  Future<void> accedi({required String email, required String password}) async {
    final ruolo = email.startsWith('nut')
        ? Ruolo.nutrizionista
        : Ruolo.paziente;
    simulaAccesso(ruolo);
  }

  @override
  Future<void> esci() async {
    _profilo = null;
    notifyListeners();
  }

  @override
  Future<void> recuperaPassword({required String email}) async {}
}
