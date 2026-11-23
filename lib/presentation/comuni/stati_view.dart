import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/tema/tema.dart';

/// Stato di caricamento (CLAUDE.md, "Come lavorare": caricamento, vuoto, errore).
class CaricamentoView extends StatelessWidget {
  const CaricamentoView({super.key, this.messaggio = Testi.caricamento});

  final String messaggio;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              messaggio,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stato vuoto: icona, titolo, messaggio e un'azione facoltativa
/// (es. "Invita un paziente" quando l'elenco è vuoto, UC_GI_3 flusso 2.1).
class StatoVuotoView extends StatelessWidget {
  const StatoVuotoView({
    super.key,
    required this.icona,
    required this.titolo,
    required this.messaggio,
    this.etichettaAzione,
    this.onAzione,
  });

  final IconData icona;
  final String titolo;
  final String messaggio;
  final String? etichettaAzione;
  final VoidCallback? onAzione;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icona, size: 56, color: ColoriCenato.primario),
            const SizedBox(height: 16),
            Text(titolo, textAlign: TextAlign.center, style: testo.titleLarge),
            const SizedBox(height: 8),
            Text(
              messaggio,
              textAlign: TextAlign.center,
              style: testo.bodyLarge?.copyWith(
                color: ColoriCenato.testoSecondario,
              ),
            ),
            if (etichettaAzione != null && onAzione != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAzione, child: Text(etichettaAzione!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Errore con pulsante "Riprova" (RNF_A_2: messaggi chiari, nessuna chiusura).
/// Chi la usa deve conservare ciò che l'utente ha già inserito.
class ErroreView extends StatelessWidget {
  const ErroreView({
    super.key,
    this.messaggio = Testi.erroreRete,
    required this.onRiprova,
  });

  final String messaggio;
  final VoidCallback onRiprova;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: ColoriCenato.errore,
            ),
            const SizedBox(height: 16),
            Text(
              Testi.erroreGenerico,
              textAlign: TextAlign.center,
              style: testo.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              messaggio,
              textAlign: TextAlign.center,
              style: testo.bodyLarge,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRiprova,
              icon: const Icon(Icons.refresh),
              label: const Text(Testi.riprova),
            ),
          ],
        ),
      ),
    );
  }
}
