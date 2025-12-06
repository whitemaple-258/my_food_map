import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';
// ★追加：より自由にアプリを選べるピッカー
import 'package:file_picker/file_picker.dart';

class ImageHelper {
  static final ImageHelper _instance = ImageHelper._internal();
  factory ImageHelper() => _instance;
  ImageHelper._internal();

  final ImagePicker _picker = ImagePicker();

  // 1. 複数枚選択（★修正：FilePickerを使ってアプリを選べるように変更）
  Future<List<XFile>> pickMultiImage() async {
    try {
      // FilePickerを使うと、Android標準の「ファイル選択」画面が開きます。
      // ここで左上のメニューから「フォト」「ギャラリー」「ドライブ」などを自由に選べます。
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image, // 画像ファイルのみ表示
        allowMultiple: true, // 複数選択OK
      );

      if (result != null) {
        // 選択されたファイルのパスを、アプリが扱える XFile 形式に変換して返す
        return result.paths
            .where((path) => path != null)
            .map((path) => XFile(path!))
            .toList();
      }
      return []; // キャンセル時
    } catch (e) {
      print("選択エラー: $e");
      return [];
    }
  }

  // 2. カメラ撮影（変更なし：カメラはImagePickerが最適）
  Future<XFile?> pickImageFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      return null;
    }
  }

  // 3. データ消失対策（変更なし）
  Future<List<XFile>> retrieveLostData() async {
    if (!Platform.isAndroid) return [];
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) return [];
    return response.files ?? [];
  }

  // 4. 保存と圧縮（変更なし）
  Future<String?> saveImage(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final String fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${sourcePath.hashCode}.jpg';
    final String targetPath = join(directory.path, fileName);

    try {
      var result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        quality: 80,
        minWidth: 1280,
        minHeight: 1280,
        format: CompressFormat.jpeg,
      );

      return result?.path;
    } catch (e) {
      print("圧縮保存エラー: $e");
      try {
        final File sourceFile = File(sourcePath);
        await sourceFile.copy(targetPath);
        return targetPath;
      } catch (e2) {
        return null;
      }
    }
  }
}
