package com.surgefort.towersurgegame

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — native file-upload bridge for the WebView
// ============================================================
// The site's <input type="file"> triggers the WebView's file
// selector, which hops here through the `surgefort/harbor/pickfile`
// MethodChannel and returns the picked `content://` URIs back into
// the Flutter side. This bypasses the file_picker plugin (see
// gray_part_pitfalls.md §1 — file_picker 10.x drags its own KGP and
// breaks the Flutter build).
//
// Keep `HARBOR_UPLOAD_CHANNEL` in sync with the string in
// lib/tide/stage/harbor_stage.dart — one string, two languages.
// ============================================================
class MainActivity : FlutterActivity() {

    companion object {
        private const val HARBOR_UPLOAD_CHANNEL = "surgefort/harbor/pickfile"
        private const val REQUEST_UPLOAD_PICK = 0x5F27
    }

    private var awaitingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HARBOR_UPLOAD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pick" -> {
                    val multiple = call.argument<Boolean>("multiple") ?: false
                    val mimes = call.argument<List<String>>("mimeTypes")
                        ?: emptyList()
                    launchChooser(multiple, mimes, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        awaitingResult?.success(emptyList<String>())
        awaitingResult = result

        val filtered = mimes.filter { it.contains("/") }
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                filtered.isEmpty() -> type = "*/*"
                filtered.size == 1 -> type = filtered[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, filtered.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(
                Intent.createChooser(intent, null),
                REQUEST_UPLOAD_PICK,
            )
        } catch (e: Exception) {
            awaitingResult = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_UPLOAD_PICK) return

        val pending = awaitingResult
        awaitingResult = null
        if (pending == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            pending.success(emptyList<String>())
            return
        }

        val uris = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { uris.add(it.toString()) }
        }
        pending.success(uris)
    }
}
