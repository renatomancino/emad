import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/dipendenze.dart';
import '../../core/router/rotte.dart';
import '../../core/tema/tema.dart';
import '../../domain/modelli/dati_profilo.dart';
import '../../domain/modelli/profilo.dart';
import '../../domain/regole/validazione.dart';
import '../../domain/repository/auth_repository.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../nutrizionista/abbonamento_view.dart';
import 'componenti.dart';
import 'controlli.dart';
import 'segnaposto_page.dart';
import 'stati_view.dart';

/// Profilo dell'utente (UC_GA_3, RF_GA_5) con logout (UC_GA_2) ed eliminazione
/// dell'account (UC_GA_5).
/// - Paziente: nome, altezza, data di nascita, obiettivo; interruzione del
///   collegamento (UC_GI_5).
/// - Nutrizionista: nome e titolo; accesso a disponibilità (UC_GV_3) e
///   abbonamento (UC_GAD_3).
class ProfiloPage extends StatefulWidget {
  const ProfiloPage({
    super.key,
    required this.dip,
    this.mostraIndietro = false,
  });

  final Dipendenze dip;

  /// `true` quando la pagina è aperta sopra una sezione (paziente).
  final bool mostraIndietro;

  @override
  State<ProfiloPage> createState() => _ProfiloPageState();
}

class _ProfiloPageState extends State<ProfiloPage> {
  final _nome = TextEditingController();
  final _titolo = TextEditingController();
  final _altezza = TextEditingController();
  final _obiettivo = TextEditingController();
  DateTime? _nascita;

  bool _caricamento = true;
  String? _erroreCaricamento;
  bool _salvando = false;
  bool _inCorso = false;
  String? _erroreNome;
  String? _erroreAltezza;
  String? _erroreSalvataggio;
  bool _erroreSalvataggioDiRete = false;

