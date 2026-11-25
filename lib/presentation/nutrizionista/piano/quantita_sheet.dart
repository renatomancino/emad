import 'package:material_ui/material_ui.dart';

import '../../../core/tema/tema.dart';
import '../../../domain/modelli/alimento.dart';
import '../../../domain/regole/calcoli_piano.dart';
import '../../comuni/controlli.dart';
import '../alimenti/ricerca_alimento.dart' show formattaValore;
import 'riepilogo_giorno.dart' show kcalTesto;

/// Chiede la quantità di un alimento (UC_GP_2 passo 4): quantità rapide
/// (RF_GP_15) o campo libero, con anteprima di kcal e macro. Restituisce i
/// grammi, o `null` se si annulla.
Future<double?> chiediQuantita(
  BuildContext context, {
  required Alimento alimento,
  double? iniziale,
  String etichettaConferma = 'Aggiungi',
}) {
  // Un avviso ancora visibile coprirebbe il pulsante del foglio.
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _QuantitaSheet(
      alimento: alimento,
      iniziale: iniziale,
      etichettaConferma: etichettaConferma,
    ),
  );
}

class _QuantitaSheet extends StatefulWidget {
  const _QuantitaSheet({
    required this.alimento,
    required this.iniziale,
    required this.etichettaConferma,
  });

  final Alimento alimento;
  final double? iniziale;
  final String etichettaConferma;

  @override
  State<_QuantitaSheet> createState() => _QuantitaSheetState();
}

class _QuantitaSheetState extends State<_QuantitaSheet> {
  late final _testo = TextEditingController(
    text: widget.iniziale == null ? '' : formattaValore(widget.iniziale!),
  );
  String? _errore;

  @override
  void dispose() {
    _testo.dispose();
    super.dispose();
  }

  /// Quantità scritta, se valida (per l'anteprima).
  double? get _quantita =>
      validaQuantita(_testo.text) == null ? leggiQuantita(_testo.text) : null;

  void _conferma() {
    final errore = validaQuantita(_testo.text);
    if (errore != null) {
      setState(() => _errore = errore);
      return;
    }
    Navigator.of(context).pop(leggiQuantita(_testo.text));
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final q = _quantita;
    final macro = q == null ? null : macroVoce(widget.alimento, q);
    final a = widget.alimento;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(a.nome, style: testo.titleLarge),
            Text(
              'Per 100 g: ${formattaValore(a.kcal100g ?? 0)} kcal · '
              'P ${formattaValore(a.proteine100g ?? 0)} g · '
              'C ${formattaValore(a.carboidrati100g ?? 0)} g · '
              'G ${formattaValore(a.grassi100g ?? 0)} g',
              style: testo.bodyMedium?.copyWith(color: c.testoSecondario),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in quantitaRapideG)
                  ActionChip(
                    key: Key('quantita-rapida-$g'),
                    label: Text('$g g'),
                    onPressed: () => setState(() {
                      _testo.text = '$g';
                      _errore = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            CampoTesto(
              controller: _testo,
              etichetta: 'Quantità (g)',
              errore: _errore,
              tastiera: const TextInputType.numberWithOptions(decimal: true),
              azioneTastiera: TextInputAction.done,
              onInvio: _conferma,
              onCambiato: (_) => setState(() => _errore = null),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  macro == null
                      ? 'Indica la quantità per vedere kcal e macro.'
                      : '${kcalTesto(macro.kcal)} kcal · '
                            'P ${formattaValore(macro.proteineG)} g · '
                            'C ${formattaValore(macro.carboidratiG)} g · '
                            'G ${formattaValore(macro.grassiG)} g',
                  key: const Key('anteprima-quantita'),
                  style: testo.titleSmall,
                ),
              ),
            ),
            const SizedBox(height: 8),
            PulsantePrimario(
              etichetta: widget.etichettaConferma,
              onPressed: _conferma,
            ),
          ],
        ),
      ),
    );
  }
}
