import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tema/tema.dart';
import '../../../domain/modelli/alimento.dart';
import '../../../domain/repository/alimenti_repository.dart';
import '../../../domain/repository/pazienti_repository.dart';
import '../../comuni/componenti.dart';
import '../../comuni/segnaposto_page.dart';
import '../../comuni/stati_view.dart';

/// Pagina di Open Food Facts da aprire con il link di attribuzione (ODbL).
final Uri indirizzoOpenFoodFacts = Uri.parse(
  'https://world.openfoodfacts.org/',
);

/// Valore con una cifra decimale al massimo e la virgola: `9`, `41,2`.
String formattaValore(double v) => v == v.roundToDouble()
    ? v.toInt().toString()
    : v.toStringAsFixed(1).replaceAll('.', ',');

/// Ricerca di un alimento riutilizzabile (UC_GP_3): campo con attesa di
/// 400 ms prima di cercare, recenti e preferiti a campo vuoto, risultati con
/// kcal e macro per 100 g, stato vuoto, errore con "Riprova" e attribuzione
/// "Dati: Open Food Facts (ODbL)" sempre visibile (RNF_L_5).
class RicercaAlimento extends StatefulWidget {
  const RicercaAlimento({
    super.key,
    required this.repository,
    required this.onScelto,
    this.onCreaPersonalizzato,
    this.onScansiona,
    this.apriLink,
    this.testoIniziale,
  });

  final AlimentiRepository repository;

  /// Testo già nel campo all'apertura (importazione da file: il nome da
  /// abbinare), con la ricerca avviata.
  final String? testoIniziale;

  /// L'alimento scelto, già salvato nella cache.
  final ValueChanged<Alimento> onScelto;

  /// Apre il modulo dell'alimento personalizzato, con il testo cercato. Al
  /// ritorno la ricerca si aggiorna.
  final Future<void> Function(String testo)? onCreaPersonalizzato;

  /// Apre la scansione del codice a barre (RF_GP_4): icona nel campo di
  /// ricerca. Restituisce vero se si torna a cercare per nome (il campo
  /// prende il fuoco).
  final Future<bool> Function()? onScansiona;

  /// Apre un indirizzo (di prova nei test); predefinito: browser del telefono.
  final Future<void> Function(Uri indirizzo)? apriLink;

  static const attesaDigitazione = Duration(milliseconds: 400);

  @override
  State<RicercaAlimento> createState() => _RicercaAlimentoState();
}

class _RicercaAlimentoState extends State<RicercaAlimento> {
  final _testo = TextEditingController();
  final _fuoco = FocusNode();
  Timer? _attesa;

  /// Cresce a ogni ricerca: le risposte di ricerche superate si scartano.
  int _versione = 0;
  bool _ultimaAnchePerOnline = false;
  RisultatoRicerca? _risultato;
  ErroreOperazione? _errore;
  bool _inCorso = false;
  List<Alimento> _recenti = const [];
  List<Alimento> _preferiti = const [];

  String get _termine => _testo.text.trim();
  bool get _pronto => _termine.length >= 2;

