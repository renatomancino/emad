import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/dipendenze.dart';
import '../../core/router/rotte.dart';
import '../../core/tema/tema.dart';
import '../../domain/modelli/paziente.dart';
import '../../domain/modelli/piano.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../comuni/errore_limite_dialog.dart';
import '../comuni/componenti.dart';
import '../comuni/segnaposto_page.dart';
import '../comuni/stati_view.dart';
import 'sponsor_card.dart';

/// Filtro dell'elenco (RF_GI_6): Attivi / Archiviati / Tutti.
enum FiltroPazienti {
  attivi('Attivi'),
  archiviati('Archiviati'),
  tutti('Tutti');

  const FiltroPazienti(this.etichetta);

  final String etichetta;

  bool include(StatoPaziente stato) => switch (this) {
    FiltroPazienti.attivi => stato == StatoPaziente.attivo,
    FiltroPazienti.archiviati => stato == StatoPaziente.archiviato,
    FiltroPazienti.tutti => true,
  };
}

/// Elenco pazienti del nutrizionista (UC_GI_3, UC_GI_4, RF_GI_3-6) con inviti
/// in attesa (RF_GI_8) e scheda sponsor nel Free (RF_GAD_6). Il semaforo e
/// l'ultimo check-in arrivano con la dashboard della fase 3.
class PazientiPage extends StatefulWidget {
  const PazientiPage({super.key, required this.dip});

  final Dipendenze dip;

  @override
  State<PazientiPage> createState() => _PazientiPageState();
}

class _PazientiPageState extends State<PazientiPage> {
  final _ricerca = TextEditingController();
  FiltroPazienti _filtro = FiltroPazienti.attivi;
  bool _caricamento = true;
  String? _errore;
  List<PazienteElenco> _pazienti = [];
  List<Invito> _inviti = [];
  StatoAbbonamento? _abbonamento;

  @override
  void initState() {
    super.initState();
    widget.dip.pazienti.addListener(_carica);
    widget.dip.abbonamento.addListener(_carica);
    _ricerca.addListener(() => setState(() {}));
    _carica();
  }

