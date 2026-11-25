import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/dipendenze.dart';
import '../../../core/router/rotte.dart';
import '../../../core/tema/tema.dart';
import '../../../domain/modelli/alimento.dart';
import '../../../domain/modelli/modello_piano.dart';
import '../../../domain/modelli/obiettivi.dart';
import '../../../domain/modelli/piano_alimentare.dart';
import '../../../domain/regole/calcoli_piano.dart';
import '../../../domain/repository/pazienti_repository.dart';
import '../../comuni/componenti.dart';
import '../../comuni/controlli.dart';
import '../../comuni/stati_view.dart';
import 'aggiungi_alimento_page.dart';
import 'alternative_page.dart';
import 'copia_giorno_sheet.dart';
import 'modelli_sheet.dart';
import 'pasto_card.dart';
import 'quantita_sheet.dart';
import 'riepilogo_giorno.dart';
import 'storico_versioni_page.dart';

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

DateTime _oggi() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Problemi elencati per esteso nell'avviso di piano incompleto; gli altri
/// si riassumono (un piano di 5 giorni con 4 pasti vuoti ne ha 20).
const _righeProblemiVisibili = 4;

/// Pasti proposti per un piano nuovo (RF_GP_1: colazione, spuntino, pranzo, cena).
const _pastiPredefiniti = [
  TipoPasto.colazione,
  TipoPasto.spuntino,
  TipoPasto.pranzo,
  TipoPasto.cena,
];

/// Editor del piano alimentare di un paziente (UC_GP_1, UC_GP_2, RF_GP_1,
/// RF_GP_2, RF_GP_7, RF_GP_15, RF_GP_16).
///
/// Se il paziente non ha ancora un piano chiede data di inizio, giorni e
/// pasti; altrimenti parte dal piano in uso. Per ogni giorno mostra sempre
/// i totali e lo scostamento dagli obiettivi. Salvare crea una **nuova
/// versione** e la assegna al paziente: la precedente resta nello storico.
class PianoEditorPage extends StatefulWidget {
  const PianoEditorPage({
    super.key,
    required this.dip,
    required this.pazienteId,
    this.nomePaziente,
  });

  final Dipendenze dip;
  final String pazienteId;
  final String? nomePaziente;

  @override
  State<PianoEditorPage> createState() => _PianoEditorPageState();
}

class _PianoEditorPageState extends State<PianoEditorPage> {
  bool _caricamento = true;
  String? _erroreCaricamento;

  /// Piano in modifica; `null` finché non si è scelto giorni e pasti.
  PianoAlimentare? _piano;
  int _versioneInUso = 0;
  Obiettivi? _obiettivi;
  int _giorno = 1;
  bool _modificato = false;
  bool _inCorso = false;
  ErroreOperazione? _erroreSalvataggio;
  String? _pastoEvidenziato;

  String get _nome => widget.nomePaziente ?? 'il paziente';

  @override
  void initState() {
    super.initState();
    widget.dip.obiettivi.addListener(_ricaricaObiettivi);
    _carica();
  }