  AuthRepository get _auth => widget.dip.auth;
  bool get _nutrizionista => _auth.ruolo == Ruolo.nutrizionista;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    for (final c in [_nome, _titolo, _altezza, _obiettivo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _erroreCaricamento = null;
    });
    try {
      final d = await widget.dip.profilo.leggi();
      if (!mounted) return;
      setState(() {
        _nome.text = d.nome;
        _titolo.text = d.titolo ?? '';
        _altezza.text = d.altezzaCm == null ? '' : _numero(d.altezzaCm!);
        _obiettivo.text = d.obiettivo ?? '';
        _nascita = d.dataNascita;
        _caricamento = false;
      });
    } on ErroreOperazione catch (e) {
      if (!mounted) return;
      setState(() {
        _erroreCaricamento = e.messaggio;
        _caricamento = false;
      });
    }
  }

  static String _numero(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toString();

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _scegliData() async {
    final oggi = DateTime.now();
    final scelta = await showDatePicker(
      context: context,
      initialDate: _nascita ?? DateTime(oggi.year - 30),
      firstDate: DateTime(1900),
      lastDate: oggi,
      helpText: 'Data di nascita',
      cancelText: Testi.annulla,
    );
    if (scelta != null && mounted) setState(() => _nascita = scelta);
  }

  Future<void> _salva() async {
    final erroreNome = Validazione.nome(_nome.text);
    final erroreAltezza = _nutrizionista
        ? null
        : Validazione.altezzaCm(_altezza.text);
    setState(() {
      _erroreNome = erroreNome;
      _erroreAltezza = erroreAltezza;
      _erroreSalvataggio = null;
    });
    if (erroreNome != null || erroreAltezza != null) return;

    setState(() => _salvando = true);
    try {
      await widget.dip.profilo.salva(
        DatiProfilo(
          nome: _nome.text.trim(),
          titolo: _nutrizionista ? _titolo.text : null,
          altezzaCm: _nutrizionista || _altezza.text.trim().isEmpty
              ? null
              : double.parse(_altezza.text.trim().replaceAll(',', '.')),
          dataNascita: _nutrizionista ? null : _nascita,
          obiettivo: _nutrizionista ? null : _obiettivo.text,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profilo aggiornato.')));
      }
    } on ErroreOperazione catch (e) {
      // I campi restano compilati: si può riprovare senza perdere nulla.
      if (mounted) {
        setState(() {
          _erroreSalvataggio = e.messaggio;
          _erroreSalvataggioDiRete = e.codice == 'rete';
        });
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<bool> _conferma(String titolo, String testo, String azione) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titolo),
        content: Text(testo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Testi.annulla),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(azione),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _avvisa(String messaggio) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(messaggio)));
  }

  Future<void> _esci() async {
    if (!await _conferma(Testi.esci, Testi.esciConferma, Testi.esci)) return;
    setState(() => _inCorso = true);
    try {
      // Il router torna da solo alla schermata di accesso.
      await _auth.esci();
    } on ErroreAuth catch (e) {
      _avvisa(e.messaggio);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _scollegati() async {
    final ok = await _conferma(
      'Interrompere il collegamento?',
      'Il tuo nutrizionista non vedrà più i nuovi dati e le visite future '
          'verranno annullate. I dati già registrati restano nel suo storico. '
          'Per tornare a essere seguito servirà un nuovo invito.',
      'Interrompi',
    );
    if (!ok) return;
    setState(() => _inCorso = true);
    try {
      await widget.dip.pazienti.scollegati();
      // Il router porta alla schermata dove inserire un nuovo codice.
      await _auth.aggiornaCollegamento();
      _avvisa('Collegamento interrotto.');
    } on ErroreOperazione catch (e) {
      _avvisa(e.messaggio);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilo = _auth.profilo;
    final testo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: widget.mostraIndietro
          ? AppBar(title: const Text(Testi.profilo))
          : IntestazioneSezione(
              titolo: _nutrizionista
                  ? Testi.profiloAbbonamentoTitolo
                  : Testi.profilo,
              sottotitolo: profilo?.ruolo.etichetta,
            ),
      body: _caricamento
          ? const CaricamentoView()
          : _erroreCaricamento != null
          ? ErroreView(messaggio: _erroreCaricamento!, onRiprova: _carica)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _formDati(testo),
                const SizedBox(height: 16),
                if (_nutrizionista) ...[
                  RigaElenco(
                    key: const Key('apri-disponibilita'),
                    leading: const IconaTonale(
                      icona: Icons.schedule,
                      dimensione: 40,
                    ),
                    titolo: 'Disponibilità e durata della visita',
                    sottotitolo: 'Giorni e orari di ricevimento',
                    trailing: Icon(
                      Icons.chevron_right,
                      color: context.colori.testoSecondario,
                    ),
                    onTap: () => context.go(Rotte.nutDisponibilita),
                  ),
                  const SizedBox(height: 16),
                  AbbonamentoView(repository: widget.dip.abbonamento),
                ] else ...[
                  const RigaElenco(
                    leading: IconaTonale(
                      icona: Icons.notifications_none,
                      dimensione: 40,
                    ),
                    titolo: 'Promemoria dei pasti',
                    sottotitolo: 'In arrivo (UC_GN_2)',
                  ),
                  if (_auth.collegato) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _inCorso ? null : _scollegati,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Interrompi il collegamento'),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _inCorso ? null : _esci,
                  icon: const Icon(Icons.logout),
                  label: const Text(Testi.esci),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('apri-elimina-account'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colori.errore,
                  ),
                  onPressed: _inCorso
                      ? null
                      : () => context.push(Rotte.eliminaAccount),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Elimina il mio account'),
                ),
              ],
            ),
    );
  }

  Widget _formDati(TextTheme testo) {
    return SchedaSezione(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconaTonale(icona: Icons.person),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _auth.profilo?.ruolo.etichetta ?? '',
                  style: testo.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CampoTesto(
            controller: _nome,
            etichetta: 'Nome e cognome',
            errore: _erroreNome,
            suggerimentiAutofill: const [AutofillHints.name],
            onCambiato: (_) => setState(() => _erroreNome = null),
          ),
          if (_nutrizionista) ...[
            const SizedBox(height: 12),
            CampoTesto(
              controller: _titolo,
              etichetta: 'Titolo (es. biologa nutrizionista)',
            ),
          ] else if (_auth.collegato) ...[
            const SizedBox(height: 12),
            CampoTesto(
              controller: _altezza,
              etichetta: 'Altezza (cm)',
              errore: _erroreAltezza,
              tastiera: const TextInputType.numberWithOptions(decimal: true),
              onCambiato: (_) => setState(() => _erroreAltezza = null),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('scegli-data-nascita'),
              onPressed: _scegliData,
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                _nascita == null
                    ? 'Data di nascita'
                    : 'Nato il ${_data(_nascita!)}',
              ),
            ),
            const SizedBox(height: 12),
            CampoTesto(
              controller: _obiettivo,
              etichetta: 'Il tuo obiettivo',
              maxRighe: 3,
            ),
          ],
          if (_erroreSalvataggio != null) ...[
            const SizedBox(height: 12),
            MessaggioErrore(
              messaggio: _erroreSalvataggio!,
              onRiprova: _erroreSalvataggioDiRete ? _salva : null,
            ),
          ],
          const SizedBox(height: 16),
          PulsantePrimario(
            etichetta: 'Salva le modifiche',
            onPressed: _salva,
            inCorso: _salvando,
          ),
        ],
      ),
    );
  }
}
