import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'transizioni.dart';

/// Famiglie di font incorporate in `assets/fonts/` (licenza SIL OFL).
/// Titoli ed etichette forti: Plus Jakarta Sans. Testo corrente: Inter.
const String fontTitoli = 'PlusJakartaSans';
const String fontTesto = 'Inter';

/// Valori della palette chiara, usati da [CenatoColori.chiaro].
abstract final class _Palette {
  static const sfondo = Color(0xFFF3F6F4);
  static const superficie = Color(0xFFFFFFFF);
  static const bordo = Color(0xFFE1E8E3);
  static const bordoCampo = Color(0xFF7B8B81);
  static const testo = Color(0xFF16211C);
  static const testoSecondario = Color(0xFF55645C);

  /// Verde principale. Contrasto con il bianco circa 6,5:1 (WCAG AA, RNF_U_3).
  static const primario = Color(0xFF2F6B4F);
  static const sulPrimario = Color(0xFFFFFFFF);
  static const primarioTonale = Color(0xFFE2F1E8);
  static const errore = Color(0xFFB3261E);
  static const erroreTonale = Color(0xFFF7E9E8);
  static const avviso = Color(0xFF8A5A00);
  static const avvisoTonale = Color(0xFFFFF3D6);

  // Semaforo dell'aderenza (RF_GAD_2): invariato rispetto al RAD.
  static const semaforoVerde = Color(0xFF2E7D4F);
  static const semaforoGiallo = Color(0xFFB7791F);
  static const semaforoRosso = Color(0xFFC0392B);
}

/// Palette dell'app, registrata nel tema come estensione: così i colori
/// seguono il tema attivo e un tema scuro si aggiunge senza toccare le pagine.
@immutable
class CenatoColori extends ThemeExtension<CenatoColori> {
  const CenatoColori({
    required this.sfondo,
    required this.superficie,
    required this.bordo,
    required this.bordoCampo,
    required this.testo,
    required this.testoSecondario,
    required this.primario,
    required this.sulPrimario,
    required this.primarioTonale,
    required this.errore,
    required this.erroreTonale,
    required this.avviso,
    required this.avvisoTonale,
    required this.semaforoVerde,
    required this.semaforoGiallo,
    required this.semaforoRosso,
  });

  /// Sfondo delle schermate.
  final Color sfondo;

  /// Sfondo di card, campi e barre.
  final Color superficie;

  /// Linee decorative (divisori, bordi di elementi non interattivi).
  final Color bordo;

  /// Bordo dei campi di testo: almeno 3:1 sulla superficie (WCAG 1.4.11).
  final Color bordoCampo;
  final Color testo;
  final Color testoSecondario;
  final Color primario;

  /// Colore di testo e icone sopra [primario].
  final Color sulPrimario;

  /// Fondo tenue del verde, per icone, badge e selezioni.
  final Color primarioTonale;
  final Color errore;

  /// Fondo tenue del rosso, per icone e badge di errore.
  final Color erroreTonale;

  /// Testo di avviso (giallo scuro) da usare su [avvisoTonale].
  final Color avviso;
  final Color avvisoTonale;
  final Color semaforoVerde;
  final Color semaforoGiallo;
  final Color semaforoRosso;

  static const chiaro = CenatoColori(
    sfondo: _Palette.sfondo,
    superficie: _Palette.superficie,
    bordo: _Palette.bordo,
    bordoCampo: _Palette.bordoCampo,
    testo: _Palette.testo,
    testoSecondario: _Palette.testoSecondario,
    primario: _Palette.primario,
    sulPrimario: _Palette.sulPrimario,
    primarioTonale: _Palette.primarioTonale,
    errore: _Palette.errore,
    erroreTonale: _Palette.erroreTonale,
    avviso: _Palette.avviso,
    avvisoTonale: _Palette.avvisoTonale,
    semaforoVerde: _Palette.semaforoVerde,
    semaforoGiallo: _Palette.semaforoGiallo,
    semaforoRosso: _Palette.semaforoRosso,
  );

