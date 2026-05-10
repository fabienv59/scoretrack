class MatchRecord {
  final int? id;
  final String gameTypeId;
  final String team1Name;
  final String team2Name;
  final int score1;
  final int score2;
  final DateTime playedAt;

  const MatchRecord({
    this.id,
    required this.gameTypeId,
    required this.team1Name,
    required this.team2Name,
    required this.score1,
    required this.score2,
    required this.playedAt,
  });

  String? get winner {
    if (score1 > score2) return team1Name;
    if (score2 > score1) return team2Name;
    return null;
  }

  factory MatchRecord.fromMap(Map<String, dynamic> map) => MatchRecord(
        id: map['id'] as int?,
        gameTypeId: map['game_type_id'] as String,
        team1Name: map['team1_name'] as String,
        team2Name: map['team2_name'] as String,
        score1: map['score1'] as int,
        score2: map['score2'] as int,
        playedAt:
            DateTime.fromMillisecondsSinceEpoch(map['played_at'] as int),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'game_type_id': gameTypeId,
        'team1_name': team1Name,
        'team2_name': team2Name,
        'score1': score1,
        'score2': score2,
        'played_at': playedAt.millisecondsSinceEpoch,
      };
}
