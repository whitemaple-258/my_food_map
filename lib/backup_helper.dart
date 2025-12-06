import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:my_food_map/db_helper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_lib;
// ★定数ファイルをインポート
import 'package:my_food_map/constants.dart';

class BackupHelper {
  // ■■■ データ使用量計算 ■■■
  Future<int> calculateTotalSize() async {
    try {
      int total = 0;
      final appDir = await getApplicationDocumentsDirectory();
      if (appDir.existsSync()) {
        appDir.listSync().forEach((f) {
          if (f is File &&
              (f.path.endsWith('.jpg') || f.path.endsWith('.json'))) {
            total += f.lengthSync();
          }
        });
      }
      // ★修正: constantsからパスを取得
      final dbPath = await AppConstants.getDbPath();
      final dbFile = File(dbPath);
      if (await dbFile.exists()) total += await dbFile.length();

      return total;
    } catch (e) {
      return 0;
    }
  }

  // ■■■ Googleログイン ■■■
  Future<User?> signInWithGoogle() async {
    try {
      final google_lib.GoogleSignInAccount? googleUser =
          await google_lib.GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final google_lib.GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      return userCredential.user;
    } catch (e) {
      print("ログインエラー: $e");
      return null;
    }
  }

  // ■■■ クラウドへのアップロード (世代管理 + 差分 + 安全装置) ■■■
  Future<bool> uploadToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final String uid = user.uid;

    try {
      print("--- バックアップ開始 (UID: $uid) ---");

      // 1. 世代交代 (data -> data_old)
      await _rotateCloudData(uid);

      // 2. DBを閉じる
      await DBHelper().close();

      final appDir = await getApplicationDocumentsDirectory();
      final prefs = await SharedPreferences.getInstance();

      // ★修正: constantsからパスを取得
      final dbPath = await AppConstants.getDbPath();

      // 表札
      final infoFile = File(join(appDir.path, 'user_info.txt'));
      await infoFile.writeAsString(
        "Email: ${user.email}\nUID: $uid\nLast Backup: ${DateTime.now()}",
      );
      await FirebaseStorage.instance
          .ref()
          .child("users/$uid/user_info.txt")
          .putFile(infoFile);

      // ジャンル設定
      final String? genreJson = prefs.getString('genres_v1');
      if (genreJson != null) {
        final genreFile = File(join(appDir.path, 'genres.json'));
        await genreFile.writeAsString(genreJson);
        await FirebaseStorage.instance
            .ref()
            .child("users/$uid/data/genres.json")
            .putFile(genreFile);
      }

      // マイカラー設定
      final List<String>? myColors = prefs.getStringList('my_custom_colors');
      if (myColors != null) {
        final colorFile = File(join(appDir.path, 'colors.json'));
        await colorFile.writeAsString(json.encode(myColors));
        await FirebaseStorage.instance
            .ref()
            .child("users/$uid/data/colors.json")
            .putFile(colorFile);
      }

      // DBファイル (最重要)
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final int size = await dbFile.length();
        // ★安全装置: 1KB以下なら中止
        if (size < 1024) throw "DBファイル破損の疑いあり (サイズ過小)";

        // ★修正: ファイル名もconstantsから取得
        await FirebaseStorage.instance
            .ref()
            .child("users/$uid/data/${AppConstants.dbFileName}")
            .putFile(dbFile);
      }

      // 写真 (差分)
      List<String> uploadedHistory =
          prefs.getStringList('uploaded_images_history') ?? [];
      Set<String> historySet = uploadedHistory.toSet();
      List<String> newHistory = List.from(uploadedHistory);
      final files = appDir.listSync();
      int count = 0;

      for (var file in files) {
        if (file is File && file.path.endsWith('.jpg')) {
          final filename = basename(file.path);
          if (!historySet.contains(filename)) {
            await FirebaseStorage.instance
                .ref()
                .child("users/$uid/images/$filename")
                .putFile(file);
            newHistory.add(filename);
            historySet.add(filename);
            count++;
          }
        }
      }
      await prefs.setStringList('uploaded_images_history', newHistory);

      // 画像カタログ
      final imageListFile = File(join(appDir.path, 'images.json'));
      await imageListFile.writeAsString(json.encode(newHistory));
      await FirebaseStorage.instance
          .ref()
          .child("users/$uid/data/images.json")
          .putFile(imageListFile);

