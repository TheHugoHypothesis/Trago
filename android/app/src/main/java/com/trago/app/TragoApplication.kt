package com.trago.app

import android.app.Application
import com.trago.app.data.AppSettings
import com.trago.app.data.DefaultTragoRepository
import com.trago.app.data.TragoRepository
import com.trago.app.data.api.ApiClient

class TragoApplication : Application() {

    val settings: AppSettings by lazy { AppSettings(this) }

    val repository: TragoRepository by lazy {
        DefaultTragoRepository(settings) { baseUrl, token -> ApiClient.create(baseUrl, token) }
    }
}
