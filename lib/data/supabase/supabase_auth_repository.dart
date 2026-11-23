import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/modelli/profilo.dart';
import '../../domain/repository/auth_repository.dart';

/// [AuthRepository] su Supabase Auth (email e password) e tabella `profili`.
///
/// Il ruolo è passato nei metadati della registrazione: il trigger
/// `crea_profilo_da_auth` (supabase/migrations/000_profili.sql) crea il
/// profilo, e il ruolo non si può più cambiare.
class SupabaseAuthRepository extends AuthRepository {
  SupabaseAuthRepository(this._client) {
    _sottoscrizione = _client.auth.onAuthStateChange.listen(
      (evento) => _aggiornaDaSessione(evento.session),
      onError: (Object _) => _impostaProfilo(null),
    );
    _aggiornaDaSessione(_client.auth.currentSession);
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _sottoscrizione;

  Profilo? _profilo;
  bool _inCaricamento = true;

  @override
  bool get inCaricamento => _inCaricamento;

  @override
  Profilo? get profilo => _profilo;

  @override
  Future<bool> registra({
    required String email,
    required String password,
    required Ruolo ruolo,
    required String nome,
  }) async {
    final risposta = await _esegui(
      () => _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'ruolo': ruolo.valoreDb, 'nome': nome.trim()},
      ),
    );
    if (risposta.session == null) return false;
    await _aggiornaDaSessione(risposta.session);
    return true;
  }

  @override
  Future<void> accedi({required String email, required String password}) async {
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
    _impostaProfilo(null);
  }

  @override
  Future<void> recuperaPassword({required String email}) async {
    await _esegui(() => _client.auth.resetPasswordForEmail(email.trim()));
  }

  Future<void> _aggiornaDaSessione(Session? sessione) async {
    if (sessione == null) {
      _impostaProfilo(null);
      return;
    }
    try {
      final riga = await _client
          .from('profili')
          .select('id, ruolo, nome')
          .eq('id', sessione.user.id)
          .maybeSingle();
      _impostaProfilo(riga == null ? null : Profilo.daRiga(riga));
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
        return 'Email o password non corretti. Se non ricordi la password '
            'usa "Password dimenticata".';
      case 'user_already_exists':
      case 'email_exists':
        return 'Esiste già un account con questa email.';
      case 'email_not_confirmed':
        return 'Devi confermare l\'email prima di accedere: controlla la posta.';
      case 'weak_password':
        return 'Password troppo debole: usa almeno 8 caratteri.';
      case 'validation_failed':
      case 'email_address_invalid':
        return 'Email non valida.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Troppi tentativi ravvicinati. Attendi qualche minuto e riprova.';
      case 'signup_disabled':
        return 'La registrazione è momentaneamente disattivata.';
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
