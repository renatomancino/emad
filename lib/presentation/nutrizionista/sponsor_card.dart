import 'package:material_ui/material_ui.dart';

import '../../core/tema/tema.dart';
import '../comuni/componenti.dart';

/// SponsorCard (RF_GAD_6, RNF_L_6): scheda STATICA, solo nella dashboard del
/// nutrizionista con piano Free. Nessuna immagine remota, nessuna chiamata di
/// rete, nessun tracciamento, nessun dato dei pazienti. Mai mostrata al paziente.
class SponsorCard extends StatelessWidget {
  const SponsorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    return Card(
      color: c.avvisoTonale,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconaTonale(
                  icona: Icons.campaign_outlined,
                  colore: c.avviso,
                  sfondo: c.superficie,
                  dimensione: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Spazio sponsor',
                    style: testo.labelMedium?.copyWith(color: c.avviso),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Corso di aggiornamento in nutrizione clinica (esempio)',
              style: testo.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Visibile solo nel piano Free. Passa a Start o Pro per '
              'toglierlo.',
              style: testo.bodySmall?.copyWith(color: c.testoSecondario),
            ),
          ],
        ),
      ),
    );
  }
}
