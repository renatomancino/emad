import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/modelli/profilo.dart';
import '../../domain/repository/auth_repository.dart';

/// [AuthRepository] su Supabase Auth (email e password) e tabella `profili`.
///
/// Il ruolo, il nome, il consenso e il codice di invito sono passati nei
/// metadati della registrazione: il trigger `crea_profilo_da_auth`
/// (supabase/migrations/000 e 004) crea il profilo, rifiuta la registrazione
/// senza consenso e il ruolo non si può più cambiare.
class SupabaseAuthRepository extends AuthRepository {
  SupabaseAuthRepository(this._client) {
    _sottoscrizione = _client.auth.onAuthStateChange.listen((evento) {
      if (evento.event == AuthChangeEvent.passwordRecovery) {
        _inRecuperoPassword = true;
      }
      _aggiornaDaSessione(evento.session);
    }, onError: (Object _) => _impostaProfilo(null));
    _aggiornaDaSessione(_client.auth.currentSession);
  }

  /// Rientro dal link di reimpostazione password: va inserito tra i Redirect
  /// URLs di Supabase (docs/supabase.md) ed è gestito da AndroidManifest.xml.
  static const urlRitornoApp = 'it.unisa.cenato://login-callback';

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _sottoscrizione;

  Profilo? _profilo;
  bool _inCaricamento = true;
  bool _collegato = false;
  bool _primoAccesso = false;
  bool _inRecuperoPassword = false;
  String? _codicePendente;

  @override
  bool get inCaricamento => _inCaricamento;

  @override
  Profilo? get profilo => _profilo;

  @override
  bool get collegato => _collegato;

  @override
  String? get codiceInvitoPendente => _codicePendente;

  @override
  bool get primoAccesso => _primoAccesso;

  @override
  bool get inRecuperoPassword => _inRecuperoPassword;

  @override
  Future<bool> registra({
    required String email,
    required String password,
    required Ruolo ruolo,
    required String nome,
    required String versioneInformativa,
    String? codiceInvito,
  }) async {
    // Impostato prima: il router lo legge appena arriva la sessione.
    _primoAccesso = ruolo == Ruolo.nutrizionista;
    final AuthResponse risposta;
    try {
      risposta = await _esegui(
        () => _client.auth.signUp(
          email: email.trim(),
          password: password,
          emailRedirectTo: kIsWeb ? null : urlRitornoApp,
          data: {
            'ruolo': ruolo.valoreDb,
            'nome': nome.trim(),
            'consenso_dati': true,
            'versione_informativa': versioneInformativa,
            if (codiceInvito != null && codiceInvito.isNotEmpty)
              'codice_invito': codiceInvito,
          },
        ),
      );
    } catch (_) {
      _primoAccesso = false;
      rethrow;
    }

    // Con "Confirm email" attivo Supabase non segnala l'email già registrata:
    // restituisce un utente senza identità.
    if (risposta.user?.identities?.isEmpty ?? false) {
      _primoAccesso = false;
      throw const ErroreAuth(
        'Esiste già un account con questa email.',
        codice: 'user_already_exists',
      );
    }
    if (risposta.session == null) {
      _primoAccesso = false;
      return false;
    }
    await _aggiornaDaSessione(risposta.session);
    return true;
  }