  @override
  void dispose() {
    widget.dip.pazienti.removeListener(_carica);
    widget.dip.abbonamento.removeListener(_carica);
    _ricerca.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final risultati = await Future.wait([
        widget.dip.pazienti.elencoPazienti(),
        widget.dip.pazienti.elencoInviti(),
        widget.dip.abbonamento.stato(),
      ]);
      if (!mounted) return;
      setState(() {
        _pazienti = risultati[0] as List<PazienteElenco>;
        _inviti = risultati[1] as List<Invito>;
        _abbonamento = risultati[2] as StatoAbbonamento;
        _caricamento = false;
      });
    } on ErroreOperazione catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.messaggio;
        _caricamento = false;
      });
    }
  }

  void _vaiAlPiano() => context.go(Rotte.nutProfilo);

  void _mostraArchiviabili() => setState(() => _filtro = FiltroPazienti.attivi);

  Future<void> _esegui(Future<void> Function() azione, String conferma) async {
    try {
      await azione();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(conferma)));
    } on ErroreLimitePiano catch (e) {
      if (!mounted) return;
      await mostraErroreLimite(
        context,
        e,
        onCambiaPiano: _vaiAlPiano,
        onArchivia: _mostraArchiviabili,
      );
    } on ErroreOperazione catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.messaggio)));
    }
  }

  Future<void> _invita() async {
    final ab = _abbonamento;
    if (ab != null && ab.piano.limite != null) {
      // Controllo anticipato per un messaggio immediato; il database
      // ricontrolla comunque in crea_invito.
      final occupati =
          (ab.piano == PianoAbbonamento.free
              ? ab.pazientiCollegatiTotali
              : ab.pazientiAttivi) +
          ab.invitiInAttesa;
      if (occupati >= ab.piano.limite!) {
        await mostraErroreLimite(
          context,
          ErroreLimitePiano(
            ab.piano == PianoAbbonamento.free
                ? 'Hai raggiunto il limite del piano Free (1 paziente).'
                : 'Hai raggiunto il limite del piano Start (5 pazienti attivi).',
            piano: ab.piano,
          ),
          onCambiaPiano: _vaiAlPiano,
          onArchivia: _mostraArchiviabili,
        );
        return;
      }
    }
    if (mounted) context.go(Rotte.nutInvito);
  }

  Future<void> _confermaArchiviazione(PazienteElenco p) async {
    final free = _abbonamento?.piano == PianoAbbonamento.free;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archiviare ${p.nome}?'),
        content: Text(
          'Il paziente non viene eliminato: lo storico resta consultabile e '
          'puoi riattivarlo in seguito. Le visite future vengono annullate.\n\n'
          '${free ? 'Nel piano Free l\'archiviazione non libera il posto.' : 'Nel tuo piano l\'archiviazione libera un posto.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archivia'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _esegui(
        () => widget.dip.pazienti.archivia(p.id),
        '${p.nome} archiviato.',
      );
    }
  }

  void _azioniPaziente(PazienteElenco p) {
    final router = GoRouter.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.nome, style: Theme.of(context).textTheme.titleLarge),
              Text(p.stato.etichetta),
              const SizedBox(height: 16),
              if (p.stato == StatoPaziente.attivo) ...[
                FilledButton.icon(
                  icon: const Icon(Icons.track_changes_outlined),
                  label: const Text('Obiettivi nutrizionali'),
                  onPressed: () {
                    Navigator.pop(context);
                    router.push(Rotte.nutObiettivi(p.id), extra: p.nome);
                  },
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Piano alimentare'),
                  onPressed: () {
                    Navigator.pop(context);
                    router.push(Rotte.nutPiano(p.id), extra: p.nome);
                  },
                ),
                const SizedBox(height: 8),
              ],
              if (p.stato == StatoPaziente.attivo)
                OutlinedButton.icon(
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archivia'),
                  onPressed: () {
                    Navigator.pop(context);
                    _confermaArchiviazione(p);
                  },
                ),
              if (p.stato == StatoPaziente.archiviato &&
                  !p.archiviatoDalPaziente)
                FilledButton.icon(
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Riattiva'),
                  onPressed: () {
                    Navigator.pop(context);
                    _esegui(
                      () => widget.dip.pazienti.riattiva(p.id),
                      '${p.nome} di nuovo attivo.',
                    );
                  },
                ),
              if (p.archiviatoDalPaziente)
                const Text(
                  'Il paziente ha interrotto il collegamento: per seguirlo di '
                  'nuovo serve un nuovo invito.',
                ),
              const SizedBox(height: 8),
              Text(
                'Dettaglio, piano e check-in arrivano nelle prossime schede. '
                'Un paziente collegato non si elimina mai.',
                style: TextStyle(color: context.colori.testoSecondario),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _revoca(Invito i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revocare l\'invito?'),
        content: Text('Il codice ${i.codice} non sarà più valido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoca'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _esegui(
        () => widget.dip.pazienti.revocaInvito(i.id),
        'Invito revocato.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IntestazioneSezione(
        titolo: 'Pazienti',
        sottotitolo: 'Elenco, filtri e inviti',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _caricamento ? null : _invita,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Invita'),
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_caricamento && _abbonamento == null) return const CaricamentoView();
    if (_errore != null) {
      return ErroreView(messaggio: _errore!, onRiprova: _carica);
    }

    final q = _ricerca.text.trim().toLowerCase();
    final visibili =
        _pazienti
            .where((p) => p.stato != StatoPaziente.invitato)
            .where((p) => _filtro.include(p.stato))
            .where((p) => q.isEmpty || p.nome.toLowerCase().contains(q))
            .toList()
          // Ordine alfabetico (l'ordinamento per semaforo arriva in fase 3).
          ..sort(
            (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
          );
    final adesso = DateTime.now();
    final inAttesa = _inviti
        .where((i) => i.statoEffettivo(adesso) == StatoInvito.creato)
        .toList();
    final nessunPaziente = _pazienti.every(
      (p) => p.stato == StatoPaziente.invitato,
    );

    return RefreshIndicator(
      onRefresh: _carica,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_abbonamento?.piano == PianoAbbonamento.free) ...[
            const SponsorCard(),
            const SizedBox(height: 16),
          ],
          SelettorePillole<FiltroPazienti>(
            opzioni: [
              for (final f in FiltroPazienti.values)
                OpzioneSelettore(f, f.etichetta),
            ],
            selezionato: _filtro,
            onCambiato: (f) => setState(() => _filtro = f),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ricerca,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cerca per nome',
            ),
          ),
          const SizedBox(height: 16),
          if (nessunPaziente)
            StatoVuotoView(
              icona: Icons.group_add_outlined,
              titolo: 'Nessun paziente',
              messaggio: 'Invita il tuo primo paziente: riceverà un codice da inserire nell\'app.',
              etichettaAzione: 'Invita un paziente',
              onAzione: _invita,
            )
          else if (visibili.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nessun paziente con questo filtro.',
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final p in visibili) ...[
              _RigaPaziente(paziente: p, onTap: () => _azioniPaziente(p)),
              const SizedBox(height: 8),
            ],
          if (inAttesa.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Inviti in attesa',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final i in inAttesa) ...[
              RigaElenco(
                leading: const IconaTonale(
                  icona: Icons.mail_outline,
                  dimensione: 40,
                ),
                titolo: '${i.nome ?? 'Nuovo paziente'} · ${i.codice}',
                sottotitolo: 'Scade il ${_data(i.scadenza)}',
                trailing: TextButton(
                  onPressed: () => _revoca(i),
                  child: const Text('Revoca'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _RigaPaziente extends StatelessWidget {
  const _RigaPaziente({required this.paziente, required this.onTap});

  final PazienteElenco paziente;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final archiviato = paziente.stato == StatoPaziente.archiviato;
    final c = context.colori;
    return RigaElenco(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: archiviato ? c.bordo : c.primarioTonale,
        foregroundColor: archiviato ? c.testoSecondario : c.primario,
        child: Text(
          paziente.nome.isEmpty ? '?' : paziente.nome[0],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      titolo: paziente.nome,
      sottotitolo: 'Semaforo e ultimo check-in: fase 3',
      trailing: EtichettaStato(
        testo: paziente.stato.etichetta,
        tono: archiviato ? TonoStato.neutro : TonoStato.positivo,
      ),
    );
  }
}
