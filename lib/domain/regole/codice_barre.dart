/// Codici a barre dei prodotti (RF_GP_4, UC_GP_3).
///
/// La fotocamera legge EAN-13, EAN-8, UPC-A e UPC-E. Open Food Facts e la
/// cache (`alimenti.codice_barre`) usano la forma a 13 cifre per gli UPC, che
/// sono un caso particolare di EAN-13 (con uno 0 davanti): normalizzare prima
/// di cercare fa sì che lo stesso prodotto abbia sempre lo stesso codice.
abstract final class CodiceBarre {
  /// Forma accettata dalla colonna `alimenti.codice_barre`.
  static final formatoDb = RegExp(r'^[0-9]{6,14}$');

  /// Codice pronto per la ricerca e la cache, oppure `null` se la lettura non
  /// è valida (lunghezza sbagliata o cifra di controllo errata: una lettura
  /// sporca non deve diventare una ricerca a vuoto).
  ///
  /// [upcE] dice che le 8 cifre sono un UPC-E (formato indicato dallo
  /// scanner) e non un EAN-8: si espandono nell'UPC-A equivalente.
  static String? normalizza(String grezzo, {bool upcE = false}) {
    final codice = grezzo.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(codice)) return null;
    final String gtin;
    switch (codice.length) {
      case 8 when upcE:
        final upcA = espandiUpcE(codice);
        if (upcA == null) return null;
        gtin = '0$upcA';
      case 8 || 13:
        gtin = codice;
      case 12:
        gtin = '0$codice';
      default:
        return null;
    }
    return cifraDiControlloValida(gtin) ? gtin : null;
  }

  /// Controllo modulo 10 dei codici GTIN (EAN-8, UPC-A, EAN-13): pesi 3 e 1
  /// alternati partendo dalla cifra a sinistra di quella di controllo.
  static bool cifraDiControlloValida(String gtin) {
    if (gtin.length < 2 || !RegExp(r'^[0-9]+$').hasMatch(gtin)) return false;
    final cifre = gtin.codeUnits.map((c) => c - 48).toList();
    final controllo = cifre.removeLast();
    var somma = 0;
    for (var i = 0; i < cifre.length; i++) {
      final daDestra = cifre.length - 1 - i;
      somma += cifre[i] * (daDestra.isEven ? 3 : 1);
    }
    return (10 - somma % 10) % 10 == controllo;
  }

  /// UPC-E (8 cifre: sistema 0 o 1, sei cifre, controllo) nell'UPC-A di 12
  /// cifre equivalente; `null` se non è un UPC-E.
  static String? espandiUpcE(String upcE) {
    if (!RegExp(r'^[01][0-9]{7}$').hasMatch(upcE)) return null;
    final s = upcE[0];
    final d = upcE.substring(1, 7);
    final c = upcE[7];
    final ultima = int.parse(d[5]);
    final String corpo;
    if (ultima <= 2) {
      corpo = '${d.substring(0, 2)}${d[5]}0000${d.substring(2, 5)}';
    } else if (ultima == 3) {
      corpo = '${d.substring(0, 3)}00000${d.substring(3, 5)}';
    } else if (ultima == 4) {
      corpo = '${d.substring(0, 4)}00000${d[4]}';
    } else {
      corpo = '${d.substring(0, 5)}0000${d[5]}';
    }
    return '$s$corpo$c';
  }
}

/// Scarta le letture ripetute dello stesso codice: la fotocamera vede lo
/// stesso codice a barre molte volte al secondo, ma la ricerca va fatta una
/// volta sola (scheda Trello, punto 5).
class FiltroLetture {
  FiltroLetture({
    this.intervallo = intervalloStessoCodice,
    DateTime Function()? adesso,
  }) : _adesso = adesso ?? DateTime.now;

  /// Tempo entro cui una nuova lettura dello stesso codice si ignora.
  static const intervalloStessoCodice = Duration(seconds: 3);

  final Duration intervallo;
  final DateTime Function() _adesso;
  String? _ultimo;
  DateTime? _ultimoIl;

  /// Vero se [codice] va elaborato; falso se è lo stesso di poco fa.
  bool accetta(String codice) {
    final adesso = _adesso();
    final ultimoIl = _ultimoIl;
    if (codice == _ultimo &&
        ultimoIl != null &&
        adesso.difference(ultimoIl) < intervallo) {
      return false;
    }
    _ultimo = codice;
    _ultimoIl = adesso;
    return true;
  }
}
