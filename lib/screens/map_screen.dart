import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart'; // ★追加
import 'package:path/path.dart' hide context;
import 'package:sqflite/sqflite.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

import '../db_helper.dart';
import '../image_helper.dart';
import '../constants.dart';
import '../genre_manager.dart';
import 'spot_form_screen.dart';
import 'settings_screen.dart';
import '../widgets/custom_tab_bar.dart';
import '../widgets/filter_modal.dart';
import '../widgets/spot_detail_sheet.dart';
import '../marker_generator.dart';
import 'reminder_screen.dart';

// 切り出したウィジェット
import '../widgets/map_tab_view.dart';
import '../widgets/list_tab_view.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng _currentPosition = const LatLng(35.170915, 136.881537); // 名古屋駅

  Set<Marker> _markers = {};
  Set<Marker> _searchMarkers = {};

  List<Map<String, dynamic>> _filteredSpots = [];
  List<Map<String, dynamic>> _allSpots = [];

  String _filterName = '';
  String? _filterGenre;
  String? _filterPrefecture;
  double? _filterMinRating;

  final TextEditingController _searchBarController = TextEditingController();

  int _selectedIndex = 0;
  bool _isWantToGoMode = false;
  late StreamSubscription _intentDataStreamSubscription;

  // ★追加：近隣チェック済みフラグ（アプリ起動時に1回だけ出すため）
  bool _hasCheckedNearby = false;
  bool _hasReminderAlert = false;

  static final platform = MethodChannel('com.example.my_food_map/sound');

  @override
  void initState() {
    super.initState();
    _initApp();
    _checkLostData();
    _initSharingIntent();
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  // --- 初期化 ---

  Future<void> _initApp() async {
    // ★追加：データの救済措置（間違った場所にあるDBを正しい場所に移動）
    await _migrateOldDataIfNeeded();

    await GenreManager().load();
    await _getCurrentLocation();
    await _loadSpots();

    // 期限切れ削除 & アラートチェック
    await DBHelper().deleteExpiredReminders();
    await _checkReminderAlert();

    if (!_hasCheckedNearby) {
      _checkNearbyWantToGoSpots();
    }
  }

  // ★追加：データ移行（救済）メソッド
  Future<void> _migrateOldDataIfNeeded() async {
    try {
      // 1. 本来あるべき場所 (System DB)
      final dbDir = await getDatabasesPath();
      final systemDbPath = join(dbDir, 'my_map_log_v4.db');
      final systemDbFile = File(systemDbPath);

      // 2. 間違って保存されていたかもしれない場所 (Documents)
      final docDir = await getApplicationDocumentsDirectory();
      final docDbPath = join(docDir.path, 'my_map_log_v4.db');
      final docDbFile = File(docDbPath);

      // 「Documentsにあって、Systemにない（またはサイズが小さい）」なら復旧させる
      if (await docDbFile.exists()) {
        final docSize = await docDbFile.length();
        int sysSize = 0;
        if (await systemDbFile.exists()) {
          sysSize = await systemDbFile.length();
        }

        // Documentsの方がデータが大きければ、それが本物である可能性が高い
        if (docSize > sysSize) {
          print("★データ救済: DocumentsフォルダからDBを復旧します");
          print("Src: $docDbPath ($docSize bytes)");
          print("Dst: $systemDbPath ($sysSize bytes)");

          // DB接続を閉じてからコピー
          await DBHelper().close();

          // フォルダ作成
          await Directory(dbDir).create(recursive: true);

          // 上書きコピー
          await docDbFile.copy(systemDbPath);
          print("★復旧完了");
        }
      }
    } catch (e) {
      print("データ移行エラー: $e");
    }
  }

  Future<void> _checkReminderAlert() async {
    final reminders = await DBHelper().getReminders();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool shouldAlert = false;
    List<String> alertingItems = [];

    for (var item in reminders) {
      final deadline = DateTime.parse(item['deadline']);
      final diff = deadline.difference(today).inDays;

      // DBに保存された個別の設定日数を取得（デフォルト3日）
      final int alertThreshold = item['alert_days'] ?? 3;

      // 残り日数が設定値以下ならアラート（0日=当日も含む）
      if (diff >= 0 && diff <= alertThreshold) {
        shouldAlert = true;
        // リストに追加 ("〇〇 (あとx日)")
        String dayText = diff == 0 ? "今日まで！" : "あと$diff日";
        alertingItems.add("・${item['title']} ($dayText)");
        break;
      }
    }

    if (mounted) {
      setState(() {
        _hasReminderAlert = shouldAlert;
      });

      // ★追加：アラートがある場合、音を鳴らしてポップアップ表示
      if (shouldAlert && alertingItems.isNotEmpty) {
        // 通知音を鳴らす
        try {
          await platform.invokeMethod('playNotificationSound');
        } catch (e) {
          print("音の再生エラー: $e");
        }

        // ポップアップを表示 (awaitで閉じるのを待つ)
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.red),
                SizedBox(width: 8),
                Text("期限のお知らせ", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("以下のリマインド期限が迫っています！"),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: alertingItems
                          .map(
                            (text) => Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 閉じて次へ
                  // 期限タブへ移動したければここで _selectedIndex = 2; setState((){}); としてもOK
                },
                child: const Text("確認"),
              ),
            ],
          ),
        );
      }
    }
  }

  // ★追加：近くの「行ってみたい」お店を探す機能
  Future<void> _checkNearbyWantToGoSpots() async {
    if (!mounted || _allSpots.isEmpty) return;

    // 「行ってみたい」かつ、まだ「行った」になっていないお店を抽出
    final wantToGoSpots = _allSpots
        .where((s) => (s['is_want_to_go'] ?? 0) == 1)
        .toList();

    if (wantToGoSpots.isEmpty) return;

    Map<String, dynamic>? nearestSpot;
    double minDistance = 50.0; // 反応する半径 (メートル)

    for (var spot in wantToGoSpots) {
      final double distance = Geolocator.distanceBetween(
        _currentPosition.latitude,
        _currentPosition.longitude,
        spot['latitude'],
        spot['longitude'],
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestSpot = spot;
      }
    }

    if (nearestSpot != null) {
      _hasCheckedNearby = true; // チェック済みにする

      // ダイアログを表示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("近くのお店が見つかりました📍"),
          content: Text(
            "「行ってみたい」リストにある\n\n『${nearestSpot!['title']}』\n\nの近くにいます。\n「行った」リストに登録しますか？",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("あとで"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openConversionScreen(nearestSpot!); // 変換画面を開く
              },
              child: const Text("登録する"),
            ),
          ],
        ),
      );
    }
  }

  // ★追加：変換画面を開く処理（共通化）
  Future<void> _openConversionScreen(Map<String, dynamic> item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpotFormScreen(
          spot: item,
          isConversion: true, // 変換モードON
        ),
      ),
    );

    if (result == true) {
      _loadSpots();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('おめでとうございます！「行ったお店」に登録しました！🎉')),
        );
      }
    }
  }

  // --- 共有機能 (完全版) ---

  void _initSharingIntent() {
    // 1. アプリ起動中に共有を受け取った場合 (Stream)
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
          _processSharedContent(value);
        }, onError: (err) => print("共有エラー: $err"));

    // 2. アプリ停止状態で共有から起動された場合 (Initial)
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        _processSharedContent(value);
        ReceiveSharingIntent.instance.reset(); // 受け取り済みとしてリセット
      }
    });
  }

  // データの中身を見て振り分ける処理
  void _processSharedContent(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    final firstFile = files.first;

    // タイプによって処理を分岐
    if (firstFile.type == SharedMediaType.text ||
        firstFile.type == SharedMediaType.url) {
      // テキスト（GoogleマップのURLなど）の場合 -> pathにテキストが入っています
      _handleSharedText(firstFile.path);
    } else if (firstFile.type == SharedMediaType.image) {
      // 画像の場合
      _handleSharedFiles(files);
    }
  }

  // ---------------------------------------------------
  // テキスト共有の処理 (metadata_fetch版)
  // ---------------------------------------------------
  Future<void> _handleSharedText(String text) async {
    print("共有されたテキスト: $text");

    // テキストを行ごとに分割
    List<String> lines = text.split('\n');
    String targetUrl = "";
    String potentialName = "";

    // 1. URLと店名候補を探す
    for (String line in lines) {
      String trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith("http")) {
        // 画像用URL(googleusercontent)よりも、地図用URL(maps.google)を優先する
        if (targetUrl.isEmpty || trimmed.contains("maps.google.com")) {
          targetUrl = trimmed;
        }
      } else {
        // URLじゃない行は店名の可能性がある
        if (potentialName.isEmpty) potentialName = trimmed;
      }
    }

    // URLが見つからなかった場合 -> 店名候補で検索
    if (targetUrl.isEmpty) {
      if (potentialName.isNotEmpty) {
        _searchBarController.text = potentialName;
        _performPlacesSearch(potentialName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("共有データから有効な情報が見つかりませんでした")),
        );
      }
      return;
    }

    // URLが見つかった場合 -> 解析へ
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    String? fetchedName;
    try {
      // 店名候補（テキスト1行目）があればそれを優先
      if (potentialName.isNotEmpty) {
        fetchedName = potentialName;
      } else {
        // なければURLから解析
        fetchedName = await _fetchTitleFromUrl(targetUrl);
      }
    } catch (e) {
      print("解析失敗: $e");
    }

    if (mounted) Navigator.pop(context); // ローディング消す

    if (fetchedName != null &&
        fetchedName.isNotEmpty &&
        fetchedName != "Google マップ") {
      // 成功！検索を実行
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("店名を検出: $fetchedName")));
        _searchBarController.text = fetchedName;
        _performPlacesSearch(fetchedName);
      }
    } else {
      // 失敗 (Googleマップというタイトルしか取れなかった場合など)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("店名を取得できませんでした。手動で検索してください。")),
        );
      }
    }
  }

  // ---------------------------------------------------
  // URL解析ロジック (最強版: 偽装アクセス + OGP解析)
  // ---------------------------------------------------
  Future<String?> _fetchTitleFromUrl(String url) async {
    try {
      // 1. スマホブラウザ(iPhone)のフリをしてアクセスする
      // これにより、Googleは「ボット」ではなく「人間」と判断して正しい詳細ページを返します
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1',
        },
      );

      // 2. 最終的にたどり着いたURL（リダイレクト後）を確認
      // URL自体に店名が含まれている場合があるため (例: .../maps/place/店名/...)
      final finalUrl = response.request?.url.toString() ?? url;
      print("解析対象URL: $finalUrl");

      // A. URLから店名抜き出しを試みる
      if (finalUrl.contains("/maps/place/")) {
        try {
          // /maps/place/ の直後にある文字列を取得
          String part = finalUrl.split("/maps/place/")[1];
          String rawName = part.split("/")[0]; // 次のスラッシュまで
          String decodedName = Uri.decodeComponent(
            rawName.replaceAll('+', ' '),
          );

          // 座標データっぽくなければ採用
          if (!RegExp(r'^\d+(\.\d+)?,\d+(\.\d+)?').hasMatch(decodedName)) {
            print("URLから特定成功: $decodedName");
            return decodedName;
          }
        } catch (_) {}
      }

      // 3. 取得したHTMLを解析パッケージに渡す
      var document = MetadataFetch.responseToDocument(response);
      var data = MetadataParser.parse(document);

      // B. 解析結果からタイトルを探す
      if (data != null) {
        String? title = data.title;
        String? desc = data.description;

        print("取得タイトル: $title");
        print("取得説明文: $desc");

        // タイトルがまともなら採用
        if (title != null && title != "Google マップ" && title.isNotEmpty) {
          // ゴミ除去 ("店名 - Google マップ" -> "店名")
          return title.replaceAll(" - Google マップ", "").trim();
        }

        // タイトルがダメなら、説明文(description)から探す
        // descriptionは "★★★★☆ · ラーメン屋 · 〇〇区..." のようになっていることが多い
        if (desc != null && desc.contains("·")) {
          // "·" で区切って、店名っぽい部分（評価の次あたり）を探す
          // Googleマップのdescription形式に依存しますが、最後の手段として有効
          List<String> parts = desc.split("·");
          for (String part in parts) {
            String candidate = part.trim();
            // 明らかにジャンルや住所でないものを店名と推測（簡易的）
            if (candidate.length > 1 && !candidate.contains("★")) {
              print("説明文から推測: $candidate");
              return candidate;
            }
          }
        }
      }
    } catch (e) {
      print("解析エラー: $e");
    }
    return null;
  }

  // 画像共有の処理
  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    if (!mounted) return;
    final List<String> imagePaths = files.map((f) => f.path).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    LatLng targetPos = _currentPosition;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        targetPos = LatLng(position.latitude, position.longitude);
        setState(() => _currentPosition = targetPos);
        try {
          mapController.animateCamera(CameraUpdate.newLatLng(targetPos));
        } catch (_) {}
      }
    } catch (e) {
      print("現在地取得エラー: $e");
    }

    if (mounted) Navigator.pop(context);
    if (mounted)
      _showRegisterMenu(targetPos, fromShare: true, sharedImages: imagePaths);
  }

  Future<void> _checkLostData() async {
    final lostFiles = await ImageHelper().retrieveLostData();
    if (lostFiles.isNotEmpty && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${lostFiles.length}枚の画像を復元しました')));
    }
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
    try {
      mapController.animateCamera(CameraUpdate.newLatLng(_currentPosition));
    } catch (e) {
      /*無視*/
    }
  }

  Future<void> _loadSpots() async {
    final spots = await DBHelper().getSpots();
    if (!mounted) return;
    _allSpots = spots;

    final filteredList = _allSpots.where((item) {
      final int isWantToGoVal = _isWantToGoMode ? 1 : 0;
      if ((item['is_want_to_go'] ?? 0) != isWantToGoVal) return false;
      if (_filterMinRating != null &&
          (item['rating'] ?? 0.0) < _filterMinRating!) {
        return false;
      }
      if (_filterGenre != null) {
        final itemGenres = (item['genre'] as String).split(',');
        if (!itemGenres.contains(_filterGenre)) return false;
      }
      if (_filterPrefecture != null &&
          item['prefecture'] != _filterPrefecture) {
        return false;
      }
      if (_filterName.isNotEmpty) {
        final query = _filterName.toLowerCase();
        final title = item['title'].toString().toLowerCase();
        if (!title.contains(query)) return false;
      }
      return true;
    }).toList();

    filteredList.sort((a, b) => b['created_at'].compareTo(a['created_at']));

    // ★修正：マーカー生成処理（非同期）
    // 色ごとにアイコン画像を生成してキャッシュする（パフォーマンス対策）
    Map<String, BitmapDescriptor> iconCache = {};
    Set<Marker> newMarkers = {};

    for (var item in filteredList) {
      final firstGenreId = (item['genre'] as String).split(',').first;

      // キャッシュになければ生成
      if (!iconCache.containsKey(firstGenreId)) {
        final color = GenreManager().getColor(firstGenreId);
        final icon = await MarkerGenerator.createCustomMarkerBitmap(color);
        iconCache[firstGenreId] = icon;
      }

      newMarkers.add(
        Marker(
          markerId: MarkerId(item['id'].toString()),
          position: LatLng(item['latitude'], item['longitude']),
          infoWindow: InfoWindow(title: item['title']),

          // ★生成したカスタムアイコンを使用
          icon: iconCache[firstGenreId]!,

          onTap: () => _showDetailModal(item),
        ),
      );
    }

    setState(() {
      _filteredSpots = filteredList;
      _markers = newMarkers;
    });
  }

  void _resetFilters() {
    setState(() {
      _filterName = '';
      _filterGenre = null;
      _filterPrefecture = null;
      _filterMinRating = null;
      _searchMarkers.clear();
      _searchBarController.clear();
    });
    _loadSpots();
  }

  void _toggleMode() {
    setState(() {
      _isWantToGoMode = !_isWantToGoMode;
    });
    _resetFilters();
    final modeName = _isWantToGoMode ? "【行ってみたいお店】" : "【行ったお店】";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$modeName モードに切り替えました"),
        backgroundColor: _isWantToGoMode ? Colors.blueAccent : Colors.orange,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // --- 検索 ---
  Future<void> _performPlacesSearch(String query) async {
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url = Uri.parse(
        'https://places.googleapis.com/v1/places:searchText',
      );
      final LatLng center = await mapController.getVisibleRegion().then(
        (r) => LatLng(
          (r.northeast.latitude + r.southwest.latitude) / 2,
          (r.northeast.longitude + r.southwest.longitude) / 2,
        ),
      );
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
            'center': {
              'latitude': center.latitude,
              'longitude': center.longitude,
            },
            'radius': 5000.0,
          },
        },
      });
      final response = await http.post(url, headers: headers, body: body);
      if (mounted) Navigator.pop(context);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['places'] as List?;
        if (results == null || results.isEmpty) {
          _showError('見つかりませんでした');
          return;
        }
        Set<Marker> newSearchMarkers = {};
        List<Map<String, dynamic>> searchResultsList = [];
        double minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
        for (var item in results) {
          final name = item['displayName']?['text'] ?? '名称不明';
          final address = item['formattedAddress'] ?? '住所不明';
          final lat = item['location']['latitude'] as double;
          final lng = item['location']['longitude'] as double;
          if (lat < minLat) minLat = lat;
          if (lat > maxLat) maxLat = lat;
          if (lng < minLng) minLng = lng;
          if (lng > maxLng) maxLng = lng;
          final position = LatLng(lat, lng);
          searchResultsList.add({
            'name': name,
            'address': address,
            'lat': lat,
            'lng': lng,
          });
          newSearchMarkers.add(
            Marker(
              markerId: MarkerId('search_$lat$lng'),
              position: position,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueMagenta,
              ),
              infoWindow: InfoWindow(
                title: name,
                snippet: "タップして登録",
                onTap: () {
                  _confirmSearchResultRegistration({
                    'name': name,
                    'address': address,
                    'lat': lat,
                    'lng': lng,
                  });
                },
              ),
            ),
          );
        }
        setState(() {
          _searchMarkers = newSearchMarkers;
        });
        if (newSearchMarkers.length == 1) {
          mapController.animateCamera(
            CameraUpdate.newLatLngZoom(newSearchMarkers.first.position, 17.0),
          );
        } else {
          mapController.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
              80.0,
            ),
          );
        }
        if (mounted) {
          _showSearchResultsList(searchResultsList);
        }
      } else {
        _showError('通信エラー: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('エラー: $e');
    }
  }

  void _showSearchResultsList(List<Map<String, dynamic>> results) {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.black12,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 10),
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${results.length}件の検索結果",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.location_on,
                        color: Colors.purple,
                      ),
                      title: Text(
                        item['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        item['address'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        mapController.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(item['lat'], item['lng']),
                            17.0,
                          ),
                        );
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted) _confirmSearchResultRegistration(item);
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmSearchResultRegistration(Map<String, dynamic> place) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(place['name']),
        content: Text('ここを登録しますか？\n${place['address']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('いいえ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startRegistrationFlow(
                LatLng(place['lat'], place['lng']),
                initialTitle: place['name'],
                noImage: true,
              );
            },
            child: const Text('登録する'),
          ),
        ],
      ),
    );
  }

  void _clearSearchResult() {
    setState(() {
      _searchMarkers.clear();
      _searchBarController.clear();
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- 登録・編集・削除 ---
  Future<void> _startRegistrationFlow(
    LatLng targetPos, {
    bool fromCamera = true,
    bool noImage = false,
    String? initialTitle,
    List<String>? initialImagePaths,
    String? initialComment,
  }) async {
    List<String> pickedImagePaths = initialImagePaths ?? [];
    if (!_isWantToGoMode && !noImage && initialImagePaths == null) {
      List<XFile> rawFiles = [];
      if (fromCamera) {
        final file = await ImageHelper().pickImageFromCamera();
        if (file != null) rawFiles.add(file);
      } else {
        rawFiles = await ImageHelper().pickMultiImage();
      }
      if (rawFiles.isEmpty) return;
      pickedImagePaths = rawFiles.map((f) => f.path).toList();
    }
    String prefecture = '';
    String address = '';
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        targetPos.latitude,
        targetPos.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        prefecture = place.administrativeArea ?? '';
        address = '${place.locality ?? ''} ${place.subLocality ?? ''}';
      }
    } catch (e) {
      /*無視*/
    }
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpotFormScreen(
          lat: targetPos.latitude,
          lng: targetPos.longitude,
          prefecture: prefecture,
          address: address,
          initialTitle: initialTitle,
          isWantToGo: _isWantToGoMode,
          initialImagePaths: pickedImagePaths,
        ),
      ),
    );
    if (result == true) {
      _resetFilters();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登録しました！')));
    }
  }

  Future<void> _editSpot(Map<String, dynamic> item) async {
    Navigator.pop(context);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SpotFormScreen(spot: item)),
    );
    if (result == true) {
      _loadSpots();
      try {
        final updatedItem = (await DBHelper().getSpots()).firstWhere(
          (e) => e['id'] == item['id'],
        );
        if (mounted) _showDetailModal(updatedItem);
      } catch (e) {
        /*削除済み*/
      }
    }
  }

  Future<void> _deleteSpot(int id, List<String> imagePaths) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (mounted) Navigator.pop(context);
    for (String path in imagePaths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (e) {
        /*無視*/
      }
    }
    await DBHelper().deleteSpot(id);
    _loadSpots();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('削除しました')));
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => FilterModal(
        allSpots: _allSpots,
        initialName: _filterName,
        initialGenre: _filterGenre,
        initialPrefecture: _filterPrefecture,
        initialMinRating: _filterMinRating,
        showRating: !_isWantToGoMode,
        onApply: (name, genre, pref, minRating) {
          setState(() {
            _filterName = name;
            _filterGenre = genre;
            _filterPrefecture = pref;
            _filterMinRating = minRating;
          });
          _loadSpots();
        },
        onReset: _resetFilters,
      ),
    );
  }

  void _showDetailModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => SpotDetailSheet(
        spot: item,
        onEdit: () => _editSpot(item),
        onDelete: () => _deleteSpot(
          item['id'],
          List<String>.from(item['image_paths'] ?? []),
        ),
        // ★修正: 共通化したメソッドを呼び出す
        onConvertToVisited: () {
          Navigator.pop(modalContext);
          _openConversionScreen(item);
        },
        onGenreTap: (id) {
          Navigator.pop(modalContext);
          setState(() {
            _filterGenre = id;
            _filterName = '';
            _filterPrefecture = null;
            _filterMinRating = null;
          });
          _loadSpots();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("「${GenreManager().getName(id)}」で絞り込みました")),
          );
        },
        onPrefectureTap: (pref) {
          Navigator.pop(modalContext);
          setState(() {
            _filterPrefecture = pref;
            _filterName = '';
            _filterGenre = null;
            _filterMinRating = null;
          });
          _loadSpots();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("「$pref」で絞り込みました")));
        },
      ),
    );
  }

  Future<String?> _identifyPlaceName(LatLng pos) async {
    try {
      final url = Uri.parse(
        'https://places.googleapis.com/v1/places:searchNearby',
      );
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': googleApiKey,
        'X-Goog-FieldMask': 'places.displayName',
      };
      final body = json.encode({
        'locationRestriction': {
          'circle': {
            'center': {'latitude': pos.latitude, 'longitude': pos.longitude},
            'radius': 20.0,
          },
        },
        'languageCode': 'ja',
        'maxResultCount': 1,
      });
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['places'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.first['displayName']['text'];
        }
      }
    } catch (e) {
      print("店名特定エラー: $e");
    }
    return null;
  }

  Future<void> _onMapLongPress(LatLng pos) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    final String? foundName = await _identifyPlaceName(pos);
    if (mounted) Navigator.pop(context);
    if (mounted) _showRegisterMenu(pos, initialTitle: foundName);
  }

  Future<void> _onCameraFabTap() async {
    LatLng mapCenter = await mapController.getVisibleRegion().then(
      (r) => LatLng(
        (r.northeast.latitude + r.southwest.latitude) / 2,
        (r.northeast.longitude + r.southwest.longitude) / 2,
      ),
    );
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }
    final String? foundName = await _identifyPlaceName(mapCenter);
    if (mounted) Navigator.pop(context);
    if (mounted) _showRegisterMenu(mapCenter, initialTitle: foundName);
  }

  void _showRegisterMenu(
    LatLng pos, {
    String? initialTitle,
    bool fromShare = false,
    List<String>? sharedImages,
  }) {
    // 外部アプリからの共有の場合は、モードに関わらず登録フローへ
    if (fromShare && sharedImages != null) {
      _startRegistrationFlow(
        pos,
        noImage: false,
        initialImagePaths: sharedImages,
      );
      return;
    }

    // ★修正: 「行ってみたいモード」ならシンプル確認のみ
    if (_isWantToGoMode) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("行ってみたいお店に登録"),
          content: Text("「${initialTitle ?? '指定の場所'}」を\nリストに追加しますか？"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // 写真なし(noImage: true)で登録画面へ
                _startRegistrationFlow(
                  pos,
                  noImage: true,
                  initialTitle: initialTitle,
                );
              },
              child: const Text("登録する"),
            ),
          ],
        ),
      );
    } else {
      // ★「行ったモード」なら写真選択メニューを出す（従来通り）
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (initialTitle != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "「$initialTitle」を登録",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('写真を撮って登録'),
                onTap: () {
                  Navigator.pop(context);
                  _startRegistrationFlow(
                    pos,
                    fromCamera: true,
                    initialTitle: initialTitle,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('アルバムから選択'),
                onTap: () {
                  Navigator.pop(context);
                  _startRegistrationFlow(
                    pos,
                    fromCamera: false,
                    initialTitle: initialTitle,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('写真なしで登録'),
                onTap: () {
                  Navigator.pop(context);
                  _startRegistrationFlow(
                    pos,
                    noImage: true,
                    initialTitle: initialTitle,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeColor = _isWantToGoMode
        ? const Color(0xFF64B5F6)
        : const Color(0xFFFFB74D);
    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          if (_isWantToGoMode && _selectedIndex != 2)
            Container(
              width: double.infinity,
              color: Colors.blue[100],
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text(
                "行ってみたいお店リスト",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                MapTabView(
                  currentPosition: _currentPosition,
                  markers: _markers.union(_searchMarkers),
                  searchMarkers: _searchMarkers,
                  isLocationEnabled: true,
                  isWantToGoMode: _isWantToGoMode,
                  searchBarController: _searchBarController,
                  onMapCreated: (c) => mapController = c,
                  onLongPress: _onMapLongPress,
                  onSearchSubmitted: _performPlacesSearch,
                  onClearSearch: _clearSearchResult,
                  onFilterTap: _showFilterModal,
                  onMyLocationTap: () {
                    mapController.animateCamera(
                      CameraUpdate.newLatLng(_currentPosition),
                    );
                  },
                  filterName: _filterName,
                  filterGenre: _filterGenre,
                  filterPrefecture: _filterPrefecture,
                  filterMinRating: _filterMinRating,
                  onClearFilters: _resetFilters,
                  onChipDeletedGenre: (v) {
                    setState(() {
                      _filterGenre = null;
                      _loadSpots();
                    });
                  },
                  onChipDeletedPref: (v) {
                    setState(() {
                      _filterPrefecture = null;
                      _loadSpots();
                    });
                  },
                  onChipDeletedRating: (v) {
                    setState(() {
                      _filterMinRating = null;
                      _loadSpots();
                    });
                  },
                ),
                ListTabView(
                  filteredSpots: _filteredSpots,
                  allSpots: _allSpots,
                  isWantToGoMode: _isWantToGoMode,
                  onTapSpot: _showDetailModal,
                  onFilterTap: _showFilterModal,
                  filterName: _filterName,
                  filterGenre: _filterGenre,
                  filterPrefecture: _filterPrefecture,
                  filterMinRating: _filterMinRating,
                  onClearFilters: _resetFilters,
                  onGenreTap: (id) {
                    setState(() {
                      _filterGenre = id;
                      _filterName = '';
                      _filterPrefecture = null;
                      _filterMinRating = null;
                    });
                    _loadSpots();
                  },
                  onPrefectureTap: (pref) {
                    setState(() {
                      _filterPrefecture = pref;
                      _filterName = '';
                      _filterGenre = null;
                      _filterMinRating = null;
                    });
                    _loadSpots();
                  },
                  onRatingDelete: (v) {
                    setState(() {
                      _filterMinRating = null;
                      _loadSpots();
                    });
                  },
                ),
                ReminderScreen(),
                SettingsScreen(
                  onDataChanged: () {
                    _loadSpots();
                    _checkReminderAlert();
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomTabBar(
        selectedIndex: _selectedIndex,
        isWantToGoMode: _isWantToGoMode,
        showReminderAlert: _hasReminderAlert,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index == 2) _hasReminderAlert = false;
          });
          _loadSpots();
        },
        onLongPress: _toggleMode,
      ),
      floatingActionButton: _selectedIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      "現在地を登録！",
                      style: TextStyle(
                        color: modeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ClipPath(
                    clipper: TriangleClipper(),
                    child: Container(color: Colors.white, height: 8, width: 16),
                  ),
                  const SizedBox(height: 4),
                  FloatingActionButton(
                    onPressed: _onCameraFabTap,
                    heroTag: 'camera_fab',
                    backgroundColor: modeColor,
                    child: const Icon(Icons.add_location_alt, size: 30),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
