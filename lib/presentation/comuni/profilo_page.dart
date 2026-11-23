import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/tema/tema.dart';
import '../../domain/modelli/profilo.dart';
import '../../domain/repository/auth_repository.dart';
import 'segnaposto_page.dart';

/// Profilo dell'utente con il logout (UC_GA_2, passi 7-8).
/// Modifica del profilo, abbonamento ed eliminazione dell'account arrivano
/// nelle schede della fase 1 (UC_GA_3, UC_GA_5, UC_GAD_3).
class ProfiloPage extends StatefulWidget {
  const ProfiloPage({
    super.key,
    required this.auth,
    this.mostraIndietro = false,
  });

  final AuthRepository auth;

  /// `true` quando la pagina è aperta sopra una sezione (paziente).
  final bool mostraIndietro;

  @override
  State<ProfiloPage> createState() => _ProfiloPageState();
}

class _ProfiloPageState extends State<ProfiloPage> {
  bool _inUscita = false;

  Future<void> _esci() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Testi.esci),
        content: const Text(Testi.esciConferma),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Testi.annulla),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Testi.esci),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    setState(() => _inUscita = true);
    try {
      // Il router torna da solo alla schermata di accesso.
      await widget.auth.esci();
    } on ErroreAuth catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.messaggio)));
    } finally {
      if (mounted) setState(() => _inUscita = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilo = widget.auth.profilo;
    final nutrizionista = profilo?.ruolo == Ruolo.nutrizionista;
    final testo = Theme.of(context).textTheme;
    final intestazione = IntestazioneSezione(
      titolo: nutrizionista ? Testi.profiloAbbonamentoTitolo : Testi.profilo,
      sottotitolo: profilo?.ruolo.etichetta,
    );
    return Scaffold(
      appBar: widget.mostraIndietro
          ? AppBar(title: const Text(Testi.profilo))
          : intestazione,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const CircleAvatar(
                backgroundColor: ColoriCenato.primarioChiaro,
                child: Icon(Icons.person, color: ColoriCenato.primario),
              ),
              title: Text(profilo?.nome ?? '', style: testo.titleMedium),
              subtitle: Text(profilo?.ruolo.etichetta ?? ''),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                nutrizionista
                    ? 'In arrivo: dati del profilo, disponibilità, piano di '
                          'abbonamento Free / Start / Pro (UC_GA_3, UC_GV_3, UC_GAD_3).'
                    : 'In arrivo: dati del profilo, promemoria, interruzione del '
                          'collegamento ed eliminazione dell\'account (UC_GA_3, '
                          'UC_GN_2, UC_GI_5, UC_GA_5).',
                style: testo.bodyMedium?.copyWith(
                  color: ColoriCenato.testoSecondario,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _inUscita ? null : _esci,
            icon: const Icon(Icons.logout),
            label: const Text(Testi.esci),
          ),
        ],
      ),
    );
  }
}
