//
//  ShareSheet.swift
//  MusicMindAI
//
//  Утилита для отображения share sheet на iOS
//

import SwiftUI
import UIKit

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Не требуется обновление
    }
}
#endif