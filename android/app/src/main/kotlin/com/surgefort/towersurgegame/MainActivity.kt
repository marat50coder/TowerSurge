package com.surgefort.towersurgegame

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — TWO native bridges for the WebView / attribution
// ============================================================
//
// 1. FILE UPLOAD BRIDGE (`surgefort/harbor/pickfile`)
//    The site's <input type="file"> triggers the WebView's file
//    selector, which hops here and returns the picked `content://`
//    URIs back into the Flutter side. This bypasses the file_picker
//    plugin (see gray_part_pitfalls.md §1 — file_picker 10.x drags
//    its own KGP and breaks the Flutter build).
//
// 2. LAUNCH-URL / INTENT BRIDGE (`surgefort/tide/intent`)
//    AppsFlyer's UDL callback drops OneLink clicks on the floor in
//    a variety of edge cases (adb-installed builds, GAID collection
//    failure, unverified assetlinks, Chrome App Links dispatching
//    the intent bypassing the referrer, etc). Whenever that happens
//    the launching URL still sits in `getIntent().getData()` — so
//    Flutter can pull it via `getLaunchUrl` and mine it for the
//    sub_id / media_source / campaign params. On warm-tap (a paid
//    link opened while the app is already running) we push the URL
//    across the channel via `onNewLaunchUrl` from `onNewIntent`.
//
// Keep the channel strings in sync with the Dart-side constants in
//   lib/tide/stage/harbor_stage.dart  and  lib/tide/wire/intent_bridge.dart
// ============================================================
class MainActivity : FlutterActivity() {

    companion object {
        private const val HARBOR_UPLOAD_CHANNEL = "surgefort/harbor/pickfile"
        private const val TIDE_INTENT_CHANNEL = "surgefort/tide/intent"
        private const val REQUEST_UPLOAD_PICK = 0x5F27
    }

    private var awaitingResult: MethodChannel.Result? = null
    private var tideChannel: MethodChannel? = null

    /// Latest launch URL captured from the current `Intent`. Cleared
    /// via `consumeLaunchUrl` once Flutter has absorbed it so the
    /// same URL doesn't re-fire on the next configuration change.
    private var pendingLaunchUrl: String? = null

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

        tideChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TIDE_INTENT_CHANNEL,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLaunchUrl" -> {
                        result.success(captureLaunchUrl(intent))
                    }
                    "consumeLaunchUrl" -> {
                        pendingLaunchUrl = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val url = captureLaunchUrl(intent)
        if (url != null) {
            tideChannel?.invokeMethod("onNewLaunchUrl", url)
        }
    }

    private fun captureLaunchUrl(sourceIntent: Intent?): String? {
        val cached = pendingLaunchUrl
        if (cached != null) return cached
        if (sourceIntent == null) return null
        val action = sourceIntent.action ?: return null
        if (action != Intent.ACTION_VIEW) return null
        val data = sourceIntent.data ?: return null
        val url = data.toString()
        if (url.isEmpty()) return null
        pendingLaunchUrl = url
        return url
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
