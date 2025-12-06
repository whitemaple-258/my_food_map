// lib/constants.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // DBのファイル名を定義
  static const String dbFileName = 'my_map_log_v4.db';
  static String get googleApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // DBのフルパスを取得するメソッド（全員これを使う！）
  static Future<String> getDbPath() async {
    final dbDir = await getDatabasesPath();
    return join(dbDir, dbFileName);
  }
}

// ジャンルの定義
const Map<String, String> genreMap = {
  'ramen': 'ラーメン',
  'meat': '肉料理',
  'japanese': '和食',
  'cafe': 'カフェ',
  'western': '洋食',
  'bar': '居酒屋',
  'other': 'その他',
};
