import 'package:material_ui/material_ui.dart';

import '../../../core/tema/tema.dart';
import '../../../domain/modelli/piano_alimentare.dart';
import '../../../domain/regole/calcoli_piano.dart';
import '../alimenti/ricerca_alimento.dart' show formattaValore;
import 'riepilogo_giorno.dart' show kcalTesto;

/// Testo delle alternative di una voce: "Alternative: Fette biscottate 35 g".
String testoAlternative(VocePiano voce) => voce.alternative.isEmpty
    ? ''
    : 'Alternative: ${voce.alternative.map((a) => '${a.alimento.nome} ${formattaValore(a.quantitaG)} g').join(', ')}';

/// Riga di una voce: nome, quantità, kcal e, se ci sono, le alternative.
class RigaVoce extends StatelessWidget {
  const RigaVoce({super.key, required this.voce, this.azione});

  final VocePiano voce;

  /// Elementi a destra (cestino, maniglia di riordino): solo nell'editor.
  final Widget? azione;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final macro = macroVoce(voce.alimento, voce.quantitaG);
    final alternative = testoAlternative(voce);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voce.alimento.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: testo.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${formattaValore(voce.quantitaG)} g · '
                  '${kcalTesto(macro.kcal)} kcal',
                  style: testo.bodyMedium?.copyWith(color: c.testoSecondario),
                ),
                if (alternative.isNotEmpty)
                  Text(
                    alternative,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: testo.bodySmall?.copyWith(color: c.testoSecondario),
                  ),
              ],
            ),
          ),
        ),
        ?azione,
      ],
    );
  }
}

/// Intestazione di un pasto: tipo, orario e kcal del pasto.
class IntestazionePasto extends StatelessWidget {
  const IntestazionePasto({super.key, required this.pasto, this.menu});

  final PastoPiano pasto;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final macro = macroPasto(pasto);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pasto.tipo.etichetta, style: testo.titleMedium),
              Text(
                [
                  if (pasto.orario != null) 'alle ${pasto.orario}',
                  '${kcalTesto(macro.kcal)} kcal',
                ].join(' · '),
                style: testo.bodyMedium?.copyWith(color: c.testoSecondario),
              ),
            ],
          ),
        ),
        ?menu,
      ],
    );
  }
}
