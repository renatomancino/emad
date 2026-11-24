import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/dipendenze.dart';
import '../../core/router/rotte.dart';
import '../../core/tema/tema.dart';
import '../../domain/modelli/paziente.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../comuni/controlli.dart';
import '../comuni/errore_limite_dialog.dart';

/// InvitoView (UC_GI_1, SC_GI_1): crea il codice di invito e prepara il
/// messaggio da inviare al paziente.
class InvitoPage extends StatefulWidget {
  const InvitoPage({super.key, required this.dip});

  final Dipendenze dip;

  @override
  State<InvitoPage> createState() => _InvitoPageState();
}

class _InvitoPageState extends State<InvitoPage> {
  final _nome = TextEditingController();
  bool _inCorso = false;
  String? _errore;
  Invito? _invito;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  String _testoInvito(Invito i) {
    final d = i.scadenza;
    final scadenza =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final nome = widget.dip.auth.profilo?.nome ?? 'il tuo nutrizionista';
    return 'Ciao! Sono $nome: ti invito a seguire il tuo percorso con me su '
        'Cenato. Scarica l\'app, scegli "Paziente" e inserisci il codice '
        '${i.codice} (valido fino al $scadenza).';
  }

  Future<void> _crea() async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });
    try {
      final invito = await widget.dip.pazienti.creaInvito(
        nome: _nome.text.trim().isEmpty ? null : _nome.text.trim(),
      );
      if (mounted) setState(() => _invito = invito);
    } on ErroreLimitePiano catch (e) {
      if (!mounted) return;
      await mostraErroreLimite(
        context,
        e,
        onCambiaPiano: () => context.go(Rotte.nutProfilo),
        onArchivia: () => context.go(Rotte.nutPazienti),
      );
    } on ErroreOperazione catch (e) {
      // Il nome resta nel campo: l'utente può riprovare.
      if (mounted) setState(() => _errore = e.messaggio);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _copia(Invito i) async {
    await Clipboard.setData(ClipboardData(text: _testoInvito(i)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Testo copiato: incollalo in WhatsApp, SMS o email.'),
      ),
    );
  }

  /// Apre il foglio di condivisione di sistema (WhatsApp, SMS, email...).
  /// Se non è disponibile (es. alcuni browser) si ripiega sulla copia.
  Future<void> _condividi(Invito i) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: _testoInvito(i), subject: 'Invito a Cenato'),
      );
    } catch (_) {
      await _copia(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final invito = _invito;
    return Scaffold(
      appBar: AppBar(title: const Text('Invita un paziente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (invito == null) ...[
            Text(
              'Crea un codice personale da inviare al paziente. Il codice vale '
              '7 giorni e si può revocare finché non viene usato.',
              style: testo.bodyLarge,
            ),
            const SizedBox(height: 16),
            CampoTesto(
              controller: _nome,
              etichetta: 'Nome del paziente (facoltativo)',
            ),
            const SizedBox(height: 16),
            PulsantePrimario(
              etichetta: 'Crea invito',
              onPressed: _crea,
              inCorso: _inCorso,
            ),
            if (_errore != null) ...[
              const SizedBox(height: 12),
              Text(
                _errore!,
                style: const TextStyle(color: ColoriCenato.errore),
              ),
            ],
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Codice di invito', style: testo.labelLarge),
                    const SizedBox(height: 8),
                    SelectableText(
                      invito.codice,
                      key: const Key('codice-invito'),
                      style: testo.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: ColoriCenato.primario,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Valido fino al ${invito.scadenza.day.toString().padLeft(2, '0')}/'
                      '${invito.scadenza.month.toString().padLeft(2, '0')}/${invito.scadenza.year}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Messaggio da inviare', style: testo.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_testoInvito(invito)),
              ),
            ),
            const SizedBox(height: 16),
            PulsantePrimario(
              etichetta: 'Condividi',
              onPressed: () => _condividi(invito),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _copia(invito),
              child: const Text('Copia il messaggio'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go(Rotte.nutPazienti),
              child: const Text('Torna ai pazienti'),
            ),
          ],
        ],
      ),
    );
  }
}
