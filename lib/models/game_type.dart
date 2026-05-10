enum GameType {
  petanque('Pétanque', '🎯', 13),
  pingpong('Ping-pong', '🏓', 11),
  darts('Fléchettes', '🎯', 501),
  belote('Belote', '🃏', 81),
  babyfoot('Baby-foot', '⚽', 10),
  badminton('Badminton', '🏸', 21),
  molkky('Mölkky', '🪵', 50),
  custom('Personnalisé', '🎮', 0);

  const GameType(this.label, this.emoji, this.targetScore);

  final String label;
  final String emoji;
  final int targetScore; // 0 = pas de limite, fin manuelle

  /// Si non-null, utiliser Image.asset au lieu de l'emoji
  String? get assetImage {
    if (this == GameType.petanque) return 'assets/images/petanque.png';
    return null;
  }

  static GameType fromId(String id) => GameType.values
      .firstWhere((g) => g.name == id, orElse: () => GameType.custom);
}
