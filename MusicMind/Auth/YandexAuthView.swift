//
//  YandexAuthView.swift
//  MusicMindAI
//
//  WKWebView-обёртка для OAuth: перехват access_token из URL fragment
//  или редирект на music.yandex.ru (cookies + user_id через account/status).
//

import SwiftUI
import WebKit
import OSLog

// MARK: - Callback

struct YandexAuthResult {
    var accessToken: String?
    var cookies: String?
    var userId: String?
}

// MARK: - SwiftUI wrapper

struct YandexAuthView: View {
    @Environment(\.dismiss) private var dismiss
    var onComplete: (YandexAuthResult) -> Void
    let musicService: YandexMusicService
    
    init(onComplete: @escaping (YandexAuthResult) -> Void, musicService: YandexMusicService = YandexMusicService()) {
        self.onComplete = onComplete
        self.musicService = musicService
    }

    var body: some View {
        YandexAuthWebViewRepresentable(onComplete: { result in
            onComplete(result)
            dismiss()
        }, musicService: musicService)
        .ignoresSafeArea(.all, edges: [.top, .bottom, .leading, .trailing])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - UIViewRepresentable + WKWebView

private struct YandexAuthWebViewRepresentable: UIViewRepresentable {
    let onComplete: (YandexAuthResult) -> Void
    let musicService: YandexMusicService

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, musicService: musicService)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.didLoadInitialURL { return }
        context.coordinator.didLoadInitialURL = true
        let url = URL(string: YandexAuthConstants.authURL)!
        webView.load(URLRequest(url: url))
    }
}

// MARK: - Coordinator (WKNavigationDelegate)

private final class Coordinator: NSObject, WKNavigationDelegate {
    let onComplete: (YandexAuthResult) -> Void
    weak var webView: WKWebView?
    var didLoadInitialURL = false
    var didComplete = false
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "YandexAuth")
    private let musicService: YandexMusicService
    
    init(onComplete: @escaping (YandexAuthResult) -> Void, musicService: YandexMusicService) {
        self.onComplete = onComplete
        self.musicService = musicService
    }

    private func finish(_ result: YandexAuthResult) {
        guard !didComplete else { return }
        didComplete = true
        let hasToken = result.accessToken != nil
        let hasCookies = result.cookies != nil
        let cookieLen = result.cookies?.count ?? 0
        logger.info("auth finish: token=\(hasToken) cookies=\(hasCookies) len=\(cookieLen) userId=\(result.userId ?? "nil")")
        onComplete(result)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // 1) Токен в fragment (implicit flow): ...#access_token=xxx
        if let fragment = url.fragment, !fragment.isEmpty {
            if let token = parseAccessToken(fromFragment: fragment) {
                finish(YandexAuthResult(accessToken: token, cookies: nil, userId: nil))
                decisionHandler(.cancel)
                return
            }
        }

        // 2) Custom scheme callback: musicmind://callback#access_token=...
        if url.scheme?.lowercased() == "musicmind" || url.scheme?.lowercased() == "musicmindai" {
            if let fragment = url.fragment, let token = parseAccessToken(fromFragment: fragment) {
                finish(YandexAuthResult(accessToken: token, cookies: nil, userId: nil))
            }
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let currentURL = webView.url?.absoluteString, currentURL.contains("music.yandex") else { return }
        // document.cookie не видит HttpOnly (Session_id) — берём из WKHTTPCookieStore
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            let forMusic = cookies.filter { $0.domain.contains("yandex") }
            let hasSession = forMusic.contains { $0.name == "Session_id" || $0.name == "sessionid2" }
            guard hasSession, !forMusic.isEmpty else { return }
            let cookieHeader = forMusic.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            
            // получаем userId через YandexMusicService
            Task {
                let userId = await self.musicService.fetchUserId(cookies: cookieHeader)
                await MainActor.run {
                    self.finish(YandexAuthResult(
                        accessToken: nil,
                        cookies: cookieHeader,
                        userId: userId
                    ))
                }
            }
        }
    }

    private func parseAccessToken(fromFragment fragment: String) -> String? {
        let parts = fragment.split(separator: "&")
        for part in parts {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2,
               pair[0].removingPercentEncoding?.lowercased() == "access_token" {
                return pair[1].removingPercentEncoding
            }
        }
        return nil
    }
}

// MARK: - Constants (как в auth_webview.py)

enum YandexAuthConstants {
    static let authURL =
        "https://passport.yandex.ru/pwl-yandex/auth/add"
        + "?origin=music"
        + "&retpath=https%3A%2F%2Fmusic.yandex.ru%2F"
        + "&language=ru"
        + "&cause=auth"
        + "&process_uuid=\(UUID().uuidString)"
}
