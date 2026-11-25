import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/informativa.dart';
import '../../core/dipendenze.dart';
import '../../core/router/rotte.dart';
import '../../core/tema/tema.dart';
import '../../domain/modelli/profilo.dart';
import '../../domain/regole/validazione.dart';
import '../../domain/repository/auth_repository.dart';
import '../../domain/repository/collegamento_repository.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../comuni/componenti.dart';
import '../comuni/controlli.dart';

/// Registrazione in tre schermate per entrambi i ruoli (UC_GA_1, RNF_U_4):
/// 1. scelta del ruolo, 2. modulo (per il paziente anche il codice di
/// invito, verificato subito), 3. informativa e consenso esplicito GDPR
/// art. 9 (RF_GA_6). Senza consenso l'account non si crea.
class RegistrazionePage extends StatefulWidget {
  const RegistrazionePage({super.key, required this.dip});

  final Dipendenze dip;

  @override
  State<RegistrazionePage> createState() => _RegistrazionePageState();
}

class _RegistrazionePageState extends State<RegistrazionePage> {
  static const _passi = 3;

  int _passo = 0;
  Ruolo? _ruolo;

  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _conferma = TextEditingController();
  final _codice = TextEditingController();

  final Map<String, String?> _errori = {};
  AnteprimaInvito? _anteprima;
  String? _codiceVerificato;

  bool _consenso = false;
  bool _consensoMancante = false;
  bool _inCorso = false;
  String? _erroreGenerale;
  bool _erroreDiRete = false;
  bool _daConfermare = false;

  AuthRepository get _auth => widget.dip.auth;
  bool get _paziente => _ruolo == Ruolo.paziente;

  @override
  void dispose() {
    for (final c in [_nome, _email, _password, _conferma, _codice]) {
      c.dispose();
    }
    super.dispose();
  }

  void _indietro() {
    if (_passo == 0) {
      context.go(Rotte.accesso);
    } else {
      setState(() {
        _passo--;
        _erroreGenerale = null;
      });
    }
  }

  void _scegliRuolo(Ruolo ruolo) {
    setState(() {
      if (_ruolo != ruolo) {
        _anteprima = null;
        _codiceVerificato = null;
      }
      _ruolo = ruolo;
      _passo = 1;
    });
  }

  /// Passo 2 → 3: controlla i campi e, per il paziente, il codice di invito.
  Future<void> _continuaDalModulo() async {
    final errori = <String, String?>{
      'nome': Validazione.nome(_nome.text),
      'email': Validazione.email(_email.text),
      'password': Validazione.password(_password.text),
      'conferma': Validazione.conferma(_password.text, _conferma.text),
      if (_paziente) 'codice': Validazione.codiceInvito(_codice.text),
    };
    setState(() {
      _errori
        ..clear()
        ..addAll(errori);
      _erroreGenerale = null;
    });
    if (errori.values.any((e) => e != null)) return;

    if (_paziente) {
      final codice = Validazione.normalizzaCodice(_codice.text);
      if (_anteprima == null || _codiceVerificato != codice) {
        setState(() => _inCorso = true);
        try {
          final anteprima = await widget.dip.collegamento.verifica(codice);
          if (!mounted) return;
          setState(() {
            _anteprima = anteprima;
            _codiceVerificato = codice;
          });
        } on ErroreOperazione catch (e) {
          if (!mounted) return;
          setState(() {
            if (e.codice == 'rete') {
              _erroreGenerale = e.messaggio;
              _erroreDiRete = true;
            } else {
              _errori['codice'] = e.messaggio;
            }
          });
          return;
        } finally {
          if (mounted) setState(() => _inCorso = false);
        }
      }
    }
    if (mounted) setState(() => _passo = 2);
  }

