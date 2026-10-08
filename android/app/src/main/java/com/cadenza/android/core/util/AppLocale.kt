package com.cadenza.android.core.util

// iOS의 localized(ko, en, de) + LanguageBundle 역할.
// 런타임 언어 전환 시 DataStore에서 language를 읽어 이 값을 갱신.
object AppLocale {
    var language: String = "ko"

    fun localized(ko: String, en: String, de: String): String = when (language) {
        "en" -> en
        "de" -> de
        else -> ko
    }
}
