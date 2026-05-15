enum DartsVariant {
  darts501,
  darts301,
  countUp,
  roundTheClock;

  String get label {
    switch (this) {
      case DartsVariant.darts501:
        return '501 Double Out';
      case DartsVariant.darts301:
        return '301 Double Out';
      case DartsVariant.countUp:
        return 'Count Up';
      case DartsVariant.roundTheClock:
        return "L'Horloge";
    }
  }

  String get subtitle {
    switch (this) {
      case DartsVariant.darts501:
        return 'Descend de 501 → 0, finir en double';
      case DartsVariant.darts301:
        return 'Descend de 301 → 0, finir en double';
      case DartsVariant.countUp:
        return 'Score monte · max gagne';
      case DartsVariant.roundTheClock:
        return "Zones 1→20→Bull dans l'ordre";
    }
  }

  bool get isCountdown =>
      this == DartsVariant.darts501 || this == DartsVariant.darts301;

  int get startScore {
    switch (this) {
      case DartsVariant.darts501:
        return 501;
      case DartsVariant.darts301:
        return 301;
      default:
        return 0;
    }
  }
}
