import 'package:material_ui/material_ui.dart';

import '../../../core/tema/tema.dart';
import '../../../domain/modelli/obiettivi.dart';
import '../../../domain/modelli/piano_alimentare.dart';
import '../../../domain/regole/calcoli_piano.dart';
import '../../comuni/componenti.dart';
import '../alimenti/ricerca_alimento.dart' show formattaValore;
import 'pasto_card.dart';
import 'riepilogo_giorno.dart';

/// Piano alimentare in sola lettura: scelta del giorno, totali con
/// scostamento dagli obiettivi (se noti) e pasti con le loro voci e
/// alternative. Lo usano lo storico delle versioni del nutrizionista e la
/// sezione Dieta del paziente (UC_GP_4).
///
/// I parametri facoltativi servono alla sezione Dieta; i valori predefiniti
/// lasciano lo storico com'era.
class PianoSolaLettura extends StatefulWidget {
  const PianoSolaLettura({
    super.key,
    required this.piano,
    this.obiettivi,
    this.giornoIniziale,
    this.giornoOggi,
    this.intestazione,
    this.alternativeEspandibili = false,
    this.macroPerPasto = false,
    this.fisica,
  });

  final PianoAlimentare piano;
  final Obiettivi? obiettivi;

  /// Giorno mostrato all'apertura (1 = lunedì … 7 = domenica). Se manca o il
  /// piano non lo prevede, si apre il primo giorno del piano.
  final int? giornoIniziale;

  /// Giorno di oggi: la sua pillola dice "· oggi" (il testo c'è sempre, così
  /// l'evidenza non dipende solo dal colore, RNF_U_3). `null` = nessuna.
  final int? giornoOggi;

  /// Contenuto in cima all'elenco, prima del selettore dei giorni (gli
  /// obiettivi nella sezione Dieta). Scorre con il resto della pagina.
  final Widget? intestazione;

  /// Alternative chiuse dietro "Alternative (N)" (vedi `RigaVoce`).
  final bool alternativeEspandibili;

  /// Mostra proteine, carboidrati e grassi sotto ogni pasto (sezione Dieta).
  final bool macroPerPasto;

  /// Fisica dell'elenco: la sezione Dieta usa `AlwaysScrollableScrollPhysics`
  /// perché il "tira per aggiornare" funzioni anche con pochi pasti.
  final ScrollPhysics? fisica;

  @override
  State<PianoSolaLettura> createState() => _PianoSolaLetturaState();
}

class _PianoSolaLetturaState extends State<PianoSolaLettura> {
  late int _giorno = _giornoValido(widget.giornoIniziale);

  /// [preferito] se il piano lo prevede, altrimenti il primo giorno del piano.
  int _giornoValido(int? preferito) {
    final piano = widget.piano;
    if (preferito != null && piano.giorno(preferito) != null) return preferito;
    return piano.giorni.isEmpty ? 1 : piano.giorni.first.giornoSettimana;
  }

  @override
  void didUpdateWidget(covariant PianoSolaLettura vecchio) {
    super.didUpdateWidget(vecchio);
    // Dopo un aggiornamento il piano può non avere più il giorno scelto (la
    // nuova versione l'ha tolto): invece di "Questo piano non ha giorni" si
    // passa al giorno iniziale o al primo disponibile.
    if (widget.piano.giorno(_giorno) == null) {
      _giorno = _giornoValido(widget.giornoIniziale);
    }
  }

  @override
  Widget build(BuildContext context) {
    final piano = widget.piano;
    final giorno = piano.giorno(_giorno);
    final c = context.colori;
    if (piano.giorni.isEmpty || giorno == null) {
      return ListView(
        physics: widget.fisica,
        padding: const EdgeInsets.all(16),
        children: [
          ?widget.intestazione,
          const SizedBox(height: 24),
          const Center(child: Text('Questo piano non ha giorni.')),
        ],
      );
    }
    return ListView(
      physics: widget.fisica,
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.intestazione != null) ...[
          widget.intestazione!,
          const SizedBox(height: 12),
        ],
        SelettorePillole<int>(
          opzioni: [
            for (final g in piano.giorni)
              OpzioneSelettore(
                g.giornoSettimana,
                g.giornoSettimana == widget.giornoOggi
                    ? '${GiorniSettimana.abbreviato(g.giornoSettimana)} · oggi'
                    : GiorniSettimana.abbreviato(g.giornoSettimana),
              ),
          ],
          selezionato: _giorno,
          onCambiato: (g) => setState(() => _giorno = g),
        ),
        const SizedBox(height: 12),
        RiepilogoGiorno(
          titolo: _giorno == widget.giornoOggi
              ? '${GiorniSettimana.nome(_giorno)} (oggi)'
              : GiorniSettimana.nome(_giorno),
          // Totale del giorno con i calcoli esistenti (D20): niente somme nuove.
          totale: macroGiorno(giorno),
          obiettivi: widget.obiettivi,
        ),
        const SizedBox(height: 12),
        for (final pasto in giorno.pasti) ...[
          Card(
            // Chiave per giorno e pasto: cambiando giorno (o versione) la
            // card si ricrea, così le "Alternative" aperte non vengono
            // ereditate dalla riga che sta nella stessa posizione.
            key: ValueKey('pasto-$_giorno-${pasto.chiave}'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IntestazionePasto(pasto: pasto),
                  if (widget.macroPerPasto) _MacroPasto(pasto: pasto),
                  Divider(color: c.bordo),
                  for (final v in pasto.voci)
                    RigaVoce(
                      voce: v,
                      alternativeEspandibili: widget.alternativeEspandibili,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Macro del pasto sotto l'intestazione (la scheda chiede kcal **e macro**
/// per pasto). Valori da `macroPasto`, già usata dall'intestazione.
class _MacroPasto extends StatelessWidget {
  const _MacroPasto({required this.pasto});

  final PastoPiano pasto;

  @override
  Widget build(BuildContext context) {
    final m = macroPasto(pasto);
    // Un decimale come il totale del giorno (arrotonda1 toglie i residui
    // delle somme, tipo 10.399999). Lo spazio indivisibile U+00A0 tiene il
    // numero attaccato alla "g" quando il testo grande va a capo.
    String g(double v) => '${formattaValore(arrotonda1(v))}\u00A0g';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        'Proteine ${g(m.proteineG)} · Carboidrati ${g(m.carboidratiG)} · '
        'Grassi ${g(m.grassiG)}',
        key: Key('macro-pasto-${pasto.chiave}'),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: context.colori.testoSecondario),
      ),
    );
  }
}
