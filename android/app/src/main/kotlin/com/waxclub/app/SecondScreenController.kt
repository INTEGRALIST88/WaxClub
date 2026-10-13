package com.waxclub.app

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import android.view.WindowManager
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.MethodChannel

/**
 * Segunda tela pelo Smart View / Miracast (lib/services/second_screen_service.dart).
 *
 * Quando o usuário espelha o celular numa TV, o Android cria uma tela de apresentação. Em vez de
 * copiar a tela do celular, o WaxClub mostra nela só a letra (a mesma página da TV, servida pelo
 * próprio celular em http://127.0.0.1:8088) e o celular continua com o painel de controle.
 */
class SecondScreenController(private val activity: Activity, private val channel: MethodChannel) {
    private val displayManager = activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val main = Handler(Looper.getMainLooper())
    private var presentation: LyricsPresentation? = null
    private var pendingUrl: String? = null

    private val listener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = notifyState()
        override fun onDisplayChanged(displayId: Int) = notifyState()
        override fun onDisplayRemoved(displayId: Int) {
            if (presentation?.display?.displayId == displayId) dismiss()
            notifyState()
        }
    }

    fun start() {
        displayManager.registerDisplayListener(listener, main)
    }

    fun stop() {
        displayManager.unregisterDisplayListener(listener)
        dismiss()
    }

    /** Primeira tela de apresentação disponível (a TV do Smart View/Miracast). */
    private fun presentationDisplay(): Display? =
        displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).firstOrNull()

    fun state(): Map<String, Any?> {
        val d = presentationDisplay()
        return mapOf(
            "available" to (d != null),
            "name" to d?.name,
            "showing" to (presentation?.isShowing == true),
        )
    }

    private fun notifyState() {
        try {
            channel.invokeMethod("state", state())
        } catch (e: Exception) {
            Log.w("WaxClub", "Second screen state not delivered: ${e.message}")
        }
    }

    /** Mostra a letra na segunda tela. Retorna false se não houver tela de apresentação. */
    fun show(url: String): Boolean {
        val d = presentationDisplay() ?: return false
        if (presentation?.isShowing == true && presentation?.display?.displayId == d.displayId) return true
        dismiss()
        pendingUrl = url
        return try {
            presentation = LyricsPresentation(activity, d, url).also { it.show() }
            notifyState()
            true
        } catch (e: WindowManager.InvalidDisplayException) {
            Log.w("WaxClub", "Second screen unavailable: ${e.message}")
            presentation = null
            false
        }
    }

    fun dismiss() {
        presentation?.let {
            try {
                it.dismiss()
            } catch (_: Exception) {
            }
        }
        presentation = null
        notifyState()
    }
}

/** Janela na tela da TV com a página da letra (mesmo visual do Chromecast/Fire TV). */
private class LyricsPresentation(context: Context, display: Display, private val pageUrl: String) :
    Presentation(context, display) {
    private var web: WebView? = null

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val view = WebView(context).apply {
            setBackgroundColor(android.graphics.Color.BLACK)
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.mediaPlaybackRequiresUserGesture = false
            settings.cacheMode = WebSettings.LOAD_NO_CACHE
            webViewClient = WebViewClient()
            loadUrl(pageUrl)
        }
        web = view
        setContentView(view)
    }

    override fun onStop() {
        web?.destroy()
        web = null
        super.onStop()
    }
}