      print("バックアップ完了");
      return true;
    } catch (e) {
      print("バックアップ失敗: $e");
      return false;
    }
  }

  // ★追加：世代交代ロジック
  Future<void> _rotateCloudData(String uid) async {
    final appDir = await getApplicationDocumentsDirectory();
    // ★修正: DBファイル名もconstantsから取得
    final List<String> targetFiles = [
      AppConstants.dbFileName,
      'genres.json',
      'colors.json',
      'images.json',
    ];

    for (var fileName in targetFiles) {
      try {
        final currentRef = FirebaseStorage.instance.ref().child(
          "users/$uid/data/$fileName",
        );
        final oldRef = FirebaseStorage.instance.ref().child(
          "users/$uid/data_old/$fileName",
        );
        final tempFile = File(join(appDir.path, 'temp_rotate_$fileName'));

        await currentRef.writeToFile(tempFile); // DL
        await oldRef.putFile(tempFile); // UP to old
        tempFile.delete();
      } catch (_) {}
    }
  }

  // --- 復元機能 ---
  Future<bool> restoreFromCloud() async {
    return _restoreInternal(isOldVersion: false);
  }

  Future<bool> restoreFromOldVersion() async {
    return _restoreInternal(isOldVersion: true);
  }

  Future<bool> _restoreInternal({required bool isOldVersion}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw "ログインしていません";
    final String uid = user.uid;
    final String folderName = isOldVersion ? "data_old" : "data";

    try {
      final appDir = await getApplicationDocumentsDirectory();
      // ★修正: constantsからパスを取得
      final dbPath = await AppConstants.getDbPath();
      final prefs = await SharedPreferences.getInstance();

      print("--- 復元開始: UID $uid (Target: $folderName) ---");

      // ★修正: ファイル名もconstantsから取得
      final dbRef = FirebaseStorage.instance.ref().child(
        "users/$uid/$folderName/${AppConstants.dbFileName}",
      );

      // 1. DB復元
      try {
        await dbRef.getMetadata();
        print("データ発見。ダウンロード開始...");
        await DBHelper().close();

        await Directory(dirname(dbPath)).create(recursive: true);
        _deleteOldDbFiles(dbPath);

        await dbRef.writeToFile(File(dbPath));
        print("DB復元完了");
      } catch (e) {
        print("データが見つかりません ($folderName): $e");
        return false;
      }

      // 2. 設定ファイル復元
      try {
        final genreFile = File(join(appDir.path, 'genres.json'));
        await FirebaseStorage.instance
            .ref()
            .child("users/$uid/$folderName/genres.json")
            .writeToFile(genreFile);
        await prefs.setString('genres_v1', await genreFile.readAsString());
        genreFile.delete();
      } catch (_) {}

      try {
        final colorFile = File(join(appDir.path, 'colors.json'));
        await FirebaseStorage.instance
            .ref()
            .child("users/$uid/$folderName/colors.json")
            .writeToFile(colorFile);
        final List<dynamic> jsonList = json.decode(
          await colorFile.readAsString(),
        );
        await prefs.setStringList(
          'my_custom_colors',
          jsonList.cast<String>().toList(),
        );
        colorFile.delete();
      } catch (_) {}

      // 3. 画像同期
      await _syncImagesFast(uid, appDir, folderName);

      return true;
    } catch (e) {
      print("復元エラー: $e");
      rethrow;
    }
  }

  Future<void> _syncImagesFast(
    String uid,
    Directory appDir,
    String folderName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> cloudFiles = [];
    try {
      final catalogRef = FirebaseStorage.instance.ref().child(
        "users/$uid/$folderName/images.json",
      );
      final catalogFile = File(join(appDir.path, 'images_catalog_temp.json'));
      await catalogRef.writeToFile(catalogFile);
      final String jsonStr = await catalogFile.readAsString();
      cloudFiles = List<String>.from(json.decode(jsonStr));
      catalogFile.delete();
    } catch (e) {
      if (folderName == "data_old") return;
      final listResult = await FirebaseStorage.instance
          .ref()
          .child("users/$uid/images")
          .listAll();
      cloudFiles = listResult.items.map((e) => e.name).toList();
    }

    List<String> missingFiles = [];
    for (String filename in cloudFiles) {
      final localFile = File(join(appDir.path, filename));
      if (!await localFile.exists()) {
        missingFiles.add(filename);
      }
    }
    await prefs.setStringList('uploaded_images_history', cloudFiles);
    if (missingFiles.isEmpty) return;
    await _downloadInBatches(uid, appDir, missingFiles);
  }

  Future<void> _downloadInBatches(
    String uid,
    Directory appDir,
    List<String> filenames,
  ) async {
    int batchSize = 10;
    for (int i = 0; i < filenames.length; i += batchSize) {
      int end = (i + batchSize < filenames.length)
          ? i + batchSize
          : filenames.length;
      List<String> batch = filenames.sublist(i, end);
      await Future.wait(
        batch.map((filename) async {
          try {
            await FirebaseStorage.instance
                .ref()
                .child("users/$uid/images/$filename")
                .writeToFile(File(join(appDir.path, filename)));
          } catch (_) {}
        }),
      );
    }
  }

  void _deleteOldDbFiles(String dbPath) {
    try {
      final mainDb = File(dbPath);
      final walDb = File('$dbPath-wal');
      final shmDb = File('$dbPath-shm');
      if (mainDb.existsSync()) mainDb.deleteSync();
      if (walDb.existsSync()) walDb.deleteSync();
      if (shmDb.existsSync()) shmDb.deleteSync();
    } catch (_) {}
  }
}
