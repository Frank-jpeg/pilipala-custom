package com.guozhigq.pilipala

import android.os.SystemClock
import android.view.MotionEvent
// import io.flutter.embedding.android.FlutterActivity
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pilipala/tv_pointer"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "tap" -> {
                    val x = call.argument<Double>("x")?.toFloat()
                    val y = call.argument<Double>("y")?.toFloat()
                    if (x == null || y == null) {
                        result.error("bad_args", "x/y is required", null)
                        return@setMethodCallHandler
                    }
                    window.decorView.post {
                        try {
                            dispatchTap(x, y)
                            result.success(true)
                        } catch (error: Throwable) {
                            result.error("tap_failed", error.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun dispatchTap(x: Float, y: Float) {
        val downTime = SystemClock.uptimeMillis()
        val down = MotionEvent.obtain(
            downTime,
            downTime,
            MotionEvent.ACTION_DOWN,
            x,
            y,
            0
        )
        val up = MotionEvent.obtain(
            downTime,
            downTime + 70,
            MotionEvent.ACTION_UP,
            x,
            y,
            0
        )
        window.decorView.dispatchTouchEvent(down)
        window.decorView.dispatchTouchEvent(up)
        down.recycle()
        up.recycle()
    }
}
