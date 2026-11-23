import 'package:flutter/foundation.dart';

import '../modelli/profilo.dart';

/// Accesso, registrazione e sessione (UC_GA_1, UC_GA_2, UC_GA_4).
///
/// È un [ChangeNotifier]: avvisa quando cambiano sessione o profilo, così il
/// router può reindirizzare in base al ruolo. Implementazioni:
/// - `SupabaseAuthRepository` (lib/data/supabase) per l'app vera;
/// - `AuthRepositoryFinto` (lib/data/finto) per test e per provare la
///   navigazione senza database.
abstract class AuthRepository extends ChangeNotifier {
  /// `true` mentre si legge la sessione salvata all'avvio.
  bool get inCaricamento;

  /// Profilo dell'utente autenticato, `null` se non c'è sessione.
  Profilo? get profilo;

  bool get autenticato => profilo != null;

  /// Ruolo dell'utente autenticato, `null` se non c'è sessione.
  Ruolo? get ruolo => profilo?.ruolo;

  /// Crea un account. Restituisce `true` se l'utente è già autenticato,
  /// `false` se deve prima confermare l'email.
  Future<bool> registra({
    required String email,
    required String password,
    required Ruolo ruolo,
    required String nome,
  });

  Future<void> accedi({required String email, required String password});

  Future<void> esci();

  /// Invia l'email per reimpostare la password. Il messaggio mostrato
  /// all'utente è lo stesso anche se l'email non esiste (UC_GA_4, passo 4).
  Future<void> recuperaPassword({required String email});
}

/// Errore di autenticazione con un messaggio in italiano per l'utente.
class ErroreAuth implements Exception {
  const ErroreAuth(this.messaggio, {this.codice});

  final String messaggio;

  /// Codice tecnico (es. `invalid_credentials`), utile nei test.
  final String? codice;

  @override
  String toString() => 'ErroreAuth($codice): $messaggio';
}
