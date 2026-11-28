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
  const RigaVoce({
    super.key,
    required this.voce,
    this.azione,
    this.onAlternative,
    this.alternativeEspandibili = false,
  });

  final VocePiano voce;

  /// `true` nella sezione Dieta del paziente (UC_GP_4): le alternative non
  /// sono scritte per esteso ma dietro un pulsante "Alternative (N)" che le
  /// apre, per tenere il piano leggibile. Solo consultazione. Con `false`
  /// (editor e storico del nutrizionista) resta la riga di testo di sempre.
  final bool alternativeEspandibili;

  /// Elementi a destra (cestino, maniglia di riordino): solo nell'editor.
  final Widget? azione;

  /// Apre le alternative della voce: solo nell'editor.
  final VoidCallback? onAlternative;

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
                if (alternative.isNotEmpty && alternativeEspandibili)
                  AlternativeEspandibili(voce: voce)
                else if (alternative.isNotEmpty)
                  Text(
                    alternative,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: testo.bodySmall?.copyWith(color: c.testoSecondario),
                  ),
                if (onAlternative != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: Key('alternative-${voce.chiave}'),
                      onPressed: onAlternative,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: Text(
                        voce.alternative.isEmpty
                            ? 'Aggiungi alternativa'
                            : 'Alternative (${voce.alternative.length})',
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
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

/// Alternative di una voce, chiuse di default (sezione Dieta del paziente,
/// RF_GP_8). Il pulsante è alto almeno 48 dp (RNF_U_3) e annuncia se è
/// aperto. Le kcal di ogni alternativa vengono da `macroVoce` (calcoli già
/// esistenti, D20): le alternative non entrano nei totali del pasto (D24).
class AlternativeEspandibili extends StatefulWidget {
  const AlternativeEspandibili({super.key, required this.voce});

  final VocePiano voce;

  @override
  State<AlternativeEspandibili> createState() => _AlternativeEspandibiliState();
}

class _AlternativeEspandibiliState extends State<AlternativeEspandibili> {
  bool _aperte = false;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final voce = widget.voce;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          expanded: _aperte,
          child: TextButton.icon(
            key: Key('mostra-alternative-${voce.chiave}'),
            onPressed: () => setState(() => _aperte = !_aperte),
            icon: Icon(_aperte ? Icons.expand_less : Icons.expand_more),
            label: Text('Alternative (${voce.alternative.length})'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 48),
            ),
          ),
        ),
        if (_aperte)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Al posto di ${voce.alimento.nome} puoi scegliere:',
                  style: testo.bodySmall?.copyWith(color: c.testoSecondario),
                ),
                for (final a in voce.alternative)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '• ${a.alimento.nome} · ${formattaValore(a.quantitaG)} g'
                      ' · ${kcalTesto(macroVoce(a.alimento, a.quantitaG).kcal)} kcal',
                      style: testo.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
