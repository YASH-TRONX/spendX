//
//  SceneDelegate.swift
//  SpendX
//
//  Created by Yashraj Anand on 20/09/26.
//

import Foundation
import UIKit
import React

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = (scene as? UIWindowScene) else { return }

    let window = UIWindow(windowScene: windowScene)
    self.window = window

    // Access the factory from the AppDelegate and start React Native on this window scene
    let appDelegate = UIApplication.shared.delegate as? AppDelegate
    appDelegate?.reactNativeFactory?.startReactNative(
      withModuleName: "SpendX",
      in: window,
      launchOptions: nil
    )
  }
}
