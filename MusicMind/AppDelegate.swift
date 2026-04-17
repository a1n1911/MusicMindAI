//
//  AppDelegate.swift
//  MusicMindAI
//
//  AppDelegate для ранней настройки окна
//

import UIKit
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate, UIWindowSceneDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        WindowManager.shared.setupWindowBackground()
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        WindowManager.shared.setupWindowBackground()
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        WindowManager.shared.setupWindowBackground()
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        WindowManager.shared.setupWindowBackground()
    }
}
