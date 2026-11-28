import 'package:material_ui/material_ui.dart';

import '../../../core/dipendenze.dart';
import '../../../core/tema/tema.dart';
import '../../../data/csv_piano_parser.dart';
import '../../../domain/modelli/alimento.dart';
import '../../../domain/modelli/piano_alimentare.dart';
import '../../../domain/regole/importazione_piano.dart';
import '../../../domain/repository/pazienti_repository.dart'
    show ErroreOperazione;
import '../../comuni/controlli.dart';
import '../alimenti/alimento_personalizzato_page.dart';
import '../alimenti/ricerca_alimento.dart' show formattaValore;
import 'aggiungi_alimento_page.dart';

/// Cosa restituisce l'importazione quando il nutrizionista conferma.
class RisultatoImportazione {
  const RisultatoImportazione({
    required this.piano,
    required this.righeImportate,
    required this.righeIgnorate,
  });

  /// Bozza non salvata: la assegna l'editor.
  final PianoAlimentare piano;
  final int righeImportate;
  final int righeIgnorate;
}

/// Ricerche in cache lanciate insieme: abbastanza per un piano settimanale in
/// pochi secondi (RNF_P_4), senza aprire centinaia di richieste con file grandi.
const int _ricercheInsieme = 8;

/// Stato di un nome di alimento letto dal file.
class _Voce {
  _Voce(this.nome);

  /// Il nome com'è scritto nella prima riga che lo usa.
  final String nome;

  /// Quante righe del file lo usano.
  int righe = 0;
  Alimento? alimento;
  bool cercando = true;
  bool ignorata = false;

  bool get risolta => ignorata || alimento != null;
}

/// "Importa da file" (RF_GP_10, RF_GP_11, UC_GP_5, SC_GP_3): scarico del
/// modello, scelta del CSV, anteprima con errori, abbinamento degli alimenti
/// e conferma.
///
/// Non scrive il piano: alla conferma si chiude restituendo una **bozza** che
/// l'editor apre, e solo "Salva e assegna" la rende una versione del paziente.
/// Annullando non si crea nulla.
class ImportaPianoPage extends StatefulWidget {
  const ImportaPianoPage({super.key, required this.dip});

  final Dipendenze dip;

  @override
  State<ImportaPianoPage> createState() => _ImportaPianoPageState();
}

class _ImportaPianoPageState extends State<ImportaPianoPage> {
  String? _nomeFile;
  EsitoCsvPiano? _esito;

  /// Alimenti del file, per nome normalizzato, nell'ordine di comparsa.
  Map<String, _Voce> _voci = {};

  /// Numeri delle righe errate che il nutrizionista ha scelto di ignorare.
  final _errateIgnorate = <int>{};

  String? _errore;
  VoidCallback? _riprova;
  bool _leggendo = false;
  bool _confermando = false;

  /// Cresce a ogni file: le ricerche di un file precedente si abbandonano.
  int _versione = 0;

  Future<void> _scaricaModello() async {
    try {
      final salvato = await widget.dip.fileCsv.salvaModello();
      if (!mounted || !salvato) return;
      _avviso('Modello salvato: compilalo e importalo da qui.');
    } on ErroreOperazione catch (e) {
      if (mounted) _avviso(e.messaggio);
    }
  }

