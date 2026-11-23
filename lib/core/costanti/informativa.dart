/// Informativa sul trattamento dei dati sanitari (GDPR art. 13 e 9, RF_GA_6,
/// RNF_L_1). Alla registrazione si salvano data e versione accettate
/// (`profili.consenso_dati_il`, `profili.versione_informativa`).
///
/// ATTENZIONE: testo di lavoro per il progetto d'esame. Prima di un uso reale
/// va rivisto da un consulente legale (titolare del trattamento, recapiti,
/// tempi di conservazione). Se il testo cambia, aumenta [versione].
abstract final class Informativa {
  static const versione = '1.0';

  static const titolo = 'Informativa sul trattamento dei dati';

  /// Frase accanto alla casella di consenso esplicito.
  static const testoConsenso =
      'Ho letto l\'informativa e acconsento al trattamento dei miei dati '
      'relativi alla salute per usare Cenato.';

  static const spiegazioneConsensoObbligatorio =
      'Il consenso è necessario: Cenato tratta dati relativi alla salute '
      '(piani alimentari, pasti, peso) e senza il tuo consenso esplicito non '
      'possiamo creare l\'account.';

  /// Sezioni mostrate nella schermata del consenso: (titolo, testo).
  static const sezioni = <(String, String)>[
    (
      'Chi tratta i dati',
      'I dati sono trattati dal gruppo di sviluppo di Cenato (progetto '
          'universitario) e conservati su un servizio cloud ospitato in '
          'Unione Europea.',
    ),
    (
      'Quali dati',
      'Nome, email, ruolo; per i pazienti anche altezza, data di nascita, '
          'obiettivo, peso, check-in dei pasti, commenti del nutrizionista e '
          'visite. Sono dati relativi alla salute (art. 9 GDPR).',
    ),
    (
      'Perché',
      'Per permettere al nutrizionista di seguire il paziente e al paziente '
          'di consultare il proprio piano. Non vendiamo i dati, non li '
          'usiamo per pubblicità e non li usiamo per altri scopi.',
    ),
    (
      'Chi li vede',
      'Il paziente vede solo i propri dati. Il nutrizionista vede solo quelli '
          'dei pazienti che ha invitato e che hanno accettato il collegamento.',
    ),
    (
      'I tuoi diritti',
      'Puoi chiedere in ogni momento la cancellazione dell\'account e dei '
          'dati dalla sezione Profilo. Puoi interrompere il collegamento con '
          'il tuo nutrizionista. Puoi revocare il consenso eliminando '
          'l\'account.',
    ),
    (
      'Avvertenza',
      'Cenato non fornisce diagnosi né consigli medici e non sostituisce il '
          'professionista. L\'indicatore di aderenza è solo un segnale di '
          'attenzione.',
    ),
  ];
}
