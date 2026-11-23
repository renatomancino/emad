/// Validazione dei campi di registrazione e accesso (UC_GA_1, UC_GA_2).
/// Ogni funzione restituisce il messaggio d'errore da mostrare sul campo,
/// oppure `null` se il valore va bene.
abstract final class Validazione {
  /// Lunghezza minima della password (anche in docs/supabase.md).
  static const lunghezzaMinimaPassword = 8;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
  static final _codice = RegExp(r'^[A-Z0-9]{6,12}$');

  static String? nome(String valore) {
    final v = valore.trim();
    if (v.isEmpty) return 'Inserisci il tuo nome.';
    if (v.length < 2) return 'Il nome è troppo corto.';
    if (v.length > 100) {
      return 'Il nome è troppo lungo (massimo 100 caratteri).';
    }
    return null;
  }

  static String? email(String valore) {
    final v = valore.trim();
    if (v.isEmpty) return 'Inserisci la tua email.';
    if (!_email.hasMatch(v)) return 'Questa email non sembra valida.';
    return null;
  }

  /// Almeno 8 caratteri, con almeno una lettera e un numero.
  static String? password(String valore) {
    if (valore.isEmpty) return 'Scegli una password.';
    if (valore.length < lunghezzaMinimaPassword) {
      return 'Usa almeno $lunghezzaMinimaPassword caratteri.';
    }
    if (!valore.contains(RegExp(r'[A-Za-z]')) ||
        !valore.contains(RegExp(r'[0-9]'))) {
      return 'Usa almeno una lettera e un numero.';
    }
    return null;
  }

  static String? conferma(String password, String conferma) {
    if (conferma.isEmpty) return 'Ripeti la password.';
    if (conferma != password) return 'Le due password non coincidono.';
    return null;
  }

  /// Il codice si scrive in qualunque modo (maiuscole, spazi): si normalizza.
  static String normalizzaCodice(String valore) =>
      valore.replaceAll(RegExp(r'\s'), '').toUpperCase();

  static String? codiceInvito(String valore) {
    final v = normalizzaCodice(valore);
    if (v.isEmpty) {
      return 'Inserisci il codice che ti ha dato il nutrizionista.';
    }
    if (!_codice.hasMatch(v)) {
      return 'Il codice ha da 6 a 12 tra lettere e numeri: controlla di averlo '
          'scritto bene.';
    }
    return null;
  }

  static String? altezzaCm(String valore) {
    final v = valore.trim();
    if (v.isEmpty) return null; // facoltativa
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < 50 || n > 250) {
      return 'Inserisci un\'altezza in cm tra 50 e 250.';
    }
    return null;
  }
}
