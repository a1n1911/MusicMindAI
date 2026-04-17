//
//  FullScreenBackground.swift
//  MusicMindAI
//
//  View для гарантированного заполнения всего экрана включая Dynamic Island
//

import SwiftUI
import UIKit

struct FullScreenBackground<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            CyberpunkTheme.backgroundGradient
                .ignoresSafeArea(.all, edges: .all)
            
            content
        }
        .background(
            FullScreenBackgroundView()
        )
    }
}

private struct FullScreenBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = CyberpunkTheme.windowBackgroundUIColor
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.backgroundColor = CyberpunkTheme.windowBackgroundUIColor
        
        // устанавливаем цвет фона для всех окон
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.backgroundColor = CyberpunkTheme.windowBackgroundUIColor
            }
        }
    }
}
