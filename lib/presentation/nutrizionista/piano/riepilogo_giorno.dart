import 'package:material_ui/material_ui.dart';

import '../../../core/tema/tema.dart';
import '../../../domain/modelli/obiettivi.dart';
import '../../../domain/modelli/piano_alimentare.dart';
import '../../../domain/regole/calcoli_piano.dart';
import '../alimenti/ricerca_alimento.dart' show formattaValore;

/// "+60", "-12", "0": segno esplicito per gli scostamenti.
String conSegno(double v, {int decimali = 0}) {
  final arrotondato = decimali == 0
      ? v.round().toDouble()
      : double.parse(v.toStringAsFixed(decimali));
  final testo = decimali == 0
      ? arrotondato.toInt().abs().toString()
      : formattaValore(arrotondato.abs());
  if (arrotondato > 0) return '+$testo';
  if (arrotondato < 0) return '-$testo';
  return testo;
}

/// "+3%", "-12%".
String percentuale(double relativo) {
  final p = (relativo * 100).round();
  return p > 0 ? '+$p%' : '$p%';
}

/// Kcal intere per l'interfaccia (un decimale solo sotto 10 kcal).
String kcalTesto(double v) =>
    v < 10 && v != v.roundToDouble() ? formattaValore(v) : v.round().toString();

/// Totali di un giorno e scostamento dagli obiettivi (RF_GP_16, UC_GP_1
/// passo 7). Sta sempre in vista sopra i pasti. Senza obiettivi mostra solo
/// i totali.
class RiepilogoGiorno extends StatelessWidget {
  const RiepilogoGiorno({
    super.key,
    required this.titolo,
    required this.totale,
    this.obiettivi,
  });

  final String titolo;
  final Macro totale;
  final Obiettivi? obiettivi;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final s = obiettivi == null ? null : scostamento(totale, obiettivi!);
    return Card(
      key: const Key('riepilogo-giorno'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(titolo, style: testo.titleMedium),
                if (s != null) _Stato(valore: s.kcal, unita: 'kcal'),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${kcalTesto(totale.kcal)} kcal',
                    style: testo.headlineSmall,
                  ),
                  if (obiettivi != null)
                    TextSpan(
                      text: '  su ${obiettivi!.kcal} di obiettivo',
                      style: testo.bodyMedium?.copyWith(
                        color: c.testoSecondario,
                      ),
                    ),
                ],
              ),
              key: const Key('totale-kcal'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Macro(
                  etichetta: 'Proteine',
                  totale: totale.proteineG,
                  valore: s?.proteine,
                ),
                _Macro(
                  etichetta: 'Carboidrati',
                  totale: totale.carboidratiG,
                  valore: s?.carboidrati,
                ),
                _Macro(
                  etichetta: 'Grassi',
                  totale: totale.grassiG,
                  valore: s?.grassi,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip con lo scarto: verde se in linea, giallo se oltre la tolleranza.
class _Stato extends StatelessWidget {
  const _Stato({required this.valore, required this.unita});

  final ScostamentoValore valore;
  final String unita;

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    final inLinea = valore.stato == StatoScostamento.inLinea;
    final testo = inLinea && valore.assoluto.abs() < 0.5
        ? 'In linea'
        : '${conSegno(valore.assoluto)} $unita (${percentuale(valore.relativo)})';
    return Container(
      key: const Key('scostamento-kcal'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: inLinea ? c.primarioTonale : c.avvisoTonale,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        inLinea ? testo : '$testo · fuori obiettivo',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: inLinea ? c.primario : c.avviso,
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({
    required this.etichetta,
    required this.totale,
    required this.valore,
  });

  final String etichetta;
  final double totale;
  final ScostamentoValore? valore;

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    final fuori = valore != null && valore!.stato != StatoScostamento.inLinea;
    final dettaglio = valore == null
        ? '${formattaValore(totale)} g'
        : '${formattaValore(totale)} / ${formattaValore(valore!.obiettivo)} g';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fuori ? c.avvisoTonale : c.primarioTonale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$etichetta $dettaglio',
        style: TextStyle(
          fontSize: 13,
          color: fuori ? c.avviso : c.testo,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
