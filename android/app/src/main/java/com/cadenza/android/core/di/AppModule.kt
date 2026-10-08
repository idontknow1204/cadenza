package com.cadenza.android.core.di

import com.cadenza.android.core.AppConfig
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.session.ConnectionStore
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideSupabaseClient(): SupabaseClient = createSupabaseClient(
        supabaseUrl = AppConfig.supabaseUrl,
        supabaseKey = AppConfig.supabaseAnonKey
    ) {
        install(Auth) {
            scheme = AppConfig.authCallbackScheme
            host = AppConfig.authCallbackHost
        }
        install(Postgrest)
        install(Realtime)
        install(Storage)
        install(Functions)
    }

    @Provides
    @Singleton
    fun provideRepository(client: SupabaseClient): Repository = Repository(client)

    @Provides
    @Singleton
    fun provideConnectionStore(repository: Repository): ConnectionStore = ConnectionStore(repository)
}
