package com.waxclub.app

import android.content.Context
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
        nsdAnnouncer?.unregister()
        try {
            multicastLock?.let { if (it.isHeld) it.release() }
            wifiLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {}
    }
}
