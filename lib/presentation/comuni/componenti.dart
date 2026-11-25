import 'package:material_ui/material_ui.dart';

import '../../core/tema/tema.dart';

/// Tono di un'etichetta di stato (es. "Attivo", "Archiviato").
/// Il significato non è mai affidato al solo colore: c'è sempre il testo.
enum TonoStato { positivo, attenzione, errore, neutro }

/// Icona dentro un quadrato arrotondato dal fondo tenue, come nelle app
/// salute. Decorativa: il significato sta nel testo accanto.
class IconaTonale extends StatelessWidget {
  const IconaTonale({
    super.key,
    required this.icona,
    this.colore,
    this.sfondo,
    this.dimensione = 44,
  });

  final IconData icona;

  /// Colore dell'icona (predefinito: verde principale).
  final Color? colore;

  /// Fondo del quadrato (predefinito: verde tenue).
  final Color? sfondo;
  final double dimensione;

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: dimensione,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: sfondo ?? c.primarioTonale,
            borderRadius: BorderRadius.circular(dimensione / 3.5),
          ),
          child: Center(
            child: Icon(
              icona,
              size: dimensione * 0.5,
              color: colore ?? c.primario,
            ),
          ),
        ),
      ),
    );
  }
}

/// Card bianca con titolo facoltativo e contenuto. Con [onTap] diventa
/// toccabile (con effetto di pressione).
class SchedaSezione extends StatelessWidget {
  const SchedaSezione({
    super.key,
    this.titolo,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final String? titolo;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titolo != null) ...[
                Text(titolo!, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Riga di un elenco dentro una card: elemento iniziale, titolo, sottotitolo
/// ed elemento finale. Alta almeno 64 dp; testi troncati con puntini, così
/// nomi lunghi o testo ingrandito non causano overflow.
class RigaElenco extends StatelessWidget {
  const RigaElenco({
    super.key,
    required this.titolo,
    this.sottotitolo,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String titolo;
  final String? sottotitolo;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titolo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: testo.titleMedium,
                      ),
                      if (sottotitolo != null)
                        Text(
                          sottotitolo!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: testo.bodyMedium?.copyWith(
                            color: c.testoSecondario,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Flexible(child: trailing!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