  void _avviso(String testo) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(testo)));

  Future<void> _scegliFile() async {
    setState(() => _leggendo = true);
    try {
      final file = await widget.dip.fileCsv.scegli();
      if (!mounted) return;
      if (file == null) {
        setState(() => _leggendo = false);
        return;
      }
      final esito = leggiCsvPiano(file.bytes);
      final voci = <String, _Voce>{};
      for (final r in esito.righe) {
        voci
                .putIfAbsent(
                  normalizzaNome(r.alimento),
                  () => _Voce(r.alimento),
                )
                .righe +=
            1;
      }
      setState(() {
        _versione++;
        _nomeFile = file.nome;
        _esito = esito;
        _voci = voci;
        _errateIgnorate.clear();
        _errore = null;
        _leggendo = false;
      });
      _abbina();
    } on ErroreFileCsv catch (e) {
      _mostraErroreFile(e.messaggio);
    } on ErroreOperazione catch (e) {
      _mostraErroreFile(e.messaggio);
    }
  }

  /// Un file che non si può usare: nessuna anteprima (UC_GP_5, flusso 4.2).
  void _mostraErroreFile(String messaggio) {
    if (!mounted) return;
    setState(() {
      _versione++;
      _esito = null;
      _voci = {};
      _errore = messaggio;
      _riprova = null;
      _leggendo = false;
    });
  }

  /// Cerca un alimento per ogni nome: prima nella cache, **a gruppi in
  /// parallelo** (RNF_P_4), poi su Open Food Facts uno alla volta per i soli
  /// nomi mancanti, perché il servizio accetta poche richieste al minuto. La
  /// schermata resta usabile e mostra l'avanzamento.
  Future<void> _abbina() async {
    final versione = _versione;
    final alimenti = widget.dip.alimenti;
    bool superata() => !mounted || versione != _versione;
    setState(() {
      _errore = null;
      for (final v in _voci.values) {
        v.cercando = !v.risolta;
      }
    });
    final daCercare = _voci.values.where((v) => !v.risolta).toList();

    // Se nel frattempo l'ha scelto o ignorato il nutrizionista, vale la sua
    // decisione.
    void assegna(_Voce voce, Alimento? trovato) {
      if (!voce.risolta) voce.alimento = trovato;
    }

    try {
      for (var i = 0; i < daCercare.length; i += _ricercheInsieme) {
        await Future.wait(
          daCercare.skip(i).take(_ricercheInsieme).map((voce) async {
            final trovato = corrispondenzaEsatta(
              voce.nome,
              await alimenti.cercaInCache(voce.nome),
            );
            if (superata() || trovato == null) return;
            setState(() {
              assegna(voce, trovato);
              voce.cercando = false;
            });
          }),
        );
        if (superata()) return;
      }
      for (final voce in daCercare) {
        Alimento? trovato;
        if (!voce.risolta) {
          trovato = corrispondenzaEsatta(
            voce.nome,
            (await alimenti.cerca(voce.nome)).alimenti,
          );
          if (superata()) return;
        }
        if (voce.cercando) {
          setState(() {
            assegna(voce, trovato);
            voce.cercando = false;
          });
        }
      }
    } on ErroreOperazione catch (e) {
      if (superata()) return;
      setState(() {
        for (final v in _voci.values) {
          v.cercando = false;
        }
        _errore = 'Non riesco a cercare gli alimenti. ${e.messaggio}';
        _riprova = _abbina;
      });
    }
  }

  Future<void> _scegliAMano(_Voce voce) async {
    final scelto = await Navigator.of(context).push<Alimento>(
      MaterialPageRoute(
        builder: (_) => AggiungiAlimentoPage(
          alimenti: widget.dip.alimenti,
          etichettaConferma: 'Usa questo alimento',
          testoIniziale: voce.nome,
        ),
      ),
    );
    _assegna(voce, scelto);
  }

  Future<void> _crea(_Voce voce) async {
    final creato = await Navigator.of(context).push<Alimento>(
      MaterialPageRoute(
        builder: (_) => AlimentoPersonalizzatoPage(
          repository: widget.dip.alimenti,
          nomeIniziale: voce.nome,
        ),
      ),
    );
    _assegna(voce, creato);
  }

  void _assegna(_Voce voce, Alimento? alimento) {
    if (alimento == null || !mounted) return;
    setState(() {
      voce.alimento = alimento;
      voce.ignorata = false;
      voce.cercando = false;
    });
  }

  bool _inclusa(RigaCsvPiano r) =>
      _voci[normalizzaNome(r.alimento)]?.alimento != null &&
      !_voci[normalizzaNome(r.alimento)]!.ignorata;

  /// Perché non si può ancora confermare; `null` se si può.
  String? get _blocco {
    final esito = _esito!;
    if (_voci.values.any((v) => v.cercando && !v.risolta)) {
      return 'Sto ancora cercando gli alimenti.';
    }
    final errate = esito.errate
        .where((r) => !_errateIgnorate.contains(r.numero))
        .length;
    if (errate > 0) {
      return 'Correggi il file e ricaricalo, oppure ignora le righe con '
          'errori.';
    }
    if (_voci.values.any((v) => !v.risolta)) {
      return 'Abbina o ignora gli alimenti non trovati.';
    }
    if (!esito.righe.any(_inclusa)) {
      return 'Non resta nessuna riga da importare.';
    }
    return null;
  }

  /// Salva in cache gli alimenti scelti (serve il loro id) e chiude con la
  /// bozza. Se qualcosa fallisce non si restituisce nulla.
  Future<void> _conferma() async {
    final esito = _esito!;
    setState(() {
      _confermando = true;
      _errore = null;
    });
    try {
      final salvati = <String, Alimento>{};
      final righe = <(RigaCsvPiano, Alimento)>[];
      for (final r in esito.righe.where(_inclusa)) {
        final chiave = normalizzaNome(r.alimento);
        salvati[chiave] ??= await widget.dip.alimenti.scegli(
          _voci[chiave]!.alimento!,
        );
        righe.add((r, salvati[chiave]!));
      }
      if (!mounted) return;
      final oggi = DateTime.now();
      Navigator.of(context).pop(
        RisultatoImportazione(
          piano: costruisciBozza(
            righe,
            dataInizio: DateTime(oggi.year, oggi.month, oggi.day),
          ),
          righeImportate: righe.length,
          righeIgnorate:
              esito.righe.length + esito.errate.length - righe.length,
        ),
      );
    } on ErroreOperazione catch (e) {
      if (!mounted) return;
      setState(() {
        _confermando = false;
        _errore = e.messaggio;
        _riprova = _conferma;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esito = _esito;
    return Scaffold(
      appBar: AppBar(title: const Text('Importa piano')),
      body: SafeArea(
        child: ListView(
          // Un elenco nuovo per ogni file: si riparte dall'alto, dove stanno
          // riepilogo e avanzamento.
          key: ValueKey('importa-$_versione'),
          padding: const EdgeInsets.all(16),
          children: [
            if (_errore != null) ...[
              MessaggioErrore(messaggio: _errore!, onRiprova: _riprova),
              const SizedBox(height: 12),
            ],
            if (esito == null) ..._inizio() else ..._anteprima(esito),
          ],
        ),
      ),
    );
  }

  /// Prima di avere un file: cosa serve, modello e scelta.
  List<Widget> _inizio() {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    return [
      Text('Importa un piano da un file CSV', style: testo.titleLarge),
      const SizedBox(height: 8),
      Text(
        'Compila il modello al computer (colonne giorno, pasto, alimento, '
        'quantita_g, note), salvalo come "CSV UTF-8" e sceglilo qui. Vedrai '
        'un\'anteprima: nulla viene assegnato senza la tua conferma.',
        style: testo.bodyLarge?.copyWith(color: c.testoSecondario),
      ),
      const SizedBox(height: 20),
      PulsantePrimario(
        etichetta: 'Scegli file CSV',
        inCorso: _leggendo,
        onPressed: _scegliFile,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _scaricaModello,
        icon: const Icon(Icons.download),
        label: const Text('Scarica modello CSV'),
      ),
    ];
  }

  List<Widget> _anteprima(EsitoCsvPiano esito) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final daAbbinare = _voci.values
        .where((v) => !v.cercando && !v.risolta)
        .length;
    final cercate = _voci.values.where((v) => !v.cercando).length;
    final blocco = _blocco;
    String conta(int n, String uno, String molti) =>
        '$n ${n == 1 ? uno : molti}';

    return [
      Text(_nomeFile ?? '', style: testo.titleMedium),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(
            label: Text(
              conta(
                esito.righe.length,
                'riga riconosciuta',
                'righe riconosciute',
              ),
            ),
          ),
          Chip(
            label: Text(
              conta(daAbbinare, 'alimento da abbinare', 'alimenti da abbinare'),
            ),
          ),
          Chip(
            label: Text(
              conta(esito.errate.length, 'riga con errori', 'righe con errori'),
            ),
          ),
        ],
      ),
      if (cercate < _voci.length) ...[
        const SizedBox(height: 12),
        Text('Cerco gli alimenti… $cercate di ${_voci.length}'),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: cercate / _voci.length),
      ],
      if (esito.errate.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('Righe con errori', style: testo.titleMedium),
        for (final r in esito.errate) _rigaErrata(r),
      ],
      const SizedBox(height: 20),
      Text('Alimenti', style: testo.titleMedium),
      for (final e in _voci.entries) _cardAlimento(e.key, e.value),
      if (esito.righe.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('Righe del file', style: testo.titleMedium),
        const SizedBox(height: 4),
        for (final r in esito.righe)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Riga ${r.numero} · ${GiorniSettimana.abbreviato(r.giorno)} · '
              '${r.pasto.etichetta} · ${r.alimento} · '
              '${formattaValore(r.quantitaG)} g'
              '${r.note.isEmpty ? '' : ' · ${r.note}'}',
              style: testo.bodyMedium?.copyWith(
                color: _voci[normalizzaNome(r.alimento)]!.ignorata
                    ? c.testoSecondario
                    : null,
                decoration: _voci[normalizzaNome(r.alimento)]!.ignorata
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
        if (esito.righe.any((r) => r.note.isNotEmpty))
          Text(
            'Le note non vengono salvate nel piano.',
            style: testo.bodySmall?.copyWith(color: c.testoSecondario),
          ),
      ],
      const SizedBox(height: 24),
      if (blocco != null) ...[
        Text(blocco, style: testo.bodyMedium?.copyWith(color: c.avviso)),
        const SizedBox(height: 8),
      ],
      PulsantePrimario(
        key: const Key('crea-bozza'),
        etichetta: 'Crea bozza',
        inCorso: _confermando,
        onPressed: blocco == null ? _conferma : null,
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _confermando ? null : _scegliFile,
        icon: const Icon(Icons.upload_file),
        label: const Text('Scegli un altro file'),
      ),
    ];
  }

  /// Una riga che il parser ha rifiutato, con colonna e motivo.
  Widget _rigaErrata(RigaCsvErrata r) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final ignorata = _errateIgnorate.contains(r.numero);
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: ignorata ? null : c.erroreTonale,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ignorata ? 'Riga ${r.numero} · ignorata' : 'Riga ${r.numero}',
              style: testo.titleSmall,
            ),
            Text(
              r.testo,
              style: testo.bodySmall?.copyWith(color: c.testoSecondario),
            ),
            for (final e in r.errori) Text('${e.colonna}: ${e.motivo}'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: Key('ignora-riga-${r.numero}'),
                onPressed: () => setState(
                  () => ignorata
                      ? _errateIgnorate.remove(r.numero)
                      : _errateIgnorate.add(r.numero),
                ),
                child: Text(ignorata ? 'Ripristina' : 'Ignora riga'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Un nome del file con l'alimento abbinato o le scelte possibili.
  Widget _cardAlimento(String chiave, _Voce v) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final a = v.alimento;
    final String stato;
    if (v.ignorata) {
      stato = 'Ignorato: le sue righe non si importano.';
    } else if (a != null) {
      final marca = a.marca == null ? '' : ' (${a.marca})';
      stato =
          'Abbinato a ${a.nome}$marca · '
          '${formattaValore(a.kcal100g ?? 0)} kcal per 100 g';
    } else if (v.cercando) {
      stato = 'Ricerca in corso…';
    } else {
      stato = 'Non trovato: scegli un alimento, crealo o ignora.';
    }
    return Card(
      margin: const EdgeInsets.only(top: 8),
      color: !v.risolta && !v.cercando ? c.avvisoTonale : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${v.nome}" · ${v.righe} ${v.righe == 1 ? 'riga' : 'righe'}',
              style: testo.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(stato),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: _confermando ? null : () => _scegliAMano(v),
                    child: Text(a == null ? 'Scegli' : 'Cambia'),
                  ),
                  if (a == null)
                    TextButton(
                      onPressed: _confermando ? null : () => _crea(v),
                      child: const Text('Crea'),
                    ),
                  TextButton(
                    key: Key('ignora-alimento-$chiave'),
                    onPressed: _confermando
                        ? null
                        : () => setState(() {
                            v.ignorata = !v.ignorata;
                            v.cercando = false;
                          }),
                    child: Text(v.ignorata ? 'Ripristina' : 'Ignora'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
