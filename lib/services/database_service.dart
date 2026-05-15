import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/match_record.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  static Database? _db;

  DatabaseService._();

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'scoretrack.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE matches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_type_id TEXT NOT NULL,
            team1_name TEXT NOT NULL,
            team2_name TEXT NOT NULL,
            score1 INTEGER NOT NULL,
            score2 INTEGER NOT NULL,
            played_at INTEGER NOT NULL,
            winner_name TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE matches ADD COLUMN winner_name TEXT',
          );
        }
      },
    );
  }

  Future<int> insertMatch(MatchRecord record) async {
    final db = await database;
    return db.insert('matches', record.toMap());
  }

  // Supprime les parties en excès pour les utilisateurs gratuits (garde les N plus récentes)
  Future<void> deleteMatchesExceedingLimit(int limit) async {
    final db = await database;
    await db.execute('''
      DELETE FROM matches
      WHERE id NOT IN (
        SELECT id FROM matches ORDER BY played_at DESC LIMIT $limit
      )
    ''');
  }

  Future<List<MatchRecord>> getLastMatches({int limit = 5}) async {
    final db = await database;
    final rows =
        await db.query('matches', orderBy: 'played_at DESC', limit: limit);
    return rows.map(MatchRecord.fromMap).toList();
  }

  Future<List<MatchRecord>> getAllMatches() async {
    final db = await database;
    final rows = await db.query('matches', orderBy: 'played_at DESC');
    return rows.map(MatchRecord.fromMap).toList();
  }
}
