import 'package:material_ui/material_ui.dart';

import '../../../core/tema/tema.dart';
import '../../../domain/modelli/obiettivi.dart';
import '../../../domain/modelli/piano_alimentare.dart';
import '../../../domain/regole/calcoli_piano.dart';
import '../../comuni/componenti.dart';
import 'pasto_card.dart';
import 'riepilogo_giorno.dart';

/// Piano alimentare in sola lettura: scelta del giorno, totali con
/// scostamento dagli obiettivi (se noti) e pasti con le loro voci e
/// alternative. Lo usa lo storico delle versioni del nutrizionista e può
/// riusarlo la sezione Dieta del paziente (UC_GP_4).
class PianoSolaLettura extends StatefulWidget {
  const PianoSolaLettura({super.key, required this.piano, this.obiettivi});

  final PianoAlimentare piano;
  final Obiettivi? obiettivi;

  @override
  State<PianoSolaLettura> createState() => _PianoSolaLetturaState();
}

class _PianoSolaLetturaState extends State<PianoSolaLettura> {
  late int _giorno = widget.piano.giorni.isEmpty
      ? 1
      : widget.piano.giorni.first.giornoSettimana;

  @override
  Widget build(BuildContext context) {
    final piano = widget.piano;
    final giorno = piano.giorno(_giorno);
    final c = context.colori;
    if (piano.giorni.isEmpty || giorno == null) {
      return const Center(child: Text('Questo piano non ha giorni.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SelettorePillole<int>(
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
        const SizedBox(height: 12),
        RiepilogoGiorno(
          titolo: GiorniSettimana.nome(_giorno),
          totale: macroGiorno(giorno),
          obiettivi: widget.obiettivi,
        ),
        const SizedBox(height: 12),
        for (final pasto in giorno.pasti) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IntestazionePasto(pasto: pasto),
                  Divider(color: c.bordo),
                  for (final v in pasto.voci) RigaVoce(voce: v),
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
