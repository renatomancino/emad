import 'package:material_ui/material_ui.dart';

import '../../core/tema/tema.dart';

/// SponsorCard (RF_GAD_6, RNF_L_6): scheda STATICA, solo nella dashboard del
/// nutrizionista con piano Free. Nessuna immagine remota, nessuna chiamata di
/// rete, nessun tracciamento, nessun dato dei pazienti. Mai mostrata al paziente.
class SponsorCard extends StatelessWidget {
  const SponsorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Card(
      color: const Color(0xFFFFF8E7),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.campaign_outlined,
              color: ColoriCenato.semaforoGiallo,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spazio sponsor', style: testo.labelMedium),
                  Text(
                    'Corso di aggiornamento in nutrizione clinica (esempio)',
                    style: testo.titleSmall,
                  ),
                  Text(
                    'Visibile solo nel piano Free. Passa a Start o Pro per '
                    'toglierlo.',
                    style: testo.bodySmall?.copyWith(
                      color: ColoriCenato.testoSecondario,
                    ),
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
