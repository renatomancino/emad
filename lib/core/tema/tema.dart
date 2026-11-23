import 'package:material_ui/material_ui.dart';

/// Colori di Cenato, presi dai mock-up del RAD (docs/rad/img/ui_paz.png):
/// verde scuro per intestazioni e azioni, sfondo verde chiarissimo, neutri.
/// Promessa grafica: rapidità, chiarezza, motivazione (RAD §3.4.5).
abstract final class ColoriCenato {
  /// Verde principale. Contrasto con il bianco circa 6,5:1 (WCAG AA, RNF_U_3).
  static const primario = Color(0xFF2F6B4F);
  static const primarioChiaro = Color(0xFFDDEFE3);
  static const sfondo = Color(0xFFF4F8F5);
  static const superficie = Color(0xFFFFFFFF);
  static const bordo = Color(0xFFD3E0D7);
  static const testo = Color(0xFF1C2421);
  static const testoSecondario = Color(0xFF5D6B64);
  static const errore = Color(0xFFB3261E);

  // Semaforo dell'aderenza (RF_GAD_2): usati dalla dashboard in fase 3.
  static const semaforoVerde = Color(0xFF2E7D4F);
  static const semaforoGiallo = Color(0xFFB7791F);
  static const semaforoRosso = Color(0xFFC0392B);
}

/// Area di tocco minima (RNF_U_3: almeno 48 dp).
const double areaToccoMinima = 48;

/// Tema Material 3 chiaro dell'app.
///
/// Il testo segue la dimensione scelta nelle impostazioni del telefono
/// (testo ridimensionabile, RNF_U_3): non si fissano scale nel codice.
ThemeData temaCenato() {
  final schema = ColorScheme.fromSeed(
    seedColor: ColoriCenato.primario,
    primary: ColoriCenato.primario,
    onPrimary: Colors.white,
    secondaryContainer: ColoriCenato.primarioChiaro,
    surface: ColoriCenato.superficie,
    error: ColoriCenato.errore,
  );

  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const dimensioneMinima = Size(areaToccoMinima, areaToccoMinima);

  return ThemeData(
    useMaterial3: true,
    colorScheme: schema,
    scaffoldBackgroundColor: ColoriCenato.sfondo,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoriCenato.primario,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: ColoriCenato.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ColoriCenato.bordo),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: dimensioneMinima,
        shape: forma,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: dimensioneMinima,
        shape: forma,
        side: const BorderSide(color: ColoriCenato.primario, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: dimensioneMinima),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoriCenato.superficie,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoriCenato.bordo),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ColoriCenato.superficie,
      indicatorColor: ColoriCenato.primarioChiaro,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (stati) => TextStyle(
          fontSize: 13,
          fontWeight: stati.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: stati.contains(WidgetState.selected)
              ? ColoriCenato.primario
              : ColoriCenato.testoSecondario,
        ),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: ColoriCenato.primarioChiaro,
      side: BorderSide.none,
      shape: StadiumBorder(),
    ),
  );
}
