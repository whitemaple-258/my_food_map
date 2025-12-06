import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GenreData {
  String id;
  String name;
  double hue; // 旧データ互換用
  int? colorValue; // 正確な色情報 (ARGB int)

  GenreData({
    required this.id,
    required this.name,
    required this.hue,
    this.colorValue,
  });

  Color get color {
    if (colorValue != null) {
      return Color(colorValue!);
    }
    // 色情報がない場合はhueから近似色を生成して返す
    return HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hue': hue,
    'colorValue': colorValue,
  };

  factory GenreData.fromJson(Map<String, dynamic> json) {
    return GenreData(
      id: json['id'],
      name: json['name'],
      hue: (json['hue'] as num).toDouble(),
      colorValue: json['colorValue'],
    );
  }
}

class GenreManager {
  static final GenreManager _instance = GenreManager._internal();
  factory GenreManager() => _instance;
  GenreManager._internal();

  List<GenreData> _genres = [];
  List<GenreData> get genres => _genres;

  // デフォルト定義
  final List<GenreData> _defaultGenres = [
    GenreData(
      id: 'ramen',
      name: 'ラーメン',
      hue: 30.0,
      colorValue: Colors.orange.value,
    ),
    GenreData(
      id: 'cafe',
      name: 'カフェ',
      hue: 30.0,
      colorValue: const Color(0xFF795548).value,
    ),
    GenreData(
      id: 'italian',
      name: 'イタリアン',
      hue: 0.0,
      colorValue: Colors.red.value,
    ),
    GenreData(
      id: 'french',
      name: 'フレンチ',
      hue: 240.0,
      colorValue: Colors.blue.value,
    ),
    GenreData(
      id: 'chinese',
      name: '中華',
      hue: 50.0,
      colorValue: const Color(0xFFFDD835).value,
    ),
    GenreData(
      id: 'japanese',
      name: '和食',
      hue: 200.0,
      colorValue: Colors.indigo.value,
    ),
    GenreData(
      id: 'izakaya',
      name: '居酒屋',
      hue: 270.0,
      colorValue: Colors.deepPurple.value,
    ),
    GenreData(
      id: 'bar',
      name: 'バー',
      hue: 260.0,
      colorValue: Colors.black.value,
    ),
    GenreData(
      id: 'sweets',
      name: 'スイーツ',
      hue: 330.0,
      colorValue: const Color(0xFFF48FB1).value,
    ),
    GenreData(
      id: 'bakery',
      name: 'パン屋',
      hue: 40.0,
      colorValue: const Color(0xFFD7CCC8).value,
    ),
    GenreData(
      id: 'curry',
      name: 'カレー',
      hue: 60.0,
      colorValue: const Color(0xFFFFAB00).value,
    ),
    GenreData(
      id: 'steak',
      name: '焼肉・肉',
      hue: 0.0,
      colorValue: const Color(0xFFB71C1C).value,
    ),
    GenreData(
      id: 'other',
      name: 'その他',
      hue: 210.0,
      colorValue: Colors.grey.value,
    ),
  ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('genres_v1');

    if (jsonStr == null) {
      // 初回起動時
      _genres = _defaultGenres
          .map(
            (e) => GenreData(
              id: e.id,
              name: e.name,
              hue: e.hue,
              colorValue: e.colorValue,
            ),
          )
          .toList();
    } else {
      // 保存データがある場合
      final List<dynamic> jsonList = json.decode(jsonStr);
      final List<GenreData> loadedList = jsonList
          .map((e) => GenreData.fromJson(e))
          .toList();
      bool needsUpdate = false; // データ更新が必要かどうかのフラグ

      for (var genre in loadedList) {
        try {
          // 1. デフォルト定義にあるか確認
          final defaultMatch = _defaultGenres.firstWhere(
            (d) => d.id == genre.id,
          );

          // 色情報が古い、またはデフォルトと異なる場合は最新の定義で上書き
          if (genre.colorValue != defaultMatch.colorValue) {
            genre.colorValue = defaultMatch.colorValue;
            genre.hue = defaultMatch.hue;
            needsUpdate = true;
          }
        } catch (e) {
          // 2. ユーザー独自のジャンル（IDがデフォルトにない）の場合
          // 色情報(colorValue)が欠落しているなら、hueから生成して補完する
          if (genre.colorValue == null) {
            genre.colorValue = HSVColor.fromAHSV(
              1.0,
              genre.hue,
              1.0,
              1.0,
            ).toColor().value;
            needsUpdate = true;
          }
        }
      }

      _genres = loadedList;

      // もしデータの補完や更新が行われたら、すぐに保存し直す
      if (needsUpdate) {
        await _save();
      }
    }
  }

  String getName(String id) {
    try {
      return _genres.firstWhere((g) => g.id == id).name;
    } catch (e) {
      return 'その他';
    }
  }

  Color getColor(String id) {
    try {
      return _genres.firstWhere((g) => g.id == id).color;
    } catch (e) {
      return Colors.grey;
    }
  }

  double getHue(String id) {
    try {
      return _genres.firstWhere((g) => g.id == id).hue;
    } catch (e) {
      return BitmapDescriptor.hueAzure;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = json.encode(_genres.map((e) => e.toJson()).toList());
    await prefs.setString('genres_v1', jsonStr);
  }

  Future<void> addGenre(String name, Color color) async {
    final id = 'genre_${DateTime.now().millisecondsSinceEpoch}';
    final hsv = HSVColor.fromColor(color);
    _genres.add(
      GenreData(id: id, name: name, hue: hsv.hue, colorValue: color.value),
    );
    await _save();
  }

  Future<void> updateGenre(String id, String name, Color color) async {
    final index = _genres.indexWhere((g) => g.id == id);
    if (index != -1) {
      final hsv = HSVColor.fromColor(color);
      _genres[index].name = name;
      _genres[index].hue = hsv.hue;
      _genres[index].colorValue = color.value;
      await _save();
    }
  }

  Future<void> deleteGenre(String id) async {
    _genres.removeWhere((g) => g.id == id);
    await _save();
  }
}