  @override
  CenatoColori copyWith({
    Color? sfondo,
    Color? superficie,
    Color? bordo,
    Color? bordoCampo,
    Color? testo,
    Color? testoSecondario,
    Color? primario,
    Color? sulPrimario,
    Color? primarioTonale,
    Color? errore,
    Color? erroreTonale,
    Color? avviso,
    Color? avvisoTonale,
    Color? semaforoVerde,
    Color? semaforoGiallo,
    Color? semaforoRosso,
  }) {
    return CenatoColori(
      sfondo: sfondo ?? this.sfondo,
      superficie: superficie ?? this.superficie,
      bordo: bordo ?? this.bordo,
      bordoCampo: bordoCampo ?? this.bordoCampo,
      testo: testo ?? this.testo,
      testoSecondario: testoSecondario ?? this.testoSecondario,
      primario: primario ?? this.primario,
      sulPrimario: sulPrimario ?? this.sulPrimario,
      primarioTonale: primarioTonale ?? this.primarioTonale,
      errore: errore ?? this.errore,
      erroreTonale: erroreTonale ?? this.erroreTonale,
      avviso: avviso ?? this.avviso,
      avvisoTonale: avvisoTonale ?? this.avvisoTonale,
      semaforoVerde: semaforoVerde ?? this.semaforoVerde,
      semaforoGiallo: semaforoGiallo ?? this.semaforoGiallo,
      semaforoRosso: semaforoRosso ?? this.semaforoRosso,
    );
  }

  @override
  CenatoColori lerp(ThemeExtension<CenatoColori>? other, double t) {
    if (other is! CenatoColori) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return CenatoColori(
      sfondo: l(sfondo, other.sfondo),
      superficie: l(superficie, other.superficie),
      bordo: l(bordo, other.bordo),
      bordoCampo: l(bordoCampo, other.bordoCampo),
      testo: l(testo, other.testo),
      testoSecondario: l(testoSecondario, other.testoSecondario),
      primario: l(primario, other.primario),
      sulPrimario: l(sulPrimario, other.sulPrimario),
      primarioTonale: l(primarioTonale, other.primarioTonale),
      errore: l(errore, other.errore),
      erroreTonale: l(erroreTonale, other.erroreTonale),
      avviso: l(avviso, other.avviso),
      avvisoTonale: l(avvisoTonale, other.avvisoTonale),
      semaforoVerde: l(semaforoVerde, other.semaforoVerde),
      semaforoGiallo: l(semaforoGiallo, other.semaforoGiallo),
      semaforoRosso: l(semaforoRosso, other.semaforoRosso),
    );
  }
}

/// Accesso breve alla palette del tema attivo. Senza estensione nel tema
/// (ad esempio un `MaterialApp` di prova) si usa la palette chiara.
extension CenatoColoriContesto on BuildContext {
  CenatoColori get colori =>
      Theme.of(this).extension<CenatoColori>() ?? CenatoColori.chiaro;
}

/// Area di tocco minima (RNF_U_3: almeno 48 dp).
const double areaToccoMinima = 48;

TextTheme _testi(CenatoColori c) {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light)
      .textTheme
      .apply(fontFamily: fontTesto, bodyColor: c.testo, displayColor: c.testo);

  TextStyle? titolo(TextStyle? stile, FontWeight peso) =>
      stile?.copyWith(fontFamily: fontTitoli, fontWeight: peso);

  return base.copyWith(
    displayLarge: titolo(base.displayLarge, FontWeight.w800),
    displayMedium: titolo(base.displayMedium, FontWeight.w800),
    displaySmall: titolo(base.displaySmall, FontWeight.w800),
    headlineLarge: titolo(base.headlineLarge, FontWeight.w800),
    headlineMedium: titolo(base.headlineMedium, FontWeight.w700),
    headlineSmall: titolo(base.headlineSmall, FontWeight.w700),
    titleLarge: titolo(base.titleLarge, FontWeight.w700),
    titleMedium: titolo(base.titleMedium, FontWeight.w600),
    titleSmall: titolo(base.titleSmall, FontWeight.w600),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
  );
}

