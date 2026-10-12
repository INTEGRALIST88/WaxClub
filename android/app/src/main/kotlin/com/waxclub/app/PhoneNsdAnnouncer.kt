package com.waxclub.app

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.util.Log

/**
 * Anuncia o celular na rede local via mDNS/DNS-SD (ex.: _waxclub._tcp), para os apps de TV
 * (como o receptor do Fire TV) encontrarem sozinhos o servidor da página da TV.
 * Registros TXT: fn = nome amigável, md = modelo do celular, mais os que o Dart enviar.
 */
class PhoneNsdAnnouncer(context: Context) {

    private val nsdManager = context.applicationContext.getSystemService(Context.NSD_SERVICE) as NsdManager
    private var registration: NsdManager.RegistrationListener? = null

    fun register(serviceType: String, baseName: String, port: Int, attributes: Map<String, String>): Boolean {
        unregister()
        // Nome visível na TV: "WaxClub (modelo do celular)"
        val friendlyName = "$baseName (${Build.MODEL})"
        val info = NsdServiceInfo().apply {
            serviceName = friendlyName
            this.serviceType = serviceType
            this.port = port
            setAttribute("fn", friendlyName)
            setAttribute("md", Build.MODEL)
            for ((key, value) in attributes) setAttribute(key, value)
        }

        val listener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) {
                Log.i(TAG, "Anunciado na rede como \"${info.serviceName}\" ($serviceType, porta $port)")
            }

            override fun onRegistrationFailed(info: NsdServiceInfo, errorCode: Int) {
                Log.w(TAG, "Falha ao anunciar na rede (erro $errorCode)")
                registration = null
            }

            override fun onServiceUnregistered(info: NsdServiceInfo) {}

            override fun onUnregistrationFailed(info: NsdServiceInfo, errorCode: Int) {}
        }

        return try {
            nsdManager.registerService(info, NsdManager.PROTOCOL_DNS_SD, listener)
            registration = listener
            true
        } catch (e: Exception) {
            Log.w(TAG, "NSD indisponível: ${e.message}")
            false
        }
    }

    fun unregister() {
        val listener = registration ?: return
        registration = null
        try {
            nsdManager.unregisterService(listener)
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val TAG = "WaxClub"
    }
}
