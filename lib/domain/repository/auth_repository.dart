import 'package:flutter/foundation.dart';

import '../modelli/profilo.dart';

/// Accesso, registrazione e sessione (UC_GA_1, UC_GA_2, UC_GA_4).
///
/// È un [ChangeNotifier]: avvisa quando cambiano sessione, profilo o
/// collegamento, così il router può reindirizzare. Implementazioni:
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

  /// Paziente collegato a un nutrizionista (stato Attivo). Per il
  /// nutrizionista è sempre `true`. Chi non è collegato vede la schermata
  /// dove inserire il codice di invito (UC_GI_2).
  bool get collegato;

  /// Codice di invito scritto alla registrazione e non ancora usato (rimasto
  /// in attesa della conferma email).
  String? get codiceInvitoPendente;

  /// `true` subito dopo la registrazione di un nutrizionista: porta al passo
  /// "disponibilità" (UC_GA_1, passo 8).
  bool get primoAccesso;

  /// `true` dopo l'apertura del link di reimpostazione password (UC_GA_4).
  bool get inRecuperoPassword;

  /// Crea un account con il consenso già dato (`versioneInformativa` è la
  /// versione accettata). Per un paziente [codiceInvito] viene ricordato fino
  /// al collegamento. Restituisce `true` se l'utente è già autenticato,
  /// `false` se deve prima confermare l'email.
  Future<bool> registra({
    required String email,
    required String password,
    required Ruolo ruolo,
    required String nome,
    required String versioneInformativa,
    String? codiceInvito,
  });

  Future<void> accedi({required String email, required String password});

  Future<void> esci();

  /// Invia l'email per reimpostare la password. Il messaggio mostrato
  /// all'utente è lo stesso anche se l'email non esiste (UC_GA_4, passo 4).
  Future<void> recuperaPassword({required String email});

  /// Imposta la nuova password dopo il rientro dal link (UC_GA_4, passo 5).
  Future<void> impostaNuovaPassword(String password);

  /// Rilegge se il paziente è collegato (dopo accettazione o scollegamento).
  Future<void> aggiornaCollegamento();

  /// Rilegge il profilo (es. dopo la modifica del nome).
  Future<void> ricaricaProfilo();

  /// Chiude la sessione sul dispositivo senza chiamare il server: serve dopo
  /// l'eliminazione dell'account, quando la sessione non esiste più.
  Future<void> chiudiSessioneLocale();

  /// Chiude il passo "disponibilità" del primo accesso del nutrizionista.
  void concludiOnboarding();
}

/// Errore di autenticazione con un messaggio in italiano per l'utente.
class ErroreAuth implements Exception {
  const ErroreAuth(this.messaggio, {this.codice});

  final String messaggio;

  /// Codice tecnico (es. `invalid_credentials`), utile nei test e per
  /// mostrare l'errore sul campo giusto.
  final String? codice;

  /// L'errore riguarda il campo email.
  bool get riguardaEmail => const {
    'user_already_exists',
    'email_exists',
    'email_address_invalid',
    'validation_failed',
  }.contains(codice);

  bool get riguardaPassword => codice == 'weak_password';

  /// Errore di rete: si può riprovare senza perdere i dati inseriti.
  bool get eRete => codice == 'rete';

  @override
  String toString() => 'ErroreAuth($codice): $messaggio';
}
