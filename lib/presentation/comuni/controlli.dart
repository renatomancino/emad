import 'package:material_ui/material_ui.dart';

/// Pulsante principale a tutta larghezza, con stato di attesa.
/// Mentre [inCorso] è vero è disattivato, così non si invia due volte.
class PulsantePrimario extends StatelessWidget {
  const PulsantePrimario({
    super.key,
    required this.etichetta,
    required this.onPressed,
    this.inCorso = false,
  });

  final String etichetta;
  final VoidCallback? onPressed;
  final bool inCorso;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: inCorso ? null : onPressed,
        child: inCorso
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(etichetta),
      ),
    );
  }
}

/// Campo di testo standard con etichetta e messaggio di errore.
class CampoTesto extends StatelessWidget {
  const CampoTesto({
    super.key,
    required this.controller,
    required this.etichetta,
    this.errore,
    this.tastiera,
    this.oscurato = false,
    this.suggerimentiAutofill,
    this.azioneTastiera,
  });

  final TextEditingController controller;
  final String etichetta;
  final String? errore;
  final TextInputType? tastiera;
  final bool oscurato;
  final Iterable<String>? suggerimentiAutofill;
  final TextInputAction? azioneTastiera;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: tastiera,
      obscureText: oscurato,
      autofillHints: suggerimentiAutofill,
      textInputAction: azioneTastiera,
      decoration: InputDecoration(labelText: etichetta, errorText: errore),
    );
  }
}
