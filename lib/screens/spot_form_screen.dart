import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geocoding/geocoding.dart';

import 'package:my_food_map/db_helper.dart';
import 'package:my_food_map/image_helper.dart';
import 'package:my_food_map/widgets/star_rating.dart';
import 'package:my_food_map/constants.dart';
import 'package:my_food_map/genre_manager.dart';

class SpotFormScreen extends StatefulWidget {
  final Map<String, dynamic>? spot;
  final double? lat;
  final double? lng;
  final String? prefecture;
  final String? address;
  final String? initialTitle;
  final bool isWantToGo;
  final List<String>? initialImagePaths;
  // ★追加: 「行ってみたい」から「行った」への変換モードかどうか
  final bool isConversion;

  const SpotFormScreen({
    super.key,
    this.spot,
    this.lat,
    this.lng,
    this.prefecture,
    this.address,
    this.initialTitle,
    this.isWantToGo = false,
    this.initialImagePaths,
    this.isConversion = false, // ★追加
  });

  @override
  State<SpotFormScreen> createState() => _SpotFormScreenState();
}

class _SpotFormScreenState extends State<SpotFormScreen> {
  String _initialTitleText = '';
  final _menuController = TextEditingController();
  final _commentController = TextEditingController();
  final List<String> _selectedGenres = [];
  double _currentRating = 3.0;
  List<String> _imagePaths = [];
  bool _isLoading = false;

  late double _currentLat;
  late double _currentLng;
  String? _currentPrefecture;
  String? _currentAddress;
  String _currentInputValue = "";

  // ★変更: 状態として管理するように変更
  late bool _isWantToGoMode;

  @override
  void initState() {
    super.initState();

    // ★モード判定ロジック
    if (widget.isConversion) {
      _isWantToGoMode = false; // 変換時は強制的に「行った」モード
    } else if (widget.spot != null) {
      _isWantToGoMode = (widget.spot!['is_want_to_go'] as int? ?? 0) == 1;
    } else {
      _isWantToGoMode = widget.isWantToGo;
    }

    // 有効なジャンルIDリストを取得
    final validGenreIds = GenreManager().genres.map((g) => g.id).toSet();

    if (widget.spot != null) {
      // 編集モード (または変換モード)
      _initialTitleText = widget.spot!['title'];

      // 変換モードの場合はメニューとコメントは引き継ぐが、評価は新規入力させる
      _menuController.text = widget.spot!['recommended_menu'] ?? '';
      _commentController.text = widget.spot!['comment'] ?? '';

      String genreString = widget.spot!['genre'] ?? '';
      if (genreString.isNotEmpty) {
        List<String> rawIds = genreString.split(',');
        for (String id in rawIds) {
          final trimmedId = id.trim();
          if (trimmedId.isEmpty) continue;
          if (validGenreIds.contains(trimmedId)) {
            _selectedGenres.add(trimmedId);
          } else {
            if (!_selectedGenres.contains('other')) {
              _selectedGenres.add('other');
            }
          }
        }
      }
      if (_selectedGenres.isEmpty) _selectedGenres.add('other');

      // 変換モードなら評価はデフォルト3.0に戻す、そうでなければ既存の値
      _currentRating = widget.isConversion
          ? 3.0
          : (widget.spot!['rating'] ?? 3.0);

      _imagePaths = List<String>.from(widget.spot!['image_paths'] ?? []);

      _currentLat = widget.spot!['latitude'];
      _currentLng = widget.spot!['longitude'];
      _currentPrefecture = widget.spot!['prefecture'];
      _currentAddress = widget.spot!['address'];
      _currentInputValue = _initialTitleText;
    } else {
      // 新規登録モード
      if (widget.initialTitle != null) {
        _initialTitleText = widget.initialTitle!;
        _currentInputValue = _initialTitleText;
      }
      if (widget.initialImagePaths != null) {
        _imagePaths.addAll(widget.initialImagePaths!);
      }
      _currentLat = widget.lat ?? 0.0;
      _currentLng = widget.lng ?? 0.0;
      _currentPrefecture = widget.prefecture;
      _currentAddress = widget.address;
    }
  }

