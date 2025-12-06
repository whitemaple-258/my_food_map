import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerGenerator {
  // 指定された色でピンの画像を生成する
  static Future<BitmapDescriptor> createCustomMarkerBitmap(Color color) async {
    // 1. 描画の準備
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // ピンの大きさ (ピクセル)
    const double size = 100.0;

    // 2. アイコン（Icons.location_on）を描画
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // ピンのアイコン設定
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.location_on.codePoint), // ピンの形
      style: TextStyle(
        fontSize: size,
        fontFamily: Icons.location_on.fontFamily,
        color: color, // ★ここで好きな色に着色！
        // 影をつけて立体感を出す（お好みで）
        shadows: const [
          Shadow(blurRadius: 5, color: Colors.black45, offset: Offset(2, 2)),
        ],
      ),
    );

    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 0));

    // 3. 画像データに変換
    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      (textPainter.height).toInt(),
    );

    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    // 4. BitmapDescriptorとして返す
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
}
