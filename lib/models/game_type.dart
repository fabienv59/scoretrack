enum GameType {
  petanque('Pétanque', '🎯', 13),
  pingpong('Ping-pong', '🏓', 11),
  darts('Fléchettes', '🎯', 501),
  babyfoot('Baby-foot', '⚽', 10),
  badminton('Badminton', '🏸', 21),
  molkky('Mölkky', '🪵', 50),
  volleyball('Volleyball', '🏐', 0),
  custom('Personnalisé', '🎮', 0);

  const GameType(this.label, this.emoji, this.targetScore);

  final String label;
  final String emoji;
  final int targetScore; // 0 = pas de limite / géré en interne

  /// Sous-titre affiché sur la carte de sélection du jeu.
  String get subtitle {
    switch (this) {
      case GameType.volleyball:
        return 'Best of 5 sets · 25 pts · 15 tie-break';
      case GameType.molkky:
        return 'Exactement 50 pts · 3 ratés = éliminé';
      case GameType.custom:
        return 'Règles libres';
      default:
        return targetScore > 0 ? 'Jusqu\'à $targetScore pts' : 'Score libre';
    }
  }

  /// Si non-null, utilise Image.asset au lieu de l'emoji
  String? get assetImage {
    if (this == GameType.petanque) return 'assets/images/petanque.png';
    return null;
  }

  static GameType fromId(String id) => GameType.values
      .firstWhere((g) => g.name == id, orElse: () => GameType.custom);
}
