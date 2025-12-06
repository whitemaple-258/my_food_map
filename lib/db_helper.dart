import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
// ★重要: パス管理を一元化するファイルをインポート
import 'package:my_food_map/constants.dart'; 

class DBHelper {
  // シングルトンパターン（アプリ内で1つのインスタンスを共有）
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  // DB接続を取得（なければ開く）
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  // ■■■ DB初期化・マイグレーション ■■■
  Future<Database> _initDB() async {
    // ★修正: 共通定数からパスを取得（これでBackupHelperと絶対にズレない）
    String path = await AppConstants.getDbPath();
    
    return await openDatabase(
      path,
      version: 3, // 現在のバージョン
      
      // 新規作成時
      onCreate: (db, version) async {
        await _createSpotsTable(db);
        await _createRemindersTable(db);
      },
      
      // バージョンアップ時 (または復元後の整合性チェック)
      onUpgrade: (db, oldVersion, newVersion) async {
        // テーブルがなければ作る（復元データの不整合対策）
        await _createSpotsTable(db);
        await _createRemindersTable(db);

        // v2 -> v3: リマインドに通知設定(alert_days)を追加
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE reminders ADD COLUMN alert_days INTEGER DEFAULT 3');
          } catch (_) { /* 既にカラムがある場合は無視 */ }
        }
      },
    );
  }

  // --- テーブル作成用SQL ---
  Future<void> _createSpotsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS spots(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        genre TEXT,
        rating REAL,
        recommended_menu TEXT,
        comment TEXT,
        created_at TEXT,
        is_want_to_go INTEGER,
        latitude REAL,
        longitude REAL,
        prefecture TEXT,
        address TEXT
      )
    ''');
  }

  Future<void> _createRemindersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        deadline TEXT,
        memo TEXT,
        created_at TEXT,
        alert_days INTEGER 
      )
    ''');
  }

  // ■■■ スポット(お店)関連の操作 ■■■
  
  // 新規登録
  Future<int> insertSpot(Map<String, dynamic> row, List<String> imagePaths) async {
    final db = await database;
    final id = await db.insert('spots', row);
    await _saveImagePaths(id, imagePaths); // 画像パスは別テーブルで管理
    return id;
  }
  
  // 全件取得 (画像パスも結合して返す)
  Future<List<Map<String, dynamic>>> getSpots() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('spots');
    List<Map<String, dynamic>> result = [];
    
    for (var map in maps) {
      var mutableMap = Map<String, dynamic>.from(map);
      mutableMap['image_paths'] = await _getImagePaths(map['id']);
      result.add(mutableMap);
    }
    return result;
  }

  // 更新
  Future<int> updateSpot(Map<String, dynamic> row, List<String> imagePaths) async {
    final db = await database;
    int id = row['id'];
    await _saveImagePaths(id, imagePaths);
    return await db.update('spots', row, where: 'id = ?', whereArgs: [id]);
  }

  // 削除
  Future<int> deleteSpot(int id) async {
    final db = await database;
    // 関連する画像データも削除
    await db.delete('spot_images', where: 'spot_id = ?', whereArgs: [id]);
    return await db.delete('spots', where: 'id = ?', whereArgs: [id]);
  }

  // --- 画像パス管理用 (内部メソッド) ---
  Future<void> _saveImagePaths(int spotId, List<String> paths) async {
    final db = await database;
    await db.execute('CREATE TABLE IF NOT EXISTS spot_images(id INTEGER PRIMARY KEY AUTOINCREMENT, spot_id INTEGER, image_path TEXT)');
    
    // 一旦全削除して入れ直す（更新処理の簡略化）
    await db.delete('spot_images', where: 'spot_id = ?', whereArgs: [spotId]);
    for (String path in paths) {
      await db.insert('spot_images', {'spot_id': spotId, 'image_path': path});
    }
  }

  Future<List<String>> _getImagePaths(int spotId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> result = await db.query('spot_images', where: 'spot_id = ?', whereArgs: [spotId]);
      return result.map((e) => e['image_path'] as String).toList();
    } catch (_) {
      return []; // テーブルがない等のエラー時は空リスト
    }
  }

  // ■■■ リマインド関連の操作 ■■■
  
  Future<int> insertReminder(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('reminders', row);
  }

  // 期限が近い順に取得
  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = await database;
    return await db.query('reminders', orderBy: 'deadline ASC');
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  // 期限切れを自動削除 (アプリ起動時に呼ぶ)
  Future<int> deleteExpiredReminders() async {
    final db = await database;
    // 今日より前 ( < today ) のデータを削除
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return await db.delete('reminders', where: 'deadline < ?', whereArgs: [todayStr]);
  }
  
  // ■■■ その他ユーティリティ ■■■

  // ジャンルIDの一括置換 (ジャンル削除時に使用)
  Future<void> changeGenre(String oldId, String newId) async {
    final db = await database;
    final spots = await db.query('spots');
    for (var spot in spots) {
      String genres = spot['genre'] as String;
      List<String> genreList = genres.split(',');
      if (genreList.contains(oldId)) {
        // 対象のIDだけ書き換えて保存し直す
        genreList = genreList.map((g) => g == oldId ? newId : g).toList();
        await db.update('spots', {'genre': genreList.join(',')}, where: 'id = ?', whereArgs: [spot['id']]);
      }
    }
  }

  // DBを閉じる (バックアップ前などに呼ぶ)
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null; // ★重要: 変数をnullに戻して、次回アクセス時に開き直させる
    }
  }
}