  @override
  void dispose() {
    widget.dip.obiettivi.removeListener(_ricaricaObiettivi);
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _erroreCaricamento = null;
    });
    try {
      final r = await Future.wait([
        widget.dip.piani.corrente(widget.pazienteId),
        widget.dip.obiettivi.corrente(widget.pazienteId),
      ]);
      if (!mounted) return;
      final corrente = r[0] as PianoAlimentare?;
      setState(() {
        _obiettivi = r[1] as Obiettivi?;
        if (corrente != null) {
          _versioneInUso = corrente.versione ?? 0;
          // La modifica parte dal piano in uso e diventa una nuova versione.
          _piano = PianoAlimentare(
            dataInizio: _oggi(),
            giorni: corrente.giorni,
          );
          _giorno = corrente.giorni.isEmpty
              ? 1
              : corrente.giorni.first.giornoSettimana;
        }
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

  /// Gli obiettivi cambiano dalla loro schermata: l'editor si aggiorna senza
  /// perdere le modifiche al piano.
  Future<void> _ricaricaObiettivi() async {
    try {
      final o = await widget.dip.obiettivi.corrente(widget.pazienteId);
      if (mounted) setState(() => _obiettivi = o);
    } on ErroreOperazione {
      // Resta il valore già mostrato.
    }
  }

  // --------------------------------------------------------- modifiche

  void _modifica(PianoAlimentare nuovo) => setState(() {
    _piano = nuovo;
    _modificato = true;
    _erroreSalvataggio = null;
    _pastoEvidenziato = null;
  });

  GiornoPiano? get _giornoAttivo => _piano?.giorno(_giorno);

  void _creaDaImpostazione(PianoAlimentare piano) => setState(() {
    _piano = piano;
    _giorno = piano.giorni.first.giornoSettimana;
    _modificato = true;
  });

  Future<void> _aggiungiAlimento(PastoPiano pasto) async {
    final alimento = await Navigator.of(context).push<Alimento>(
      MaterialPageRoute(
        builder: (_) => AggiungiAlimentoPage(alimenti: widget.dip.alimenti),
      ),
    );
    if (alimento == null || !mounted) return;
    if (!alimento.completo || alimento.id == null) {
      _avvisa('«${alimento.nome}» non ha tutti i valori nutrizionali.');
      return;
    }
    final q = await chiediQuantita(context, alimento: alimento);
    if (q == null || !mounted) return;
    _modifica(
      _piano!.aggiungiVoce(
        _giorno,
        pasto.chiave,
        VocePiano(alimento: alimento, quantitaG: q),
      ),
    );
  }

  Future<void> _cambiaQuantita(PastoPiano pasto, VocePiano voce) async {
    final q = await chiediQuantita(
      context,
      alimento: voce.alimento,
      iniziale: voce.quantitaG,
      etichettaConferma: 'Salva quantità',
    );
    if (q == null || !mounted) return;
    _modifica(_piano!.aggiornaQuantita(_giorno, pasto.chiave, voce.chiave, q));
  }

  /// Alternative ammesse per una voce (RF_GP_6): si modificano in una pagina
  /// a parte e ogni cambiamento arriva subito al piano.
  Future<void> _modificaAlternative(PastoPiano pasto, VocePiano voce) {
    final giorno = _giorno;
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AlternativePage(
          alimenti: widget.dip.alimenti,
          voce: voce,
          onCambia: (nuove) => _modifica(
            _piano!.impostaAlternative(
              giorno,
              pasto.chiave,
              voce.chiave,
              nuove,
            ),
          ),
        ),
      ),
    );
  }

  /// Copia il giorno attivo su altri giorni della settimana (RF_GP_13).
  Future<void> _copiaGiorno() async {
    final da = _giorno;
    final scelti = await scegliGiorniDestinazione(
      context,
      piano: _piano!,
      da: da,
    );
    if (scelti == null || !mounted) return;
    final conPasti = _piano!.giorniConAlimenti(scelti);
    if (conPasti.isNotEmpty) {
      final nomi = conPasti.map(GiorniSettimana.nome).join(', ');
      final ok = await _conferma(
        titolo: 'Sostituire i pasti?',
        messaggio:
            '${conPasti.length == 1 ? '$nomi ha già dei pasti' : '$nomi hanno già dei pasti'}: '
            'saranno sostituiti con quelli di '
            '${GiorniSettimana.nome(da).toLowerCase()}.',
        conferma: 'Sostituisci',
      );
      if (!ok || !mounted) return;
    }
    _modifica(_piano!.copiaGiorno(da, scelti));
    _avvisa(
      '${GiorniSettimana.nome(da)} copiato su ${scelti.length} '
      '${scelti.length == 1 ? 'giorno' : 'giorni'}.',
    );
  }

  Future<void> _salvaPastoComeModello(PastoPiano pasto) async {
    if (pasto.voci.isEmpty) {
      _avvisa('Aggiungi almeno un alimento prima di salvarlo come modello.');
      return;
    }
    final nome = await chiediNomeModello(
      context,
      titolo: 'Salva ${pasto.tipo.etichetta.toLowerCase()} come modello',
      suggerimento: pasto.tipo.etichetta,
    );
    if (nome == null || !mounted) return;
    try {
      await widget.dip.modelli.salvaPasto(nome, pasto);
      if (mounted) _avvisa('«$nome» salvato tra i pasti salvati.');
    } on ErroreOperazione catch (e) {
      if (mounted) _avvisa(e.messaggio);
    }
  }

  Future<void> _inserisciPastoSalvato() async {
    final modello = await scegliModello(
      context,
      repository: widget.dip.modelli,
      tipo: TipoModello.pasto,
    );
    if (modello == null || !mounted) return;
    try {
      _modifica(_piano!.inserisciPasto(_giorno, modello.pasto));
    } on FormatException {
      _avvisa('Questo pasto salvato non è leggibile.');
    }
  }

  Future<void> _salvaPianoComeModello() async {
    final problemi = problemiDelPiano(_piano!);
    if (problemi.isNotEmpty) {
      _avvisa(
        'Completa il piano prima di salvarlo come modello. ${problemi.first.messaggio}',
      );
      return;
    }
    final nome = await chiediNomeModello(
      context,
      titolo: 'Salva il piano come modello',
    );
    if (nome == null || !mounted) return;
    try {
      await widget.dip.modelli.salvaPiano(nome, _piano!);
      if (mounted) _avvisa('«$nome» salvato tra i piani modello.');
    } on ErroreOperazione catch (e) {
      if (mounted) _avvisa(e.messaggio);
    }
  }

  /// Parte da un piano modello per un piano nuovo: è una copia (RF_GP_9).
  Future<void> _partiDaModello() async {
    final modello = await scegliModello(
      context,
      repository: widget.dip.modelli,
      tipo: TipoModello.piano,
    );
    if (modello == null || !mounted) return;
    try {
      final piano = modello.piano(_oggi());
      if (piano.giorni.isEmpty) {
        _avvisa('Questo piano modello non ha giorni.');
        return;
      }
      _creaDaImpostazione(piano);
    } on FormatException {
      _avvisa('Questo piano modello non è leggibile.');
    }
  }

  Future<void> _aggiungiPasto() async {
    final tipo = await showModalBottomSheet<TipoPasto>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in TipoPasto.values)
              ListTile(
                title: Text(t.etichetta),
                onTap: () => Navigator.of(context).pop(t),
              ),
          ],
        ),
      ),
    );
    if (tipo != null && mounted) {
      _modifica(_piano!.aggiungiPasto(_giorno, tipo));
    }
  }

  Future<void> _rimuoviPasto(PastoPiano pasto) async {
    if (pasto.voci.isNotEmpty) {
      final ok = await _conferma(
        titolo: 'Eliminare ${pasto.tipo.etichetta.toLowerCase()}?',
        messaggio:
            'Il pasto ha ${pasto.voci.length} alimenti: verranno tolti dal '
            'piano.',
        conferma: 'Elimina',
      );
      if (!ok || !mounted) return;
    }
    _modifica(_piano!.rimuoviPasto(_giorno, pasto.chiave));
  }

  Future<void> _impostaOrario(PastoPiano pasto) async {
    final attuale = pasto.orario?.split(':');
    final scelto = await showTimePicker(
      context: context,
      initialTime: attuale == null
          ? TimeOfDay(
              hour: int.parse(pasto.tipo.orarioPredefinito.substring(0, 2)),
              minute: int.parse(pasto.tipo.orarioPredefinito.substring(3, 5)),
            )
          : TimeOfDay(
              hour: int.parse(attuale[0]),
              minute: int.parse(attuale[1]),
            ),
    );
    if (scelto == null || !mounted) return;
    final hh = scelto.hour.toString().padLeft(2, '0');
    final mm = scelto.minute.toString().padLeft(2, '0');
    _modifica(_piano!.impostaOrario(_giorno, pasto.chiave, '$hh:$mm'));
  }

  Future<void> _aggiungiGiorno() async {
    final mancanti = [
      for (final g in GiorniSettimana.tutti)
        if (_piano!.giorno(g) == null) g,
    ];
    if (mancanti.isEmpty) return;
    final scelto = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final g in mancanti)
                ListTile(
                  title: Text(GiorniSettimana.nome(g)),
                  onTap: () => Navigator.of(context).pop(g),
                ),
            ],
          ),
        ),
      ),
    );
    if (scelto == null || !mounted) return;
    // Stessi tipi di pasto del giorno che si sta guardando (oppure i predefiniti).
    final tipi = _giornoAttivo == null || _giornoAttivo!.pasti.isEmpty
        ? _pastiPredefiniti
        : [for (final p in _giornoAttivo!.pasti) p.tipo];
    setState(() => _giorno = scelto);
    _modifica(_piano!.aggiungiGiorno(scelto, tipi));
  }

  Future<void> _rimuoviGiorno() async {
    final g = _giornoAttivo;
    if (g == null) return;
    final conAlimenti = g.pasti.any((p) => p.voci.isNotEmpty);
    if (conAlimenti) {
      final ok = await _conferma(
        titolo: 'Togliere ${GiorniSettimana.nome(_giorno).toLowerCase()}?',
        messaggio:
            'I pasti e gli alimenti di questo giorno saranno tolti dal piano.',
        conferma: 'Togli',
      );
      if (!ok || !mounted) return;
    }
    final nuovo = _piano!.rimuoviGiorno(_giorno);
    setState(() {
      if (nuovo.giorni.isNotEmpty) _giorno = nuovo.giorni.first.giornoSettimana;
    });
    _modifica(nuovo);
  }

  Future<void> _cambiaData() async {
    final scelta = await showDatePicker(
      context: context,
      initialDate: _piano!.dataInizio,
      firstDate: _oggi().subtract(const Duration(days: 30)),
      lastDate: _oggi().add(const Duration(days: 365)),
    );
    if (scelta != null && mounted) {
      _modifica(_piano!.copyWith(dataInizio: scelta));
    }
  }

  Future<bool> _conferma({
    required String titolo,
    required String messaggio,
    required String conferma,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titolo),
        content: Text(messaggio),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(conferma),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _avvisa(String messaggio) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(messaggio)));

  // --------------------------------------------------------- salvataggio

  Future<void> _salva() async {
    final piano = _piano;
    if (piano == null || _inCorso) return;

    // UC_GP_1, flusso 8.1: pasto vuoto → completarlo o eliminarlo.
    final problemi = problemiDelPiano(piano);
    if (problemi.isNotEmpty) {
      final primo = problemi.first;
      setState(() {
        if (primo.giorno != null) _giorno = primo.giorno!;
        _pastoEvidenziato = primo.chiavePasto;
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Il piano non è completo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in problemi.take(_righeProblemiVisibili))
                  Text('• ${p.messaggio}'),
                if (problemi.length > _righeProblemiVisibili)
                  Text(
                    '…e altri ${problemi.length - _righeProblemiVisibili} '
                    'da completare.',
                    key: const Key('altri-problemi'),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ho capito'),
            ),
          ],
        ),
      );
      return;
    }

    final versione = _versioneInUso + 1;
    final ok = await _conferma(
      titolo: 'Salvare e assegnare il piano?',
      messaggio:
          'Si crea la versione $versione e $_nome la vedrà nella sezione '
          'Dieta. ${_versioneInUso > 0 ? 'La versione $_versioneInUso resta nello storico.' : ''}',
      conferma: 'Salva e assegna',
    );
    if (!ok || !mounted) return;

    setState(() {
      _inCorso = true;
      _erroreSalvataggio = null;
    });
    final messaggi = ScaffoldMessenger.of(context);
    try {
      final salvato = await widget.dip.piani.salva(widget.pazienteId, piano);
      if (!mounted) return;
      // Subito dopo si può uscire senza avviso: tutto è salvato.
      setState(() => _modificato = false);
      messaggi.showSnackBar(
        SnackBar(
          content: Text(
            'Piano salvato: versione ${salvato.versione}. '
            '${widget.nomePaziente ?? 'Il paziente'} lo vede nella sezione Dieta.',
          ),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } on ErroreOperazione catch (e) {
      // Il piano resta com'è: si corregge o si riprova senza perdere nulla.
      if (mounted) setState(() => _erroreSalvataggio = e);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _vaiAgliObiettivi() async {
    await context.push(
      Rotte.nutObiettivi(widget.pazienteId),
      extra: widget.nomePaziente,
    );
    if (mounted) await _ricaricaObiettivi();
  }

  Future<void> _apriStorico() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => StoricoVersioniPage(
        piani: widget.dip.piani,
        obiettivi: widget.dip.obiettivi,
        pazienteId: widget.pazienteId,
        nomePaziente: widget.nomePaziente,
      ),
    ),
  );

  Future<void> _confermaUscita() async {
    final esci = await _conferma(
      titolo: 'Uscire senza salvare?',
      messaggio: 'Le modifiche al piano non salvate andranno perse.',
      conferma: 'Esci',
    );
    if (!esci || !mounted) return;
    setState(() => _modificato = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // --------------------------------------------------------- interfaccia

  @override
  Widget build(BuildContext context) {
    final inModifica = _piano != null;
    return PopScope(
      canPop: !_modificato,
      onPopInvokedWithResult: (esce, _) {
        if (!esce) _confermaUscita();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.nomePaziente == null
                ? 'Piano alimentare'
                : 'Piano di ${widget.nomePaziente}',
          ),
          actions: [
            if (!_caricamento && _erroreCaricamento == null)
              IconButton(
                tooltip: 'Versioni del piano',
                icon: const Icon(Icons.history),
                onPressed: _apriStorico,
              ),
            if (inModifica)
              IconButton(
                tooltip: 'Salva e assegna',
                icon: _inCorso
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.check),
                onPressed: _inCorso ? null : _salva,
              ),
            if (inModifica)
              PopupMenuButton<String>(
                tooltip: 'Altre azioni',
                onSelected: (_) => _salvaPianoComeModello(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'modello',
                    child: Text('Salva piano come modello'),
                  ),
                ],
              ),
          ],
        ),
        body: SafeArea(
          child: _caricamento
              ? const CaricamentoView()
              : _erroreCaricamento != null
              ? ErroreView(messaggio: _erroreCaricamento!, onRiprova: _carica)
              : !inModifica
              ? _Impostazione(
                  nomePaziente: widget.nomePaziente,
                  obiettivi: _obiettivi,
                  onImposta: _vaiAgliObiettivi,
                  onCrea: _creaDaImpostazione,
                  onDaModello: _partiDaModello,
                )
              : _editor(context),
        ),
      ),
    );
  }

  Widget _editor(BuildContext context) {
    final piano = _piano!;
    final giorno = _giornoAttivo;
    final c = context.colori;
    final testoGrande =
        MediaQuery.textScalerOf(context).scale(10) / 10 >
        RigaElenco.scalaTestoImpilata;

    final testa = <Widget>[
      if (_obiettivi == null)
        _BannerObiettivi(nome: _nome, onImposta: _vaiAgliObiettivi),
      if (_erroreSalvataggio != null) ...[
        const SizedBox(height: 8),
        MessaggioErrore(
          messaggio: _erroreSalvataggio!.messaggio,
          onRiprova: _salva,
        ),
      ],
      const SizedBox(height: 8),
      _RigaVersione(
        versione: _versioneInUso + 1,
        dataInizio: piano.dataInizio,
        onCambiaData: _cambiaData,
      ),
      Row(
        children: [
          Expanded(
            child: SelettorePillole<int>(
              opzioni: [
                for (final g in piano.giorni)
                  OpzioneSelettore(
                    g.giornoSettimana,
                    GiorniSettimana.abbreviato(g.giornoSettimana),
                  ),
              ],
              selezionato: _giorno,
              onCambiato: (g) => setState(() => _giorno = g),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Giorni del piano',
            onSelected: (v) => switch (v) {
              'aggiungi' => _aggiungiGiorno(),
              'copia' => _copiaGiorno(),
              _ => _rimuoviGiorno(),
            },
            itemBuilder: (_) => [
              if (piano.giorni.length < GiorniSettimana.tutti.length)
                const PopupMenuItem(
                  value: 'aggiungi',
                  child: Text('Aggiungi un giorno'),
                ),
              if (giorno != null)
                PopupMenuItem(
                  value: 'copia',
                  child: Text(
                    'Copia ${GiorniSettimana.nome(_giorno).toLowerCase()} su…',
                  ),
                ),
              if (giorno != null)
                PopupMenuItem(
                  value: 'rimuovi',
                  child: Text(
                    'Togli ${GiorniSettimana.nome(_giorno).toLowerCase()}',
                  ),
                ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (giorno != null)
        RiepilogoGiorno(
          titolo: GiorniSettimana.nome(_giorno),
          totale: macroGiorno(giorno),
          obiettivi: _obiettivi,
        ),
    ];

    final pasti = <Widget>[
      if (giorno == null)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Questo piano non ha giorni: aggiungine uno dal menu.'),
        )
      else ...[
        for (final p in giorno.pasti) ...[
          _CardPasto(
            key: ValueKey(p.chiave),
            pasto: p,
            evidenziato: p.chiave == _pastoEvidenziato,
            onAggiungi: () => _aggiungiAlimento(p),
            onCambiaQuantita: (v) => _cambiaQuantita(p, v),
            onRimuoviVoce: (v) =>
                _modifica(piano.rimuoviVoce(_giorno, p.chiave, v.chiave)),
            onRiordina: (da, a) =>
                _modifica(piano.spostaVoce(_giorno, p.chiave, da, a)),
            onOrario: () => _impostaOrario(p),
            onRimuovi: () => _rimuoviPasto(p),
            onAlternative: (v) => _modificaAlternative(p, v),
            onSalvaModello: () => _salvaPastoComeModello(p),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _aggiungiPasto,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi pasto'),
            ),
            OutlinedButton.icon(
              onPressed: _inserisciPastoSalvato,
              icon: const Icon(Icons.bookmark_border),
              label: const Text('Da pasto salvato'),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        // Con testo normale i totali restano fissi sopra i pasti; con testo
        // molto grande occuperebbero lo schermo e scorrono con il resto.
        child: testoGrande
            ? ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [...testa, const SizedBox(height: 8), ...pasti],
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: testa,
                    ),
                  ),
                  Divider(height: 16, color: c.bordo),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: pasti,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Invito a impostare gli obiettivi (UC_GP_1 passo 1): non blocca l'editor.
class _BannerObiettivi extends StatelessWidget {
  const _BannerObiettivi({required this.nome, required this.onImposta});

  final String nome;
  final VoidCallback onImposta;

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    return Container(
      key: const Key('banner-obiettivi'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.avvisoTonale,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: c.avviso),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Non hai ancora impostato gli obiettivi di $nome: senza, i '
                  'totali non si confrontano con nulla.',
                  style: TextStyle(color: c.avviso),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onImposta,
              child: const Text('Imposta obiettivi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RigaVersione extends StatelessWidget {
  const _RigaVersione({
    required this.versione,
    required this.dataInizio,
    required this.onCambiaData,
  });

  final int versione;
  final DateTime dataInizio;
  final VoidCallback onCambiaData;

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Versione $versione · dal ${_data(dataInizio)}',
            key: const Key('riga-versione'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: c.testoSecondario),
          ),
        ),
        TextButton(onPressed: onCambiaData, child: const Text('Cambia data')),
      ],
    );
  }
}

/// Primo passo di un piano nuovo (UC_GP_1 passi 2-4): data di inizio, giorni
/// e pasti previsti.
class _Impostazione extends StatefulWidget {
  const _Impostazione({
    required this.nomePaziente,
    required this.obiettivi,
    required this.onImposta,
    required this.onCrea,
    required this.onDaModello,
  });

  final String? nomePaziente;
  final Obiettivi? obiettivi;
  final VoidCallback onImposta;
  final ValueChanged<PianoAlimentare> onCrea;
  final VoidCallback onDaModello;

  @override
  State<_Impostazione> createState() => _ImpostazioneState();
}

class _ImpostazioneState extends State<_Impostazione> {
  final _giorni = <int>{...GiorniSettimana.tutti};
  final _tipi = <TipoPasto>{..._pastiPredefiniti};
  DateTime _inizio = _oggi();

  Future<void> _scegliData() async {
    final scelta = await showDatePicker(
      context: context,
      initialDate: _inizio,
      firstDate: _oggi().subtract(const Duration(days: 30)),
      lastDate: _oggi().add(const Duration(days: 365)),
    );
    if (scelta != null && mounted) setState(() => _inizio = scelta);
  }

  void _crea() {
    final tipi = [
      for (final t in TipoPasto.values)
        if (_tipi.contains(t)) t,
    ];
    var piano = PianoAlimentare(dataInizio: _inizio);
    for (final g in GiorniSettimana.tutti) {
      if (_giorni.contains(g)) piano = piano.aggiungiGiorno(g, tipi);
    }
    widget.onCrea(piano);
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final pronto = _giorni.isNotEmpty && _tipi.isNotEmpty;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.nomePaziente == null
                  ? 'Nuovo piano'
                  : 'Nuovo piano per ${widget.nomePaziente}',
              style: testo.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Scegli da quando vale, i giorni e i pasti previsti. Poi '
              'aggiungi gli alimenti pasto per pasto.',
              style: testo.bodyMedium?.copyWith(color: c.testoSecondario),
            ),
            if (widget.obiettivi == null)
              _BannerObiettivi(
                nome: widget.nomePaziente ?? 'il paziente',
                onImposta: widget.onImposta,
              ),
            const SizedBox(height: 20),
            Text('Valido dal', style: testo.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _scegliData,
              icon: const Icon(Icons.event),
              label: Text(_data(_inizio)),
            ),
            const SizedBox(height: 20),
            Text('Giorni', style: testo.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in GiorniSettimana.tutti)
                  FilterChip(
                    label: Text(GiorniSettimana.abbreviato(g)),
                    selected: _giorni.contains(g),
                    showCheckmark: false,
                    onSelected: (v) =>
                        setState(() => v ? _giorni.add(g) : _giorni.remove(g)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Pasti di ogni giorno', style: testo.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in TipoPasto.values)
                  FilterChip(
                    label: Text(t.etichetta),
                    selected: _tipi.contains(t),
                    showCheckmark: false,
                    onSelected: (v) =>
                        setState(() => v ? _tipi.add(t) : _tipi.remove(t)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            PulsantePrimario(
              etichetta: 'Crea piano',
              onPressed: pronto ? _crea : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onDaModello,
              icon: const Icon(Icons.bookmark_border),
              label: const Text('Parti da un piano modello'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un pasto del giorno con le sue voci riordinabili.
class _CardPasto extends StatelessWidget {
  const _CardPasto({
    super.key,
    required this.pasto,
    required this.evidenziato,
    required this.onAggiungi,
    required this.onCambiaQuantita,
    required this.onRimuoviVoce,
    required this.onRiordina,
    required this.onOrario,
    required this.onRimuovi,
    required this.onAlternative,
    required this.onSalvaModello,
  });

  final PastoPiano pasto;
  final bool evidenziato;
  final VoidCallback onAggiungi;
  final ValueChanged<VocePiano> onCambiaQuantita;
  final ValueChanged<VocePiano> onRimuoviVoce;
  final void Function(int da, int a) onRiordina;
  final VoidCallback onOrario;
  final VoidCallback onRimuovi;
  final ValueChanged<VocePiano> onAlternative;
  final VoidCallback onSalvaModello;

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    return Card(
      margin: EdgeInsets.zero,
      shape: evidenziato
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: c.errore, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntestazionePasto(
              pasto: pasto,
              menu: PopupMenuButton<String>(
                tooltip: 'Opzioni del pasto',
                onSelected: (v) => switch (v) {
                  'orario' => onOrario(),
                  'modello' => onSalvaModello(),
                  _ => onRimuovi(),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'orario', child: Text('Imposta orario')),
                  PopupMenuItem(
                    value: 'modello',
                    child: Text('Salva come modello'),
                  ),
                  PopupMenuItem(value: 'rimuovi', child: Text('Elimina pasto')),
                ],
              ),
            ),
            if (pasto.voci.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  evidenziato
                      ? 'Pasto senza alimenti: aggiungine uno o eliminalo.'
                      : 'Nessun alimento ancora.',
                  style: TextStyle(
                    color: evidenziato ? c.errore : c.testoSecondario,
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: pasto.voci.length,
                onReorderItem: onRiordina,
                itemBuilder: (context, i) {
                  final v = pasto.voci[i];
                  return InkWell(
                    key: ValueKey(v.chiave),
                    onTap: () => onCambiaQuantita(v),
                    child: RigaVoce(
                      voce: v,
                      onAlternative: () => onAlternative(v),
                      azione: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Togli ${v.alimento.nome}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => onRimuoviVoce(v),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAggiungi,
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi alimento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
