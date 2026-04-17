//
//  AppConstants.swift
//  MusicMindAI
//
//  Константы приложения
//

import Foundation

enum AppConstants {
    enum YandexMusic {
        static let baseURL = "https://api.music.yandex.ru"
        static let accountStatusURLs = [
            "https://api.music.yandex.ru/account/status",
            "https://api.music.yandex.net/account/status"
        ]
        
        static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
        static let acceptHeader = "*/*"
        static let acceptLanguage = "ru"
        static let referer = "https://music.yandex.ru/"
        static let clientHeader = "YandexMusicWebNext/1.0.0"
        static let withoutInvocationInfo = "1"
    }
    
    enum Cache {
        static let tracksFileName = "tracks_cache.json"
        static let soundCloudTracksFileName = "tracks_cache_soundcloud.json"
        static let vkTracksFileName = "tracks_cache_vk.json"
    }
    
    enum UserDefaultsKeys {
        static let yandexCookies = "yandex_music_cookies"
        static let yandexUserId = "yandex_music_user_id"
        static let soundCloudOAuthToken = "soundcloud_oauth_token"
        static let soundCloudUserId = "soundcloud_user_id"
        static let vkToken = "vk_music_token"
        static let vkUserAgent = "vk_music_user_agent"
        static let vkUserId = "vk_music_user_id"
    }
    
    enum VKMusic {
        static let baseURL = "https://api.vk.com/method"
        static let apiVersion = "5.131"
        /// дефолтный user-agent из vkpymusic (KateMobile)
        static let defaultUserAgent = "KateMobileAndroid/56 lite-460 (Android 4.4.2; SDK 19; x86; unknown Android SDK built for x86; en)"
        /// OAuth WebView: id.vk.com → редирект на oauth.vk.com/blank.html#access_token=...
        static let webAuthURL = "https://id.vk.com/auth?return_auth_hash=86570c2509826d7737&redirect_uri=https%3A%2F%2Foauth.vk.com%2Fblank.html&redirect_uri_hash=1df62336dafc41a8c8&force_hash=1&app_id=6287487&response_type=token&code_challenge=&code_challenge_method=&scope=408861919&state="
        static let authRedirectHost = "oauth.vk.com"
        static let authRedirectPath = "/blank.html"
    }
    
    enum SoundCloud {
        static let baseURL = "https://api-v2.soundcloud.com"
        static let clientId = "fmlyTARjbcBtpv2AVaBivvR0IUKNaBUX"
        static let appVersion = "1770115510"
        static let appLocale = "en"
        static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:147.0) Gecko/20100101 Firefox/147.0"
        static let acceptHeader = "application/json, text/javascript, */*; q=0.01"
        static let acceptLanguage = "ru,en-US;q=0.9,en;q=0.8"
        static let referer = "https://soundcloud.com/"
        static let origin = "https://soundcloud.com"
        
        static let webAuthURL = "https://secure.soundcloud.com/web-auth?redirect_uri=https%3A%2F%2Fm.soundcloud.com%2Fsignin%2Fcallback&response_type=code&code_challenge=cNnFvlUmWFQppPAMv3kywQWt9dGqgAugjnYJRYGjU4M&code_challenge_method=S256&state=eyJub25jZSI6IlA1X1h3Tk5pQVg1Sy1RdzNVbmM2X1N6UlRhQTJVc3Y0TWpJVXNuajRlSXMyaUxiV2xaRU9RWXlEM2NvZkJKRkgiLCJjbGllbnRfaWQiOiJLS3pKeG13MTF0WXBDczZUMjRQNHVVWWhxbWphbEc2TSIsImFwcCI6IndlYi1hdXRoIiwib3JpZ2luIjoiaHR0cHM6Ly9tLnNvdW5kY2xvdWQuY29tIiwicGF0aCI6Ii9kaXNjb3ZlciJ9&client_id=KKzJxmw11tYpCs6T24P4uUYhqmjalG6M&device_id=216709-503988-225251-965902&origin=https%3A%2F%2Fm.soundcloud.com&theme=prefers-color-scheme&ui_evo=true&app_id=65097&tracking=local&provider_redirect=true"
        static let signinFallbackURL = "https://soundcloud.com"
    }
    
    enum Logger {
        static let subsystem = "com.musicmind"
    }
}
