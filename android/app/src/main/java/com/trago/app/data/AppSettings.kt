package com.trago.app.data

import android.content.Context
import com.trago.app.BuildConfig

/**
 * Persistência local mínima das configurações de conexão (base URL e token
 * demo). Dados sintéticos/desenvolvimento apenas; sem credenciais produtivas.
 * O token demo (`dev:*`) só existe em builds de debug (`BuildConfig.DEMO_TOKEN`).
 */
class AppSettings(context: Context) {

    private val prefs = context.getSharedPreferences("trago_settings", Context.MODE_PRIVATE)

    var baseUrl: String
        get() = prefs.getString(KEY_BASE_URL, null) ?: BuildConfig.API_BASE_URL
        set(value) = prefs.edit().putString(KEY_BASE_URL, value).apply()

    var token: String
        get() = prefs.getString(KEY_TOKEN, null) ?: BuildConfig.DEMO_TOKEN
        set(value) = prefs.edit().putString(KEY_TOKEN, value).apply()

    companion object {
        private const val KEY_BASE_URL = "api_base_url"
        private const val KEY_TOKEN = "demo_token"
    }
}