  /// Passo 3: consenso e creazione dell'account.
  Future<void> _creaAccount() async {
    if (!_consenso) {
      setState(() => _consensoMancante = true);
      return;
    }
    setState(() {
      _inCorso = true;
      _erroreGenerale = null;
      _erroreDiRete = false;
    });
    try {
      final autenticato = await _auth.registra(
        email: _email.text,
        password: _password.text,
        ruolo: _ruolo!,
        nome: _nome.text,
        versioneInformativa: Informativa.versione,
        codiceInvito: _paziente
            ? Validazione.normalizzaCodice(_codice.text)
            : null,
      );
      // Con la sessione attiva il router cambia schermata da solo.
      if (!autenticato && mounted) setState(() => _daConfermare = true);
    } on ErroreAuth catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.riguardaEmail) {
          _errori['email'] = e.messaggio;
          _passo = 1;
        } else if (e.riguardaPassword) {
          _errori['password'] = e.messaggio;
          _passo = 1;
        } else {
          _erroreGenerale = e.messaggio;
          _erroreDiRete = e.eRete;
        }
      });
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_daConfermare) {
      return _ControllaEmail(email: _email.text.trim(), anteprima: _anteprima);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (esito, _) {
        if (!esito) _indietro();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registrazione'),
          leading: IconButton(
            tooltip: 'Indietro',
            icon: const Icon(Icons.arrow_back),
            onPressed: _indietro,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Passo ${_passo + 1} di $_passi',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_passo + 1) / _passi,
                    backgroundColor: context.colori.primarioTonale,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 20),
                  switch (_passo) {
                    0 => _passoRuolo(),
                    1 => _passoModulo(),
                    _ => _passoConsenso(),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- passo 1
  Widget _passoRuolo() {
    final testo = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Come userai Cenato?', style: testo.headlineSmall),
        const SizedBox(height: 16),
        _SchedaRuolo(
          chiave: const Key('ruolo-nutrizionista'),
          icona: Icons.medical_services_outlined,
          titolo: 'Sono un nutrizionista',
          descrizione: 'Segui i tuoi pazienti, componi i piani e vedi chi ha bisogno di attenzione.',
          selezionato: _ruolo == Ruolo.nutrizionista,
          onTap: () => _scegliRuolo(Ruolo.nutrizionista),
        ),
        const SizedBox(height: 12),
        _SchedaRuolo(
          chiave: const Key('ruolo-paziente'),
          icona: Icons.person_outline,
          titolo: 'Sono un paziente',
          descrizione: 'Il tuo nutrizionista ti ha dato un codice di invito: ti serve per iniziare.',
          selezionato: _ruolo == Ruolo.paziente,
          onTap: () => _scegliRuolo(Ruolo.paziente),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- passo 2
  void _cambiato(String campo) {
    if (_errori[campo] != null || _erroreGenerale != null) {
      setState(() {
        _errori[campo] = null;
        _erroreGenerale = null;
      });
    }
  }

  Widget _passoModulo() {
    final testo = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('I tuoi dati', style: testo.headlineSmall),
        const SizedBox(height: 16),
        if (_paziente) ...[
          CampoTesto(
            controller: _codice,
            etichetta: 'Codice di invito',
            errore: _errori['codice'],
            maiuscolo: true,
            azioneTastiera: TextInputAction.next,
            aiuto: 'Te lo ha dato il tuo nutrizionista.',
            onCambiato: (_) {
              _cambiato('codice');
              if (_anteprima != null &&
                  _codiceVerificato !=
                      Validazione.normalizzaCodice(_codice.text)) {
                setState(() => _anteprima = null);
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        CampoTesto(
          controller: _nome,
          etichetta: 'Nome e cognome',
          errore: _errori['nome'],
          suggerimentiAutofill: const [AutofillHints.name],
          azioneTastiera: TextInputAction.next,
          onCambiato: (_) => _cambiato('nome'),
        ),
        const SizedBox(height: 12),
        CampoTesto(
          controller: _email,
          etichetta: 'Email',
          errore: _errori['email'],
          tastiera: TextInputType.emailAddress,
          suggerimentiAutofill: const [AutofillHints.email],
          azioneTastiera: TextInputAction.next,
          onCambiato: (_) => _cambiato('email'),
        ),
        const SizedBox(height: 12),
        CampoPassword(
          controller: _password,
          nuova: true,
          errore: _errori['password'],
          aiuto:
              'Almeno ${Validazione.lunghezzaMinimaPassword} caratteri, con lettere e numeri.',
          azioneTastiera: TextInputAction.next,
          onCambiato: (_) => _cambiato('password'),
        ),
        const SizedBox(height: 12),
        CampoPassword(
          controller: _conferma,
          nuova: true,
          etichetta: 'Ripeti la password',
          errore: _errori['conferma'],
          azioneTastiera: TextInputAction.done,
          onInvio: _continuaDalModulo,
          onCambiato: (_) => _cambiato('conferma'),
        ),
        if (_anteprima != null) ...[
          const SizedBox(height: 12),
          BannerInvito(nomeNutrizionista: _anteprima!.nomeNutrizionista),
        ],
        if (_erroreGenerale != null) ...[
          const SizedBox(height: 12),
          MessaggioErrore(
            messaggio: _erroreGenerale!,
            onRiprova: _erroreDiRete ? _continuaDalModulo : null,
          ),
        ],
        const SizedBox(height: 20),
        PulsantePrimario(
          etichetta: 'Continua',
          onPressed: _continuaDalModulo,
          inCorso: _inCorso,
        ),
      ],
    );
  }

  // --------------------------------------------------------------- passo 3
  Widget _passoConsenso() {
    final testo = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(Informativa.titolo, style: testo.headlineSmall),
        Text(
          'Versione ${Informativa.versione}',
          style: testo.bodySmall?.copyWith(
            color: context.colori.testoSecondario,
          ),
        ),
        const SizedBox(height: 12),
        if (_paziente && _anteprima != null) ...[
          BannerInvito(nomeNutrizionista: _anteprima!.nomeNutrizionista),
          const SizedBox(height: 12),
        ],
        SchedaSezione(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (titolo, corpo) in Informativa.sezioni) ...[
                Text(titolo, style: testo.titleSmall),
                const SizedBox(height: 2),
                Text(corpo),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const Key('casella-consenso'),
          value: _consenso,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(Informativa.testoConsenso),
          onChanged: (v) => setState(() {
            _consenso = v ?? false;
            if (_consenso) _consensoMancante = false;
          }),
        ),
        if (_consensoMancante)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              Informativa.spiegazioneConsensoObbligatorio,
              key: const Key('consenso-obbligatorio'),
              style: TextStyle(color: context.colori.errore),
            ),
          ),
        if (_erroreGenerale != null) ...[
          const SizedBox(height: 4),
          MessaggioErrore(
            messaggio: _erroreGenerale!,
            onRiprova: _erroreDiRete ? _creaAccount : null,
          ),
        ],
        const SizedBox(height: 12),
        PulsantePrimario(
          etichetta: 'Crea account',
          onPressed: _creaAccount,
          inCorso: _inCorso,
        ),
      ],
    );
  }
}

class _SchedaRuolo extends StatelessWidget {
  const _SchedaRuolo({
    required this.chiave,
    required this.icona,
    required this.titolo,
    required this.descrizione,
    required this.selezionato,
    required this.onTap,
  });

  final Key chiave;
  final IconData icona;
  final String titolo;
  final String descrizione;
  final bool selezionato;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    return Card(
      key: chiave,
      color: selezionato ? c.primarioTonale : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconaTonale(
                icona: icona,
                dimensione: 52,
                sfondo: selezionato ? c.superficie : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titolo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(descrizione),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.testoSecondario),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mostrata quando Supabase richiede la conferma dell'email (nessuna sessione
/// dopo la registrazione). Il codice di invito resta salvato nell'account e
/// viene usato al primo accesso.
class _ControllaEmail extends StatelessWidget {
  const _ControllaEmail({required this.email, required this.anteprima});

  final String email;
  final AnteprimaInvito? anteprima;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const IconaTonale(
                    icona: Icons.mark_email_read_outlined,
                    dimensione: 88,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Controlla la tua email',
                    style: testo.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ti abbiamo scritto a $email. Apri il link per confermare '
                    'l\'account, poi torna qui e accedi.',
                    textAlign: TextAlign.center,
                    style: testo.bodyLarge,
                  ),
                  if (anteprima != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Appena accedi ti colleghiamo a ${anteprima!.nomeNutrizionista}.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('vai-all-accesso'),
                    onPressed: () => context.go(Rotte.accesso),
                    child: const Text('Vai all\'accesso'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
