package com.cadenza.android.core

import com.cadenza.android.BuildConfig

object AppConfig {
    val supabaseUrl: String = BuildConfig.SUPABASE_URL
    val supabaseAnonKey: String = BuildConfig.SUPABASE_ANON_KEY
    const val authCallbackScheme = "cadenza"
    const val authCallbackHost = "auth-callback"
    const val authCallbackUrl = "cadenza://auth-callback"
}
