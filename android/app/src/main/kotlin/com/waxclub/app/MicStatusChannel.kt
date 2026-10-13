package com.waxclub.app

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.util.Log

/**
 * Estado do microfone durante a captura do WaxClub (lib/services/mic_busy_service.dart).
 * O Android silencia a captura de um app quando um app de acessibilidade ou uma chamada de voz
 * (VOICE_COMMUNICATION) está usando o microfone; isso não pode ser contornado, só avisado.
 */
object MicStatusChannel {
    /**
     * silenced: a captura deste app está sendo silenciada pelo sistema (Android 10+).
     * recordings: quantas capturas estão ativas no aparelho (inclui a do WaxClub, se estiver gravando).
     */
    fun status(context: Context): Map<String, Any> {
        return try {
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val configs = am.activeRecordingConfigurations
            val silenced = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && configs.any { it.isClientSilenced }
            mapOf("silenced" to silenced, "recordings" to configs.size, "sdk" to Build.VERSION.SDK_INT)
        } catch (e: Exception) {
            Log.w("WaxClub", "Mic status unavailable: ${e.message}")
            mapOf("silenced" to false, "recordings" to 0, "sdk" to Build.VERSION.SDK_INT)
        }
    }
}