  // ... (途中の _pickImages, _getPlaceSuggestions, _updateLocationFromSelection は変更なし) ...
  Future<void> _pickImages({required bool fromCamera}) async {
    await Future.delayed(Duration.zero);
    List<XFile> files = [];
    if (fromCamera) {
      final file = await ImageHelper().pickImageFromCamera();
      if (file != null) files.add(file);
    } else {
      files = await ImageHelper().pickMultiImage();
    }
    if (files.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _imagePaths.addAll(files.map((f) => f.path));
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getPlaceSuggestions(String query) async {
    if (query.isEmpty) return [];
    final url = Uri.parse('https://places.googleapis.com/v1/places:searchText');
    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': googleApiKey,
      'X-Goog-FieldMask':
          'places.displayName,places.formattedAddress,places.location',
    };
    final body = json.encode({
      'textQuery': query,
      'languageCode': 'ja',
      'locationBias': {
        'circle': {
          'center': {'latitude': _currentLat, 'longitude': _currentLng},
          'radius': 50000.0,
        },
      },
    });
    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['places'] as List?;
        if (results != null) {
          return results
              .map(
                (place) => {
                  'name': place['displayName']['text'],
                  'address': place['formattedAddress'],
                  'lat': place['location']['latitude'],
                  'lng': place['location']['longitude'],
                },
              )
              .toList()
              .cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      print("候補取得エラー: $e");
    }
    return [];
  }

  Future<void> _updateLocationFromSelection(Map<String, dynamic> place) async {
    setState(() => _isLoading = true);
    final double lat = place['lat'];
    final double lng = place['lng'];
    final String address = place['address'];
    String newPrefecture = '';
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        newPrefecture = placemarks.first.administrativeArea ?? '';
      }
    } catch (e) {
      print("逆ジオコーディングエラー: $e");
    }
    if (!mounted) return;
    setState(() {
      _currentLat = lat;
      _currentLng = lng;
      _currentAddress = address;
      _currentPrefecture = newPrefecture;
      _isLoading = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('位置情報を更新しました')));
  }

  Future<void> _saveSpot(String currentTitle) async {
    if (_isLoading) return;

    if (_selectedGenres.isEmpty) {
      _selectedGenres.add('other');
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 100));

    List<String> finalPaths = [];
    if (!_isWantToGoMode) {
      // 「行った」モードなら画像を保存
      for (String path in _imagePaths) {
        if (path.contains('app_flutter') || path.contains('Documents')) {
          finalPaths.add(path);
        } else {
          final newPath = await ImageHelper().saveImage(path);
          if (newPath != null) finalPaths.add(newPath);
        }
      }
    }

    final String titleToSave = currentTitle.trim().isEmpty
        ? '名無し'
        : currentTitle;

    Map<String, dynamic> data = {
      'title': titleToSave,
      'genre': _selectedGenres.join(','),
      'rating': _isWantToGoMode ? 0.0 : _currentRating,
      'recommended_menu': _menuController.text,
      'comment': _commentController.text,
      'created_at': DateTime.now().toString(), // 更新日時
      'is_want_to_go': _isWantToGoMode ? 1 : 0, // ★ここが0になるのでリストから移動する
      'latitude': _currentLat,
      'longitude': _currentLng,
      'prefecture': _currentPrefecture ?? '',
      'address': _currentAddress ?? '',
    };

    if (widget.spot == null) {
      await DBHelper().insertSpot(data, finalPaths);
    } else {
      data['id'] = widget.spot!['id'];

      // ★変換モードの場合は、作成日時も現在時刻に更新して「ついに行った！」感を出す
      if (widget.isConversion) {
        data['created_at'] = DateTime.now().toString();
      } else {
        // 通常編集なら作成日は維持（またはDB側で更新しないならこのままでOK）
        data['created_at'] = widget.spot!['created_at'];
      }

      if (!_isWantToGoMode) {
        List<String> oldPaths = List<String>.from(
          widget.spot!['image_paths'] ?? [],
        );
        for (String old in oldPaths) {
          if (!finalPaths.contains(old)) {
            try {
              final f = File(old);
              if (await f.exists()) await f.delete();
            } catch (e) {
              /*無視*/
            }
          }
        }
      }
      await DBHelper().updateSpot(data, finalPaths);
    }

    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    String titleText;
    if (widget.isConversion) {
      titleText = '行ったお店として登録！'; // ★変換時のタイトル
    } else {
      titleText = widget.spot == null
          ? (_isWantToGoMode ? '行ってみたいお店を登録' : '行ったお店を登録')
          : '情報を編集';
    }

    final allGenres = GenreManager().genres;

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: _isWantToGoMode
            ? Colors.blue[100]
            : Colors.orange[100], // 変換時はオレンジ系に
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : () => _saveSpot(_currentInputValue),
          ),
        ],
      ),
      // ... 以下UI部分は変更なし (自動的に isWantToGoMode=false のUIが表示されます)
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isWantToGoMode) ...[
                  SizedBox(
                    height: 120,
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      header: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.camera_alt),
                              onPressed: _isLoading
                                  ? null
                                  : () => _pickImages(fromCamera: true),
                            ),
                            IconButton(
                              icon: const Icon(Icons.photo_library),
                              onPressed: _isLoading
                                  ? null
                                  : () => _pickImages(fromCamera: false),
                            ),
                          ],
                        ),
                      ),
                      onReorder: (int oldIndex, int newIndex) {
                        setState(() {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }
                          final String item = _imagePaths.removeAt(oldIndex);
                          _imagePaths.insert(newIndex, item);
                        });
                      },
                      proxyDecorator: (child, index, animation) => Material(
                        color: Colors.transparent,
                        child: Transform.scale(scale: 1.05, child: child),
                      ),
                      itemCount: _imagePaths.length,
                      itemBuilder: (context, index) {
                        final path = _imagePaths[index];
                        return Stack(
                          key: ValueKey(path),
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(path),
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                  cacheWidth: 300,
                                  errorBuilder: (c, o, s) => Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 0,
                              child: GestureDetector(
                                onTap: _isLoading
                                    ? null
                                    : () => setState(
                                        () => _imagePaths.removeAt(index),
                                      ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                LayoutBuilder(
                  builder: (context, constraints) {
                    return Autocomplete<Map<String, dynamic>>(
                      initialValue: TextEditingValue(text: _initialTitleText),
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                            if (textEditingValue.text == '') {
                              return const Iterable<
                                Map<String, dynamic>
                              >.empty();
                            }
                            return await _getPlaceSuggestions(
                              textEditingValue.text,
                            );
                          },
                      displayStringForOption: (Map<String, dynamic> option) =>
                          option['name'],
                      onSelected: (Map<String, dynamic> selection) {
                        _currentInputValue = selection['name'];
                        _updateLocationFromSelection(selection);
                        FocusScope.of(context).unfocus();
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            if (textEditingController.text.isEmpty &&
                                _initialTitleText.isNotEmpty &&
                                _currentInputValue == _initialTitleText) {
                              textEditingController.text = _initialTitleText;
                            }
                            textEditingController.addListener(() {
                              _currentInputValue = textEditingController.text;
                            });
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              enableInteractiveSelection: true,
                              decoration: const InputDecoration(
                                labelText: '店名 (検索候補から選択で場所も更新)',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.search),
                              ),
                              onChanged: (value) {
                                _currentInputValue = value;
                              },
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: 200,
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.location_on,
                                      color: Colors.grey,
                                    ),
                                    title: Text(
                                      option['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      option['address'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 15),
                const Text(
                  "ジャンル (複数選択可)",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: allGenres.map((genre) {
                    final isSelected = _selectedGenres.contains(genre.id);
                    return FilterChip(
                      label: Text(genre.name),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedGenres.add(genre.id);
                          } else {
                            _selectedGenres.remove(genre.id);
                          }
                        });
                      },
                      selectedColor: Colors.orange[100],
                      checkmarkColor: Colors.orange,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),
                if (!_isWantToGoMode) ...[
                  const Text(
                    "評価",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  StarRating(
                    rating: _currentRating,
                    onRatingChanged: (v) => setState(() => _currentRating = v),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _menuController,
                  decoration: InputDecoration(
                    labelText: _isWantToGoMode ? '気になっているメニュー' : 'イチオシメニュー',
                    icon: const Icon(Icons.restaurant_menu),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    labelText: 'メモ・備考',
                    icon: Icon(Icons.note),
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.grey[100],
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "登録される場所:",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${_currentPrefecture ?? ''} ${_currentAddress ?? '住所不明'}",
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