/// Transizioni di pagina: dissolvenza in avanti (Material 3) ovunque, con
/// "riduci animazioni" rispettato. iOS e macOS tengono quelle predefinite
/// (scorrimento con il gesto "indietro").
PageTransitionsTheme _transizioniDiPagina() {
  const dissolvenza = TransizionePagina(FadeForwardsPageTransitionsBuilder());
  return PageTransitionsTheme(
    builders: {
      ...const PageTransitionsTheme().builders,
      TargetPlatform.android: dissolvenza,
      TargetPlatform.fuchsia: dissolvenza,
      TargetPlatform.linux: dissolvenza,
      TargetPlatform.windows: dissolvenza,
    },
  );
}

/// Tema Material 3 chiaro dell'app: stile "app salute" con sfondo chiaro,
/// card bianche con ombra morbida, controlli a pillola.
///
/// Il testo segue la dimensione scelta nelle impostazioni del telefono
/// (testo ridimensionabile, RNF_U_3): non si fissano scale nel codice.
ThemeData temaCenato() {
  const c = CenatoColori.chiaro;
  final testi = _testi(c);

  final schema = ColorScheme.fromSeed(
    seedColor: c.primario,
    primary: c.primario,
    onPrimary: c.sulPrimario,
    secondaryContainer: c.primarioTonale,
    onSecondaryContainer: c.primario,
    surface: c.superficie,
    onSurface: c.testo,
    onSurfaceVariant: c.testoSecondario,
    outlineVariant: c.bordo,
    error: c.errore,
    surfaceTint: Colors.transparent,
  );

  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const dimensioneMinima = Size(areaToccoMinima, areaToccoMinima);
  final testoBottoni = testi.labelLarge!.copyWith(fontSize: 16);
  const ombra = Color(0x33102A1E);

  OutlineInputBorder bordoCampo(Color colore, [double spessore = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colore, width: spessore),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: schema,
    textTheme: testi,
    scaffoldBackgroundColor: c.sfondo,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    extensions: const [c],
    pageTransitionsTheme: _transizioniDiPagina(),
    appBarTheme: AppBarTheme(
      backgroundColor: c.sfondo,
      foregroundColor: c.testo,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: testi.titleLarge,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: c.superficie,
      elevation: 2,
      shadowColor: ombra,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: dimensioneMinima,
        shape: forma,
        textStyle: testoBottoni,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: dimensioneMinima,
        shape: forma,
        side: BorderSide(color: c.primario, width: 1.5),
        textStyle: testoBottoni,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: dimensioneMinima,
        textStyle: testoBottoni,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primario,
      foregroundColor: c.sulPrimario,
      elevation: 3,
      shape: const StadiumBorder(),
      extendedTextStyle: testoBottoni,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.superficie,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: bordoCampo(c.bordoCampo),
      enabledBorder: bordoCampo(c.bordoCampo),
      focusedBorder: bordoCampo(c.primario, 2),
      errorBorder: bordoCampo(c.errore),
      focusedErrorBorder: bordoCampo(c.errore, 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: ombra,
      indicatorColor: c.primarioTonale,
      indicatorShape: const StadiumBorder(),
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (stati) => IconThemeData(
          size: 26,
          color: stati.contains(WidgetState.selected)
              ? c.primario
              : c.testoSecondario,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (stati) => TextStyle(
          fontFamily: fontTesto,
          fontSize: 13,
          fontWeight: stati.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: stati.contains(WidgetState.selected)
              ? c.primario
              : c.testoSecondario,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.superficie,
      selectedColor: c.primarioTonale,
      side: WidgetStateBorderSide.resolveWith(
        (stati) => stati.contains(WidgetState.selected)
            ? BorderSide(color: c.primario, width: 1.5)
            : BorderSide(color: c.bordoCampo),
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      labelStyle: testi.labelLarge?.copyWith(color: c.testo),
      secondaryLabelStyle: testi.labelLarge?.copyWith(
        color: c.primario,
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.testo,
      contentTextStyle: testi.bodyMedium?.copyWith(color: c.superficie),
      shape: forma,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: testi.titleLarge,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.superficie,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.bordo, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primario),
  );
}
