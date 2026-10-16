package com.waxclub.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.net.wifi.WifiManager
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var wifiLock: WifiManager.WifiLock? = null
    private var nsdAnnouncer: PhoneNsdAnnouncer? = null

    /** Canal do anúncio do celular na rede (_waxclub._tcp), usado por lib/services/phone_announcer.dart. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.waxclub.app/nsd").setMethodCallHandler { call, result ->
            when (call.method) {
                "register" -> {
                    val serviceType = call.argument<String>("serviceType") ?: "_waxclub._tcp"
                    val serviceName = call.argument<String>("serviceName") ?: "WaxClub"
                    val port = call.argument<Int>("port") ?: 8088
                    val attributes = call.argument<Map<String, String>>("attributes") ?: emptyMap()
                    val announcer = nsdAnnouncer ?: PhoneNsdAnnouncer(this).also { nsdAnnouncer = it }
                    result.success(announcer.register(serviceType, serviceName, port, attributes))
                }
                "unregister" -> {
                    nsdAnnouncer?.unregister()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        // Estado do microfone (silenciado por outro app?), usado por lib/services/mic_busy_service.dart
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.waxclub.app/mic").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(MicStatusChannel.status(this))
                else -> result.notImplemented()
            }
        }
        // Links de instalação de plugins (botão "Install" do site): lib/services/plugins/plugin_links.dart
        val links = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.waxclub.app/links").also { linksChannel = it }
        links.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialLink" -> {
                    // Entregue uma vez só (não reinstala ao recriar a tela)
                    val link = if (initialLinkTaken) null else intent?.data?.toString()
                    initialLinkTaken = true
                    result.success(link)
                }
                "pickLyricsFiles" -> pickLyricsFiles(result)
                // Aba do Chrome por cima do app (Custom Tab): X no canto fecha e volta ao WaxClub; o login do
                // Google funciona (no navegador interno ele é bloqueado). Sem Chrome, abre o navegador comum.
                "openTab" -> {
                    val url = call.argument<String>("url")
                    result.success(
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            val extras = Bundle()
                            extras.putBinder("android.support.customtabs.extra.SESSION", null)
                            intent.putExtras(extras)
                            intent.putExtra("android.support.customtabs.extra.TOOLBAR_COLOR", 0xFF2E1E13.toInt())
                            intent.putExtra("android.support.customtabs.extra.TITLE_VISIBILITY", 1)
                            startActivity(intent)
                            true
                        } catch (_: Exception) {
                            false
                        }
                    )
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    result.success(
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            true
                        } catch (_: Exception) {
                            false
                        }
                    )
                }
                else -> result.notImplemented()
            }
        }
        // Segunda tela do Smart View/Miracast (letra na TV, controles no celular): lib/services/second_screen_service.dart
        val screenChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.waxclub.app/second_screen")
        val screen = SecondScreenController(this, screenChannel).also { secondScreen = it }
        screen.start()
        screenChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "state" -> result.success(screen.state())
                "show" -> result.success(screen.show(call.argument<String>("url") ?: "http://127.0.0.1:8088/"))
                "hide" -> {
                    screen.dismiss()
                    result.success(null)
                }
                "openCastSettings" -> result.success(openCastSettings())
                else -> result.notImplemented()
            }
        }
    }

    private var secondScreen: SecondScreenController? = null
    private var linksChannel: MethodChannel? = null
    private var initialLinkTaken = false

    // ── Plugin S5 "My lyrics files": escolher .lrc/.txt no celular ou no Google Drive ──
    private var pickResult: MethodChannel.Result? = null
    private val pickRequest = 4711

    private fun pickLyricsFiles(result: MethodChannel.Result) {
        if (pickResult != null) {
            result.success(emptyList<Map<String, String>>())
            return
        }
        pickResult = result
        val i = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("text/plain", "application/octet-stream", "application/x-subrip", "*/*"))
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(i, pickRequest)
        } catch (_: Exception) {
            pickResult = null
            result.success(emptyList<Map<String, String>>())
        }
    }

    private fun displayName(uri: Uri): String {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) return c.getString(0) ?: ""
            }
        } catch (_: Exception) {
        }
        return uri.lastPathSegment ?: ""
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return
        val r = pickResult ?: return
        pickResult = null
        if (resultCode != RESULT_OK || data == null) {
            r.success(emptyList<Map<String, String>>())
            return
        }
        val uris = mutableListOf<Uri>()
        val clip = data.clipData
        if (clip != null) {
            for (k in 0 until clip.itemCount) uris.add(clip.getItemAt(k).uri)
        } else {
            data.data?.let { uris.add(it) }
        }
        val files = uris.take(500).mapNotNull { uri ->
            try {
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return@mapNotNull null
                if (bytes.size > 512 * 1024) null else mapOf("name" to displayName(uri), "content" to String(bytes, Charsets.UTF_8))
            } catch (_: Exception) {
                null
            }
        }
        r.success(files)
    }

    /** Link recebido com o app já aberto (singleTop): passa para o Flutter. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val link = intent.data?.toString() ?: return
        linksChannel?.invokeMethod("onLink", link)
    }

    /** Abre a tela do sistema para espelhar a tela (Smart View / Transmitir / Miracast). */
    private fun openCastSettings(): Boolean {
        for (action in listOf("android.settings.CAST_SETTINGS", "android.settings.WIFI_DISPLAY_SETTINGS")) {
            try {
                startActivity(android.content.Intent(action).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: Exception) {
            }
        }
        return false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        acquireNetworkLocks()
    }

    override fun onResume() {
        super.onResume()
        acquireNetworkLocks()
    }

    private fun acquireNetworkLocks() {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            if (wifiManager != null) {
                if (multicastLock == null || multicastLock?.isHeld == false) {
                    multicastLock = wifiManager.createMulticastLock("waxclub:multicast_lock").apply {
                        setReferenceCounted(false)
                        acquire()
                    }
                    Log.d("WaxClub", "MulticastLock acquired successfully")
                }
                if (wifiLock == null || wifiLock?.isHeld == false) {
                    @Suppress("DEPRECATION")
                    wifiLock = wifiManager.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "waxclub:wifi_lock").apply {
                        setReferenceCounted(false)
                        acquire()
                    }
                    Log.d("WaxClub", "WifiLock acquired successfully")
                }
            }
        } catch (e: Exception) {
            Log.w("WaxClub", "Notice: Network lock acquisition skipped: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        secondScreen?.stop()
        nsdAnnouncer?.unregister()
        try {
            multicastLock?.let { if (it.isHeld) it.release() }
            wifiLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {}
    }
}
