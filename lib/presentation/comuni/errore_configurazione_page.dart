import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Mostrata quando `.env` manca o non è valido.
class SchermataErroreConfigurazione extends StatelessWidget {
  const SchermataErroreConfigurazione({super.key, required this.messaggio});

  final String messaggio;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.settings_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Configurazione mancante',
                  style: testo.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  messaggio,
                  style: testo.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Istruzioni nel README.md del repository.',
                    style: testo.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
