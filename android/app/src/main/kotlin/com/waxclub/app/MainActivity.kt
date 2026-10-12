package com.waxclub.app

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

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
        try {
            multicastLock?.let { if (it.isHeld) it.release() }
            wifiLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {}
    }
}
