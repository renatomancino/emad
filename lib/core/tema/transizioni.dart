import 'package:material_ui/material_ui.dart';

/// Transizione di pagina che rispetta "riduci animazioni" del telefono: in
/// quel caso la pagina compare senza effetti. Altrimenti usa [delegato].
class TransizionePagina extends PageTransitionsBuilder {
  const TransizionePagina(this.delegato);

  final PageTransitionsBuilder delegato;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return delegato.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Durata della dissolvenza tra le schede della barra in basso.
const Duration durataDissolvenzaSchede = Duration(milliseconds: 220);

/// Contenitore delle schede della barra in basso (una per ramo di
/// navigazione): cambiando scheda la nuova compare in dissolvenza mentre la
/// precedente svanisce. Come un `IndexedStack`, tutte le schede restano
/// vive: testo digitato e posizione di scorrimento non si perdono.
/// Con "riduci animazioni" il cambio è immediato.
class RamiConDissolvenza extends StatefulWidget {
  const RamiConDissolvenza({
    super.key,
    required this.indice,
    required this.rami,
  });

  final int indice;
  final List<Widget> rami;

  @override
  State<RamiConDissolvenza> createState() => _RamiConDissolvenzaState();
}

class _RamiConDissolvenzaState extends State<RamiConDissolvenza>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animazione = AnimationController(
    vsync: this,
    duration: durataDissolvenzaSchede,
    value: 1,
  );

  /// Scheda che sta svanendo (solo durante la dissolvenza).
  int? _anteriore;

  @override
  void initState() {
    super.initState();
    _animazione.addStatusListener((stato) {
      if (stato == AnimationStatus.completed && _anteriore != null) {
        setState(() => _anteriore = null);
      }
    });
  }

  @override
  void didUpdateWidget(RamiConDissolvenza vecchio) {
    super.didUpdateWidget(vecchio);
    if (vecchio.indice == widget.indice) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _anteriore = null;
      _animazione.value = 1;
    } else {
      _anteriore = vecchio.indice;
      _animazione.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animazione.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.rami.length; i++)
          // Stessa struttura per ogni scheda, così non viene ricreata.
          Offstage(
            offstage: i != widget.indice && i != _anteriore,
            child: IgnorePointer(
              ignoring: i != widget.indice,
              child: ExcludeSemantics(
                excluding: i != widget.indice,
                child: TickerMode(
                  enabled: i == widget.indice || i == _anteriore,
                  child: FadeTransition(
                    opacity: i == widget.indice
                        ? _animazione
                        : i == _anteriore
                        ? ReverseAnimation(_animazione)
                        : const AlwaysStoppedAnimation<double>(0),
                    child: widget.rami[i],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