  @override
  void initState() {
    super.initState();
    _caricaElenchi();
    final iniziale = widget.testoIniziale?.trim() ?? '';
    if (iniziale.isNotEmpty) {
      _testo.text = iniziale;
      // Dopo il primo frame: la ricerca chiama setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _alCambio(iniziale);
      });
    }
  }

  @override
  void dispose() {
    _attesa?.cancel();
    _testo.dispose();
    _fuoco.dispose();
    super.dispose();
  }

  Future<void> _caricaElenchi() async {
    try {
      final recenti = await widget.repository.recenti();
      final preferiti = await widget.repository.preferiti();
      if (!mounted) return;
      setState(() {
        _recenti = recenti;
        _preferiti = preferiti;
      });
    } on ErroreOperazione {
      // Recenti e preferiti sono un di più: la ricerca funziona comunque.
    }
  }

  void _alCambio(String _) {
    _attesa?.cancel();
    // Con il testo nuovo le risposte delle ricerche precedenti non valgono più.
    _versione++;
    if (!_pronto) {
      setState(() {
        _risultato = null;
        _errore = null;
        _inCorso = false;
      });
      if (_termine.isEmpty) _caricaElenchi();
      return;
    }
    setState(() => _inCorso = false); // aggiorna anche il pulsante "cancella"
    _attesa = Timer(RicercaAlimento.attesaDigitazione, _cerca);
  }

  Future<void> _cerca({bool anchePerOnline = false}) async {
    final termine = _termine;
    if (termine.length < 2) return;
    _ultimaAnchePerOnline = anchePerOnline;
    final versione = ++_versione;
    setState(() {
      _inCorso = true;
      _errore = null;
    });
    try {
      final r = await widget.repository.cerca(
        termine,
        anchePerOnline: anchePerOnline,
        // Con il servizio lento si vede subito la cache, poi arriva il resto.
        alRisultatoDallaCache: (dallaCache) {
          if (!mounted || versione != _versione) return;
          setState(() => _risultato = dallaCache);
        },
      );
      if (!mounted || versione != _versione) return;
      setState(() {
        _risultato = r;
        _inCorso = false;
      });
    } on ErroreOperazione catch (e) {
      if (!mounted || versione != _versione) return;
      setState(() {
        _errore = e;
        _inCorso = false;
      });
    }
  }

  Future<void> _scegli(Alimento a) async {
    if (!a.completo) {
      await _chiediCompletamento(a);
      return;
    }
    try {
      final salvato = await widget.repository.scegli(a);
      if (!mounted) return;
      widget.onScelto(salvato);
      _caricaElenchi();
    } on ErroreOperazione catch (e) {
      _avvisa(e.messaggio);
    }
  }

  Future<void> _chiediCompletamento(Alimento a) async {
    final completa = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Dati nutrizionali incompleti'),
        content: Text(
          'Open Food Facts non ha tutti i valori di «${a.nome}». Non lo salvo '
          'come completo: puoi inserirlo a mano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Completa a mano'),
          ),
        ],
      ),
    );
    if (completa == true) await _creaPersonalizzato(a.nome);
  }

  Future<void> _creaPersonalizzato(String testo) async {
    final crea = widget.onCreaPersonalizzato;
    if (crea == null) return;
    await crea(testo);
    if (!mounted) return;
    _caricaElenchi();
    if (_pronto) _cerca();
  }

  Future<void> _scansiona() async {
    final cercaPerNome = await widget.onScansiona!();
    if (!mounted) return;
    _caricaElenchi();
    if (cercaPerNome) _fuoco.requestFocus();
  }

  Future<void> _stella(Alimento a) async {
    final nuovo = !a.preferito;
    try {
      await widget.repository.impostaPreferito(a, nuovo);
      if (!mounted) return;
      setState(() {
        final r = _risultato;
        if (r != null) {
          _risultato = RisultatoRicerca(
            alimenti: [
              for (final x in r.alimenti)
                identical(x, a) ? x.copyWith(preferito: nuovo) : x,
            ],
            onlineNonDisponibile: r.onlineNonDisponibile,
            onlineSaltato: r.onlineSaltato,
            durata: r.durata,
          );
        }
      });
      _caricaElenchi();
    } on ErroreOperazione catch (e) {
      _avvisa(e.messaggio);
    }
  }

  void _avvisa(String messaggio) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(messaggio)));
  }

  Future<void> _apri(Uri indirizzo) async {
    final apri = widget.apriLink;
    if (apri != null) {
      try {
        await apri(indirizzo);
      } on Exception {
        _avvisa('Non riesco ad aprire il link.');
      }
      return;
    }
    try {
      final aperto = await launchUrl(
        indirizzo,
        mode: LaunchMode.externalApplication,
      );
      if (!aperto) _avvisa('Non riesco ad aprire il link.');
    } on Exception {
      _avvisa('Non riesco ad aprire il link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _testo,
            focusNode: _fuoco,
            onChanged: _alCambio,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Cerca un alimento per nome',
              suffixIcon: _testo.text.isEmpty && widget.onScansiona == null
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_testo.text.isNotEmpty)
                          IconButton(
                            tooltip: 'Cancella',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _testo.clear();
                              _alCambio('');
                            },
                          ),
                        if (widget.onScansiona != null)
                          IconButton(
                            tooltip: 'Scansiona il codice a barre',
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: _scansiona,
                          ),
                      ],
                    ),
            ),
          ),
        ),
        if (_inCorso) const LinearProgressIndicator(minHeight: 3),
        Expanded(child: _corpo()),
        SafeArea(
          top: false,
          child: TextButton(
            onPressed: () => _apri(indirizzoOpenFoodFacts),
            child: const Text('Dati: Open Food Facts (ODbL)'),
          ),
        ),
      ],
    );
  }

  Widget _corpo() {
    if (_errore != null) {
      return ErroreView(
        messaggio: _errore!.messaggio,
        onRiprova: () => _cerca(anchePerOnline: _ultimaAnchePerOnline),
      );
    }
    if (!_pronto) return _elenchi();
    final r = _risultato;
    if (r == null) return const SizedBox.shrink();
    return _risultati(r);
  }

  Widget _elenchi() {
    if (_preferiti.isEmpty && _recenti.isEmpty) {
      return StatoVuotoView(
        icona: Icons.search,
        titolo: 'Cerca un alimento',
        messaggio:
            'Scrivi il nome: cerco prima tra gli alimenti già usati, poi su '
            'Open Food Facts.',
        etichettaAzione: widget.onCreaPersonalizzato == null
            ? null
            : 'Crea alimento personalizzato',
        onAzione: widget.onCreaPersonalizzato == null
            ? null
            : () => _creaPersonalizzato(''),
      );
    }
    // Un alimento preferito sta solo tra i preferiti.
    final recenti = _recenti.where((a) => !a.preferito).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (_preferiti.isNotEmpty) ...[
          const _Titolo('Preferiti'),
          for (final a in _preferiti) _riga(a),
        ],
        if (recenti.isNotEmpty) ...[
          const _Titolo('Usati di recente'),
          for (final a in recenti) _riga(a),
        ],
        if (widget.onCreaPersonalizzato != null)
          _PulsanteCrea(onPressed: () => _creaPersonalizzato('')),
      ],
    );
  }

  Widget _risultati(RisultatoRicerca r) {
    final colori = context.colori;
    final testo = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        if (r.onlineNonDisponibile)
          Card(
            color: colori.avvisoTonale,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Non riesco a contattare Open Food Facts: ti mostro gli alimenti '
                'già salvati.',
                style: testo.bodyMedium,
              ),
            ),
          ),
        if (r.onlineSaltato)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _cerca(anchePerOnline: true),
              icon: const Icon(Icons.travel_explore),
              label: const Text('Cerca anche online'),
            ),
          ),
        if (r.alimenti.isEmpty && !_inCorso)
          StatoVuotoView(
            icona: Icons.search_off,
            titolo: 'Nessun alimento trovato',
            messaggio: 'Prova con un altro nome, oppure inseriscilo tu.',
            etichettaAzione: widget.onCreaPersonalizzato == null
                ? null
                : 'Crea alimento personalizzato',
            onAzione: widget.onCreaPersonalizzato == null
                ? null
                : () => _creaPersonalizzato(_termine),
          )
        else ...[
          for (final a in r.alimenti) _riga(a),
          if (widget.onCreaPersonalizzato != null)
            _PulsanteCrea(onPressed: () => _creaPersonalizzato(_termine)),
        ],
      ],
    );
  }

  Widget _riga(Alimento a) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: _RigaAlimento(
      alimento: a,
      onTap: () => _scegli(a),
      onStella: () => _stella(a),
    ),
  );
}

