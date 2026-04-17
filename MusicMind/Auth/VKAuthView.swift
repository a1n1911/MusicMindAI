//
//  VKAuthView.swift
//  MusicMindAI
//
//  WebView для логина VK: id.vk.com → редирект на oauth.vk.com/blank.html#access_token=...
//

import SwiftUI
import WebKit
import OSLog

struct VKAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showManualEntry = false
    var onComplete: (String?, String?) -> Void

    var body: some View {
        Group {
            if showManualEntry {
                VKAuthManualView(onComplete: { token, userAgent in
                    onComplete(token, userAgent)
                    dismiss()
                }, onBack: { showManualEntry = false })
            } else {
                NavigationStack {
                    VKAuthWebViewRepresentable(onComplete: { token, userAgent in
                        onComplete(token, userAgent)
                        dismiss()
                    })
                    .ignoresSafeArea(.all, edges: [.top, .bottom, .leading, .trailing])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("VK Музыка")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(CyberpunkTheme.deepPurple, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена") {
                                onComplete(nil, nil)
                                dismiss()
                            }
                            .foregroundStyle(.white.opacity(0.9))
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button("Ввести токен вручную") {
                                showManualEntry = true
                            }
                            .font(.subheadline)
                            .foregroundStyle(CyberpunkTheme.neonPink)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - WebView

private struct VKAuthWebViewRepresentable: UIViewRepresentable {
    let onComplete: (String?, String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = WKProcessPool()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.didLoadInitialURL { return }
        context.coordinator.didLoadInitialURL = true
        guard let url = URL(string: AppConstants.VKMusic.webAuthURL) else { return }
        webView.load(URLRequest(url: url))
    }
}

// MARK: - Coordinator (перехват редиректа)

private final class Coordinator: NSObject, WKNavigationDelegate {
    let onComplete: (String?, String?) -> Void
    weak var webView: WKWebView?
    var didLoadInitialURL = false
    var didComplete = false
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "VKAuth")

    init(onComplete: @escaping (String?, String?) -> Void) {
        self.onComplete = onComplete
    }

    private func finish(token: String?, userAgent: String?) {
        guard !didComplete else { return }
        didComplete = true
        logger.info("VK auth finish: token=\(token != nil ? "ok" : "nil")")
        onComplete(token, userAgent)
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
        let host = url.host?.lowercased() ?? ""
        let path = url.path
        if host == AppConstants.VKMusic.authRedirectHost,
           path == AppConstants.VKMusic.authRedirectPath {
            // редирект: oauth.vk.com/blank.html#access_token=xxx&expires_in=86400&user_id=...
            let fragment = url.fragment ?? ""
            let token = Self.parseFragment(fragment)
            if let token = token, !token.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.finish(token: token, userAgent: nil)
                }
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }

    /// Парсит fragment вида "access_token=vk1.a.xxx&expires_in=86400&user_id=432721820"
    private static func parseFragment(_ fragment: String) -> String? {
        let parts = fragment.split(separator: "&")
        for part in parts {
            let pair = part.split(separator: "=", maxSplits: 1)
            if pair.count == 2,
               pair[0].removingPercentEncoding?.lowercased() == "access_token",
               let token = pair[1].removingPercentEncoding, !token.isEmpty {
                return token
            }
        }
        return nil
    }
}

// MARK: - Ручной ввод токена (fallback)

private struct VKAuthManualView: View {
    @State private var token = ""
    @State private var userAgent = AppConstants.VKMusic.defaultUserAgent
    var onComplete: (String?, String?) -> Void
    var onBack: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Вставь access_token (из браузера или vkpymusic)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Токен")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.9))
                        TextField("access_token", text: $token, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .lineLimit(2...4)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("User-Agent (опционально)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.9))
                        TextField("User-Agent", text: $userAgent, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .lineLimit(2...4)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    Spacer(minLength: 24)
                }
                .padding(24)
            }
            .background { CyberpunkTheme.backgroundGradient.ignoresSafeArea(.all) }
            .navigationTitle("VK Музыка — ввод токена")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CyberpunkTheme.deepPurple, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Назад") {
                        onBack()
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
                        let ua = userAgent.trimmingCharacters(in: .whitespacesAndNewlines)
                        onComplete(t.isEmpty ? nil : t, ua.isEmpty ? nil : ua)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(CyberpunkTheme.neonPink)
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
