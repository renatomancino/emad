import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tema/tema.dart';
import '../../../data/dispositivo/permesso_fotocamera.dart';
import '../../../domain/modelli/alimento.dart';
import '../../../domain/regole/codice_barre.dart';
import '../../../domain/repository/alimenti_repository.dart';
import '../../../domain/repository/pazienti_repository.dart';
import '../../comuni/componenti.dart';
import '../../comuni/controlli.dart';
import '../../comuni/stati_view.dart';
import 'alimento_personalizzato_page.dart';
import 'anteprima_simulata.dart';
import 'ricerca_alimento.dart' show formattaValore, indirizzoOpenFoodFacts;

/// Che cosa restituisce la scansione a chi l'ha aperta.
class RisultatoScansione {
  /// L'alimento da aggiungere al pasto, già salvato nella cache con fonte e
  /// codice a barre (o creato a mano con il codice).
  const RisultatoScansione.alimento(Alimento this.alimento)
    : cercaPerNome = false;

  /// Il nutrizionista preferisce la ricerca per nome (anche a permesso negato).
  const RisultatoScansione.cercaPerNome()
    : alimento = null,
      cercaPerNome = true;

  final Alimento? alimento;
  final bool cercaPerNome;
}

/// Perché l'anteprima della fotocamera non è partita.
enum ErroreFotocamera { permessoNegato, nonDisponibile }

/// Costruisce l'anteprima della fotocamera. Quella vera usa `mobile_scanner`;
/// nei test se ne passa una finta che "legge" un codice a comando.
typedef CostruttoreAnteprima = Widget Function(
  BuildContext context, {
  required void Function(String grezzo, bool upcE) onLetto,
  required void Function(ErroreFotocamera errore) onErrore,
});

enum _Fase {
  verifica,
  spiegazione,
  scansione,
  negato,
  nonDisponibile,
  ricerca,
  esito,
  errore,
}

/// Scansione del codice a barre di un prodotto (RF_GP_4, UC_GP_3, SC_GP_2,
/// SD_2, RNF_IN_3).
///
/// Spiega il permesso prima che il sistema lo chieda; con il permesso negato
/// propone la ricerca per nome e come riattivarlo. Letto un codice, chiude la
/// fotocamera e lo cerca prima nella cache e poi su Open Food Facts: se lo
/// trova mostra nome e valori per 100 g con "Aggiungi al pasto", altrimenti
/// propone "Inserisci a mano" con il codice già scritto.
class ScansioneCodicePage extends StatefulWidget {
  const ScansioneCodicePage({
    super.key,
    required this.repository,
    this.etichettaConferma = 'Aggiungi al pasto',
    this.permesso,
    this.anteprima,
    this.apriLink,
  });

  final AlimentiRepository repository;

  /// Testo del pulsante che conferma il prodotto trovato.
  final String etichettaConferma;

  /// Predefinito: il canale nativo di Android.
  final PermessoFotocamera? permesso;

  /// Predefinita: la fotocamera vera con `mobile_scanner`.
  final CostruttoreAnteprima? anteprima;

  /// Con `CENATO_RUOLO_FINTO` (demo senza Supabase, browser, simulatore) la
  /// fotocamera è simulata: il catalogo finto non ha prodotti veri.
  static const modoFinto = String.fromEnvironment('CENATO_RUOLO_FINTO') != '';

  /// Apre un indirizzo (di prova nei test); predefinito: browser del telefono.
  final Future<void> Function(Uri indirizzo)? apriLink;

  @override
  State<ScansioneCodicePage> createState() => _ScansioneCodicePageState();
}

