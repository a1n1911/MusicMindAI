//
//  SoundCloudAuthView.swift
//  MusicMindAI
//
//  WKWebView для логина SoundCloud: извлекаем OAuth токен из localStorage после входа
//

import SwiftUI
import WebKit
import OSLog

struct SoundCloudAuthView: View {
    @Environment(\.dismiss) private var dismiss
    var onComplete: (String?) -> Void

    var body: some View {
        SoundCloudAuthWebViewRepresentable(onComplete: { token in
            onComplete(token)
            dismiss()
        })
        .ignoresSafeArea(.all, edges: [.top, .bottom, .leading, .trailing])
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - UIViewRepresentable + WKWebView

private struct SoundCloudAuthWebViewRepresentable: UIViewRepresentable {
    let onComplete: (String?) -> Void

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
        let url = URL(string: AppConstants.SoundCloud.signinFallbackURL)!
        webView.load(URLRequest(url: url))
    }
}

// MARK: - Coordinator

private final class Coordinator: NSObject, WKNavigationDelegate {
    let onComplete: (String?) -> Void
    weak var webView: WKWebView?
    var didLoadInitialURL = false
    var didComplete = false
    private let logger = Logger(subsystem: AppConstants.Logger.subsystem, category: "SoundCloudAuth")

    init(onComplete: @escaping (String?) -> Void) {
        self.onComplete = onComplete
    }

    private func finish(_ token: String?, source: String = "unknown") {
        guard !didComplete else { return }
        didComplete = true
        if let t = token {
            let parts = t.split(separator: "-")
            let uid = parts.count >= 2 ? String(parts[1]) : "?"
            logger.info("SoundCloud auth finish: source=\(source), tokenLen=\(t.count), parts=\(parts.count), parsedUserId=\(uid), prefix=\(String(t.prefix(12)))...")
        } else {
            logger.info("SoundCloud auth finish: token=nil")
        }
        onComplete(token)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url?.absoluteString.lowercased(),
              (url.contains("soundcloud.com") || url.contains("m.soundcloud.com")),
              !url.contains("secure.soundcloud.com/web-auth") else {
            return
        }

        // после логина — пробуем достать токен из localStorage / sessionStorage
        let script = """
        (function() {
            try {
                var re = /2-\\d+-\\d+-[A-Za-z0-9]+/;
                var find = function(v) {
                    if (!v || typeof v !== 'string') return null;
                    var m = v.match(re);
                    return m ? m[0] : null;
                };
                var stores = [localStorage, sessionStorage];
                for (var s = 0; s < stores.length; s++) {
                    var store = stores[s];
                    for (var i = 0; i < store.length; i++) {
                        var k = store.key(i);
                        var v = store.getItem(k);
                        var t = find(v);
                        if (t) return t;
                        try {
                            var j = JSON.parse(v);
                            var str = JSON.stringify(j);
                            t = find(str);
                            if (t) return t;
                        } catch(_) {}
                    }
                }
                if (window.__sc_auth_token__) return window.__sc_auth_token__;
                return null;
            } catch(e) { return null; }
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }
            if let err = error {
                self.logger.debug("SoundCloud localStorage read error: \(err.localizedDescription)")
                return
            }
            if let token = result as? String, !token.isEmpty, token.contains("-") {
                DispatchQueue.main.async {
                    self.finish(token, source: "localStorage")
                }
            } else {
                self.logger.info("SoundCloud auth: script returned no token, result=\(String(describing: result))")
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // callback URL может содержать токен в fragment (редко)
        if let url = navigationAction.request.url,
           url.absoluteString.contains("signin/callback"),
           let fragment = url.fragment, !fragment.isEmpty {
            let parts = fragment.split(separator: "&")
            for part in parts {
                let pair = part.split(separator: "=", maxSplits: 1)
                if pair.count == 2,
                   pair[0].removingPercentEncoding?.lowercased() == "access_token",
                   let token = pair[1].removingPercentEncoding, !token.isEmpty {
                    DispatchQueue.main.async {
                        self.finish(token, source: "callback")
                    }
                    decisionHandler(.cancel)
                    return
                }
            }
        }
        decisionHandler(.allow)
    }
}
