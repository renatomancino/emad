import 'package:material_ui/material_ui.dart';

import '../../core/tema/tema.dart';

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
    this.onInvio,
    this.onCambiato,
    this.suffisso,
    this.aiuto,
    this.maiuscolo = false,
    this.maxRighe = 1,
    this.abilitato = true,
  });

  final TextEditingController controller;
  final String etichetta;
  final String? errore;
  final TextInputType? tastiera;
  final bool oscurato;
  final Iterable<String>? suggerimentiAutofill;
  final TextInputAction? azioneTastiera;
  final VoidCallback? onInvio;
  final ValueChanged<String>? onCambiato;
  final Widget? suffisso;
  final String? aiuto;
  final bool maiuscolo;
  final int maxRighe;
  final bool abilitato;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: abilitato,
      keyboardType: tastiera,
      obscureText: oscurato,
      autofillHints: suggerimentiAutofill,
      textInputAction: azioneTastiera,
      textCapitalization: maiuscolo
          ? TextCapitalization.characters
          : TextCapitalization.none,
      minLines: 1,
      maxLines: oscurato ? 1 : maxRighe,
      onSubmitted: onInvio == null ? null : (_) => onInvio!(),
      onChanged: onCambiato,
      decoration: InputDecoration(
        labelText: etichetta,
        errorText: errore,
        helperText: aiuto,
        helperMaxLines: 3,
        errorMaxLines: 3,
        suffixIcon: suffisso,
      ),
    );
  }
}

/// Campo password con pulsante per mostrare o nascondere il testo.
/// La password non viene mai salvata né scritta nei log.
class CampoPassword extends StatefulWidget {
  const CampoPassword({
    super.key,
    required this.controller,
    this.etichetta = 'Password',
    this.errore,
    this.azioneTastiera,
    this.onInvio,
    this.onCambiato,
    this.aiuto,
    this.nuova = false,
  });

  final TextEditingController controller;
  final String etichetta;
  final String? errore;
  final TextInputAction? azioneTastiera;
  final VoidCallback? onInvio;
  final ValueChanged<String>? onCambiato;
  final String? aiuto;

  /// `true` per una password da scegliere (suggerisce di salvarla al gestore
  /// password), `false` per quella da inserire all'accesso.
  final bool nuova;

  @override
  State<CampoPassword> createState() => _CampoPasswordState();
}

class _CampoPasswordState extends State<CampoPassword> {
  bool _visibile = false;

  @override
  Widget build(BuildContext context) {
    return CampoTesto(
      controller: widget.controller,
      etichetta: widget.etichetta,
      errore: widget.errore,
      oscurato: !_visibile,
      aiuto: widget.aiuto,
      azioneTastiera: widget.azioneTastiera,
      onInvio: widget.onInvio,
      onCambiato: widget.onCambiato,
      suggerimentiAutofill: [
        widget.nuova ? AutofillHints.newPassword : AutofillHints.password,
      ],
      suffisso: IconButton(
        tooltip: _visibile ? 'Nascondi la password' : 'Mostra la password',
        icon: Icon(
          _visibile ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        onPressed: () => setState(() => _visibile = !_visibile),
      ),
    );
  }
}

/// Riquadro con un errore del server e, se utile, il pulsante "Riprova".
/// Resta accanto al modulo: i dati inseriti non si perdono.
class MessaggioErrore extends StatelessWidget {
  const MessaggioErrore({super.key, required this.messaggio, this.onRiprova});

  final String messaggio;
  final VoidCallback? onRiprova;

  @override
  Widget build(BuildContext context) {
    final errore = context.colori.errore;
    return Container(
      key: const Key('messaggio-errore'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errore.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: errore.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: errore),
              const SizedBox(width: 8),
              Expanded(child: Text(messaggio)),
            ],
          ),
          if (onRiprova != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRiprova,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ),
        ],
      ),
    );
  }
}