class _ScansioneCodicePageState extends State<ScansioneCodicePage>
    with WidgetsBindingObserver {
  final _filtro = FiltroLetture();
  late final PermessoFotocamera _permesso =
      widget.permesso ??
      (ScansioneCodicePage.modoFinto
          ? PermessoFotocameraSimulato()
          : const PermessoFotocameraNativo());
  _Fase _fase = _Fase.verifica;
  String? _codice;
  EsitoCodiceBarre? _esito;
  ErroreOperazione? _errore;
  bool _aggiunta = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificaPermesso();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Di ritorno dalle impostazioni: se ora il permesso c'è, si riparte.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _fase == _Fase.negato) {
      _verificaPermesso(soloSeConcesso: true);
    }
  }

  Future<void> _verificaPermesso({bool soloSeConcesso = false}) async {
    final concesso = await _permesso.concesso();
    if (!mounted) return;
    if (concesso) {
      setState(() => _fase = _Fase.scansione);
    } else if (!soloSeConcesso) {
      setState(() => _fase = _Fase.spiegazione);
    }
  }

  void _alLetto(String grezzo, bool upcE) {
    if (_fase != _Fase.scansione) return;
    final codice = CodiceBarre.normalizza(grezzo, upcE: upcE);
    // Lettura sporca: si continua a inquadrare.
    if (codice == null || !_filtro.accetta(codice)) return;
    HapticFeedback.mediumImpact();
    _cerca(codice);
  }

  void _alErrore(ErroreFotocamera errore) {
    if (!mounted || _fase != _Fase.scansione) return;
    setState(
      () => _fase = errore == ErroreFotocamera.permessoNegato
          ? _Fase.negato
          : _Fase.nonDisponibile,
    );
  }

  /// Togliere l'anteprima dall'albero chiude la fotocamera.
  Future<void> _cerca(String codice) async {
    setState(() {
      _fase = _Fase.ricerca;
      _codice = codice;
      _esito = null;
      _errore = null;
    });
    try {
      final esito = await widget.repository.perCodiceBarre(codice);
      if (!mounted || _codice != codice) return;
      setState(() {
        _esito = esito;
        _fase = _Fase.esito;
      });
    } on ErroreOperazione catch (e) {
      if (!mounted || _codice != codice) return;
      setState(() {
        _errore = e;
        _fase = _Fase.errore;
      });
    }
  }

  void _scansionaDiNuovo() => setState(() {
    _fase = _Fase.scansione;
    _esito = null;
    _errore = null;
  });

  void _cercaPerNome() =>
      Navigator.of(context).pop(const RisultatoScansione.cercaPerNome());

  Future<void> _aggiungi(Alimento alimento) async {
    setState(() {
      _aggiunta = true;
      _errore = null;
    });
    try {
      final salvato = await widget.repository.scegli(alimento);
      if (mounted) {
        Navigator.of(context).pop(RisultatoScansione.alimento(salvato));
      }
    } on ErroreOperazione catch (e) {
      // Il prodotto resta sullo schermo: si riprova senza riscansionare.
      if (mounted) setState(() => _errore = e);
    } finally {
      if (mounted) setState(() => _aggiunta = false);
    }
  }

  Future<void> _inserisciAMano({Alimento? iniziale}) async {
    final creato = await Navigator.of(context).push<Alimento>(
      MaterialPageRoute(
        builder: (_) => AlimentoPersonalizzatoPage(
          repository: widget.repository,
          codiceBarre: _codice,
          iniziale: iniziale,
        ),
      ),
    );
    if (creato != null && mounted) {
      Navigator.of(context).pop(RisultatoScansione.alimento(creato));
    }
  }

  Future<void> _apri(Uri indirizzo) async {
    try {
      final apri = widget.apriLink;
      if (apri != null) {
        await apri(indirizzo);
      } else {
        await launchUrl(indirizzo, mode: LaunchMode.externalApplication);
      }
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Non riesco ad aprire il link.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scura = _fase == _Fase.scansione;
    final c = context.colori;
    return Scaffold(
      backgroundColor: scura ? c.fotocamera : null,
      appBar: AppBar(
        title: const Text('Scansiona codice a barre'),
        backgroundColor: scura ? c.fotocamera : null,
        foregroundColor: scura ? c.sullaFotocamera : null,
        titleTextStyle: scura
            ? Theme.of(context).appBarTheme.titleTextStyle
                  ?.copyWith(color: c.sullaFotocamera)
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _corpo()),
            if (!scura)
              TextButton(
                onPressed: () => _apri(indirizzoOpenFoodFacts),
                child: const Text('Dati: Open Food Facts (ODbL)'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _corpo() => switch (_fase) {
    _Fase.verifica => const SizedBox.shrink(),
    _Fase.spiegazione => _Avviso(
      icona: Icons.photo_camera_outlined,
      titolo: 'Serve la fotocamera',
      messaggio:
          'Cenato usa la fotocamera solo per leggere il codice a barre del '
          'prodotto: le immagini non vengono salvate né inviate. Il telefono '
          'ti chiederà il permesso.',
      principale: ('Consenti fotocamera', _scansionaDiNuovo),
      secondaria: ('Cerca per nome', _cercaPerNome),
    ),
    _Fase.scansione => _Inquadratura(
      anteprima:
          (widget.anteprima ??
          (ScansioneCodicePage.modoFinto
              ? anteprimaSimulata
              : _anteprimaMobileScanner))(
            context,
            onLetto: _alLetto,
            onErrore: _alErrore,
          ),
      onCercaPerNome: _cercaPerNome,
    ),
    _Fase.negato => _Avviso(
      icona: Icons.no_photography_outlined,
      tono: TonoStato.attenzione,
      titolo: 'Fotocamera non consentita',
      messaggio:
          'Senza il permesso non posso leggere il codice a barre. Cerca '
          'l\'alimento per nome, oppure consenti la fotocamera in '
          'Impostazioni › App › Cenato › Autorizzazioni.',
      principale: ('Cerca per nome', _cercaPerNome),
      secondaria: ('Apri impostazioni', _permesso.apriImpostazioni),
    ),
    _Fase.nonDisponibile => _Avviso(
      icona: Icons.no_photography_outlined,
      tono: TonoStato.attenzione,
      titolo: 'Fotocamera non disponibile',
      messaggio:
          'Non riesco ad avviare la fotocamera su questo dispositivo. Cerca '
          'l\'alimento per nome.',
      principale: ('Cerca per nome', _cercaPerNome),
      secondaria: ('Riprova', _scansionaDiNuovo),
    ),
    _Fase.ricerca => CaricamentoView(messaggio: 'Cerco il codice $_codice…'),
    _Fase.errore when _esito == null => ErroreView(
      messaggio: _errore!.messaggio,
      onRiprova: () => _cerca(_codice!),
    ),
    _Fase.esito || _Fase.errore => _vistaEsito(_esito!),
  };

  Widget _vistaEsito(EsitoCodiceBarre esito) => switch (esito) {
    CodiceTrovato(:final alimento, :final daCache) => _ProdottoTrovato(
      alimento: alimento,
      daCache: daCache,
      etichettaConferma: widget.etichettaConferma,
      inCorso: _aggiunta,
      errore: _errore,
      onAggiungi: () => _aggiungi(alimento),
      onScansiona: _scansionaDiNuovo,
    ),
    CodiceIncompleto(:final alimento) => _Avviso(
      icona: Icons.rule,
      tono: TonoStato.attenzione,
      titolo: 'Dati nutrizionali incompleti',
      messaggio:
          'Open Food Facts conosce «${alimento.nome}» (codice ${esito.codice}) '
          'ma non ha tutti i valori. Completali leggendo l\'etichetta.',
      principale: (
        'Inserisci a mano',
        () => _inserisciAMano(iniziale: alimento),
      ),
      secondaria: ('Scansiona di nuovo', _scansionaDiNuovo),
      terziaria: ('Cerca per nome', _cercaPerNome),
    ),
    CodiceNonTrovato() => _Avviso(
      icona: Icons.search_off,
      titolo: 'Prodotto non trovato',
      messaggio:
          'Il codice ${esito.codice} non è su Open Food Facts. Inseriscilo a '
          'mano con i valori dell\'etichetta: la prossima volta lo ritrovi '
          'scansionandolo.',
      principale: ('Inserisci a mano', _inserisciAMano),
      secondaria: ('Scansiona di nuovo', _scansionaDiNuovo),
      terziaria: ('Cerca per nome', _cercaPerNome),
    ),
    CodiceServizioNonDisponibile() => _Avviso(
      icona: Icons.cloud_off_outlined,
      tono: TonoStato.attenzione,
      titolo: 'Open Food Facts non risponde',
      messaggio:
          'Non riesco a cercare il codice ${esito.codice}. Controlla la '
          'connessione e riprova, oppure inserisci il prodotto a mano.',
      principale: ('Riprova', () => _cerca(esito.codice)),
      secondaria: ('Inserisci a mano', _inserisciAMano),
      terziaria: ('Cerca per nome', _cercaPerNome),
    ),
  };

  Widget _anteprimaMobileScanner(
    BuildContext context, {
    required void Function(String grezzo, bool upcE) onLetto,
    required void Function(ErroreFotocamera errore) onErrore,
  }) => _AnteprimaMobileScanner(onLetto: onLetto, onErrore: onErrore);
}

/// Anteprima con cornice, suggerimento e "Cerca per nome" sempre a portata.
class _Inquadratura extends StatelessWidget {
  const _Inquadratura({required this.anteprima, required this.onCercaPerNome});

  final Widget anteprima;
  final VoidCallback onCercaPerNome;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    return Stack(
      fit: StackFit.expand,
      children: [
        anteprima,
        IgnorePointer(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.8,
              child: AspectRatio(
                aspectRatio: 1.8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: c.sullaFotocamera, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.fotocamera.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    'Inquadra il codice a barre del prodotto dentro la cornice',
                    textAlign: TextAlign.center,
                    style: testo.bodyMedium?.copyWith(color: c.sullaFotocamera),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onCercaPerNome,
                icon: const Icon(Icons.search),
                label: const Text('Cerca per nome'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fotocamera vera: EAN-13, EAN-8, UPC-A e UPC-E, torcia, pausa quando l'app
/// va in secondo piano. Togliere il widget chiude la fotocamera.
class _AnteprimaMobileScanner extends StatefulWidget {
  const _AnteprimaMobileScanner({
    required this.onLetto,
    required this.onErrore,
  });

  final void Function(String grezzo, bool upcE) onLetto;
  final void Function(ErroreFotocamera errore) onErrore;

  @override
  State<_AnteprimaMobileScanner> createState() =>
      _AnteprimaMobileScannerState();
}

class _AnteprimaMobileScannerState extends State<_AnteprimaMobileScanner>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    // Lo stesso codice non viene riportato di continuo.
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _erroreSegnalato = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_alCambioStato);
  }

  void _alCambioStato() {
    final errore = _controller.value.error;
    if (errore == null || _erroreSegnalato) return;
    _erroreSegnalato = true;
    widget.onErrore(
      errore.errorCode == MobileScannerErrorCode.permissionDenied
          ? ErroreFotocamera.permessoNegato
          : ErroreFotocamera.nonDisponibile,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Il dialogo del permesso cambia lo stato dell'app prima che la
    // fotocamera sia pronta: in quel caso non si tocca nulla.
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_alCambioStato);
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _alRilevamento(BarcodeCapture cattura) {
    for (final codice in cattura.barcodes) {
      final grezzo = codice.rawValue;
      if (grezzo == null) continue;
      widget.onLetto(grezzo, codice.format == BarcodeFormat.upcE);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _alRilevamento,
          // Gli errori diventano le schermate della pagina (permesso negato,
          // fotocamera assente): qui resta il fondo nero.
          errorBuilder: (context, _) =>
              ColoredBox(color: context.colori.fotocamera),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, stato, _) {
              if (!stato.isRunning ||
                  stato.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final accesa = stato.torchState == TorchState.on;
              return IconButton.filledTonal(
                tooltip: accesa ? 'Spegni la torcia' : 'Accendi la torcia',
                iconSize: 28,
                onPressed: () => unawaited(_controller.toggleTorch()),
                icon: Icon(accesa ? Icons.flashlight_off : Icons.flashlight_on),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Messaggio a pagina intera con fino a tre azioni.
class _Avviso extends StatelessWidget {
  const _Avviso({
    required this.icona,
    required this.titolo,
    required this.messaggio,
    required this.principale,
    this.secondaria,
    this.terziaria,
    this.tono,
  });

  final IconData icona;
  final String titolo;
  final String messaggio;
  final (String, VoidCallback) principale;
  final (String, VoidCallback)? secondaria;
  final (String, VoidCallback)? terziaria;
  final TonoStato? tono;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final attenzione = tono == TonoStato.attenzione;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconaTonale(
                icona: icona,
                dimensione: 80,
                colore: attenzione ? c.avviso : null,
                sfondo: attenzione ? c.avvisoTonale : null,
              ),
              const SizedBox(height: 20),
              Text(
                titolo,
                textAlign: TextAlign.center,
                style: testo.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                messaggio,
                textAlign: TextAlign.center,
                style: testo.bodyLarge?.copyWith(color: c.testoSecondario),
              ),
              const SizedBox(height: 24),
              PulsantePrimario(
                etichetta: principale.$1,
                onPressed: principale.$2,
              ),
              if (secondaria case (final etichetta, final azione)) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: azione,
                    child: Text(etichetta),
                  ),
                ),
              ],
              if (terziaria case (final etichetta, final azione)) ...[
                const SizedBox(height: 4),
                TextButton(onPressed: azione, child: Text(etichetta)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Il prodotto letto: nome, marca e valori per 100 g (SC_GP_2, passo 2).
class _ProdottoTrovato extends StatelessWidget {
  const _ProdottoTrovato({
    required this.alimento,
    required this.daCache,
    required this.etichettaConferma,
    required this.inCorso,
    required this.errore,
    required this.onAggiungi,
    required this.onScansiona,
  });

  final Alimento alimento;
  final bool daCache;
  final String etichettaConferma;
  final bool inCorso;
  final ErroreOperazione? errore;
  final VoidCallback onAggiungi;
  final VoidCallback onScansiona;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final a = alimento;
    final personalizzato = a.fonte == FonteAlimento.personalizzato;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SchedaSezione(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const IconaTonale(icona: Icons.check_circle_outline),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Prodotto trovato',
                            style: testo.titleSmall?.copyWith(
                              color: c.primario,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(a.nome, style: testo.titleLarge),
                    if (a.marca != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        a.marca!,
                        style: testo.bodyLarge?.copyWith(
                          color: c.testoSecondario,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Valori per 100 g', style: testo.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Valore(
                          'Energia',
                          '${formattaValore(a.kcal100g!)} kcal',
                        ),
                        _Valore(
                          'Proteine',
                          '${formattaValore(a.proteine100g!)} g',
                        ),
                        _Valore(
                          'Carboidrati',
                          '${formattaValore(a.carboidrati100g!)} g',
                        ),
                        _Valore('Grassi', '${formattaValore(a.grassi100g!)} g'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      [
                        'Codice ${a.codiceBarre ?? '-'}',
                        if (personalizzato) 'tuo alimento personalizzato',
                        if (!personalizzato && daCache)
                          'già tra gli alimenti salvati',
                      ].join(' · '),
                      style: testo.bodySmall?.copyWith(
                        color: c.testoSecondario,
                      ),
                    ),
                  ],
                ),
              ),
              if (errore != null) ...[
                const SizedBox(height: 12),
                MessaggioErrore(
                  messaggio: errore!.messaggio,
                  onRiprova: onAggiungi,
                ),
              ],
              const SizedBox(height: 16),
              PulsantePrimario(
                etichetta: etichettaConferma,
                onPressed: onAggiungi,
                inCorso: inCorso,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: inCorso ? null : onScansiona,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scansiona un altro prodotto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Valore extends StatelessWidget {
  const _Valore(this.etichetta, this.valore);

  final String etichetta;
  final String valore;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.primarioTonale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etichetta,
            style: testo.bodySmall?.copyWith(color: c.testoSecondario),
          ),
          Text(valore, style: testo.titleMedium),
        ],
      ),
    );
  }
}