  @override
  Future<void> accedi({required String email, required String password}) async {
    _primoAccesso = false;
    final risposta = await _esegui(
      () => _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      ),
    );
    await _aggiornaDaSessione(risposta.session);
    if (_profilo == null) {
      throw const ErroreAuth(
        'Accesso riuscito, ma il profilo non è stato trovato. Riprova.',
        codice: 'profilo_assente',
      );
    }
  }

  @override
  Future<void> esci() async {
    await _esegui(() => _client.auth.signOut());
    _primoAccesso = false;
    _inRecuperoPassword = false;
    _impostaProfilo(null);
  }

  @override
  Future<void> recuperaPassword({required String email}) async {
    await _esegui(
      () => _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : urlRitornoApp,
      ),
    );
  }

  @override
  Future<void> impostaNuovaPassword(String password) async {
    await _esegui(
      () => _client.auth.updateUser(UserAttributes(password: password)),
    );
    _inRecuperoPassword = false;
    notifyListeners();
  }

  @override
  Future<void> aggiornaCollegamento() async {
    final sessione = _client.auth.currentSession;
    if (sessione == null || _profilo?.ruolo != Ruolo.paziente) return;
    _collegato = await _leggiCollegamento(sessione.user.id);
    if (_collegato && _codicePendente != null) {
      _codicePendente = null;
      // Il codice è stato usato: lo si toglie dai metadati (best effort).
      try {
        await _client.auth.updateUser(
          UserAttributes(data: {'codice_invito': null}),
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  @override
  Future<void> ricaricaProfilo() =>
      _aggiornaDaSessione(_client.auth.currentSession);

  @override
  Future<void> chiudiSessioneLocale() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // L'utente non esiste più sul server: basta svuotare lo stato locale.
    }
    _primoAccesso = false;
    _inRecuperoPassword = false;
    _impostaProfilo(null);
  }

  @override
  void concludiOnboarding() {
    _primoAccesso = false;
    notifyListeners();
  }

  Future<bool> _leggiCollegamento(String utenteId) async {
    final righe = await _client
        .from('pazienti')
        .select('id')
        .eq('utente_id', utenteId)
        .eq('stato', 'attivo')
        .limit(1);
    return righe.isNotEmpty;
  }

  Future<void> _aggiornaDaSessione(Session? sessione) async {
    if (sessione == null) {
      _collegato = false;
      _codicePendente = null;
      _impostaProfilo(null);
      return;
    }
    try {
      final riga = await _client
          .from('profili')
          .select('id, ruolo, nome')
          .eq('id', sessione.user.id)
          .maybeSingle();
      final profilo = riga == null ? null : Profilo.daRiga(riga);
      _collegato = profilo?.ruolo == Ruolo.paziente
          ? await _leggiCollegamento(sessione.user.id)
          : profilo != null;
      final pendente = sessione.user.userMetadata?['codice_invito'];
      _codicePendente = pendente is String && pendente.isNotEmpty
          ? pendente
          : null;
      _impostaProfilo(profilo);
    } catch (e) {
      // Nessun dato personale nei log: solo il tipo di errore.
      debugPrint('Lettura del profilo non riuscita: ${e.runtimeType}');
      _impostaProfilo(null);
    }
  }

  void _impostaProfilo(Profilo? nuovo) {
    _profilo = nuovo;
    _inCaricamento = false;
    notifyListeners();
  }

  /// Esegue una chiamata ad Auth e traduce gli errori in [ErroreAuth].
  Future<T> _esegui<T>(Future<T> Function() chiamata) async {
    try {
      return await chiamata();
    } on AuthException catch (e) {
      throw ErroreAuth(messaggioPer(e.code, e.statusCode), codice: e.code);
    } on ErroreAuth {
      rethrow;
    } catch (e) {
      debugPrint('Errore di autenticazione: ${e.runtimeType}');
      throw const ErroreAuth(
        'Connessione non riuscita. Controlla la rete e riprova.',
        codice: 'rete',
      );
    }
  }

  /// Messaggio in italiano per un codice di errore di Supabase Auth.
  @visibleForTesting
  static String messaggioPer(String? codice, [String? stato]) {
    switch (codice) {
      case 'invalid_credentials':
        return 'Email o password non corretti.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Esiste già un account con questa email.';
      case 'email_not_confirmed':
        return 'Devi confermare l\'email prima di accedere: controlla la posta.';
      case 'weak_password':
        return 'Password troppo debole: usa almeno 8 caratteri, con lettere e numeri.';
      case 'same_password':
        return 'La nuova password deve essere diversa da quella attuale.';
      case 'validation_failed':
      case 'email_address_invalid':
        return 'Questa email non è valida.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Troppi tentativi ravvicinati. Attendi qualche minuto e riprova.';
      case 'signup_disabled':
        return 'La registrazione è momentaneamente disattivata.';
      case 'session_not_found':
      case 'bad_jwt':
        return 'Il link non è più valido: richiedine uno nuovo.';
    }
    if (stato == null) {
      return 'Connessione non riuscita. Controlla la rete e riprova.';
    }
    return 'Operazione non riuscita. Riprova tra poco.';
  }

  @override
  void dispose() {
    _sottoscrizione.cancel();
    super.dispose();
  }
}
