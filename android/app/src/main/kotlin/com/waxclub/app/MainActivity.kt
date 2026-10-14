package com.waxclub.app

import android.content.Context
import android.content.Intent
import android.net.Uri
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