class _Titolo extends StatelessWidget {
  const _Titolo(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
    child: Text(testo, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _PulsanteCrea extends StatelessWidget {
  const _PulsanteCrea({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: const Text('Crea alimento personalizzato'),
    ),
  );
}

class _RigaAlimento extends StatelessWidget {
  const _RigaAlimento({
    required this.alimento,
    required this.onTap,
    required this.onStella,
  });

  final Alimento alimento;
  final VoidCallback onTap;
  final VoidCallback onStella;

  String get _sottotitolo {
    final a = alimento;
    final marca = a.marca == null ? '' : '${a.marca} · ';
    if (!a.completo) return '${marca}Mancano alcuni valori nutrizionali';
    return '$marca${formattaValore(a.kcal100g!)} kcal · '
        'P ${formattaValore(a.proteine100g!)} g · '
        'C ${formattaValore(a.carboidrati100g!)} g · '
        'G ${formattaValore(a.grassi100g!)} g · per 100 g';
  }

  @override
  Widget build(BuildContext context) {
    final colori = context.colori;
    return RigaElenco(
      titolo: alimento.nome,
      sottotitolo: _sottotitolo,
      onTap: onTap,
      trailing: alimento.completo
          ? IconButton(
              tooltip: alimento.preferito
                  ? 'Togli dai preferiti'
                  : 'Aggiungi ai preferiti',
              icon: Icon(
                alimento.preferito ? Icons.star : Icons.star_border,
                color: alimento.preferito
                    ? colori.avviso
                    : colori.testoSecondario,
              ),
              onPressed: onStella,
            )
          : const EtichettaStato(
              testo: 'Dati incompleti',
              tono: TonoStato.attenzione,
            ),
    );
  }
}
