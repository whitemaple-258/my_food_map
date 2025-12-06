// lib/constants.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppConstants {
  // DBのファイル名を定義
  static const String dbFileName = 'my_map_log_v4.db';

  // DBのフルパスを取得するメソッド（全員これを使う！）
  static Future<String> getDbPath() async {
    final dbDir = await getDatabasesPath();
    return join(dbDir, dbFileName);
  }
}

// ★ここにあなたのAPIキーを貼り付けてください
const String googleApiKey = "AIzaSyBTgKZfzSWvs9VYwkGdeKNScbcQiPThNzc";

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
