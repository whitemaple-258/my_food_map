package com.example.my_food_map

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine // ★これが必要です
import io.flutter.plugin.common.MethodChannel
import android.media.RingtoneManager

class MainActivity: FlutterActivity() {
    // チャンネル名（合言葉のようなもの）
    private val CHANNEL = "com.example.my_food_map/sound"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "playNotificationSound") {
                try {
                    // Androidのデフォルト通知音のURIを取得
                    val notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    // 再生準備
                    val r = RingtoneManager.getRingtone(applicationContext, notification)
                    // 再生
                    r.play()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Could not play sound", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
