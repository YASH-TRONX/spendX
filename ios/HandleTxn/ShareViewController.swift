//
//  ShareViewController.swift
//  HandleTxn
//
//  Created by Yashraj Anand on 21/03/26.
//

import SwiftUI
import UIKit

class ShareViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    // 1. Force the controller view to be completely clear
    self.view.backgroundColor = .clear
    self.view.isOpaque = false

    setupSwiftUI()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // 1. Re-assert our own view is clear
    self.view.backgroundColor = .clear
    self.view.isOpaque = false

    // 2. Climb up the view hierarchy and force Apple's wrapper views to be transparent
    var currentView: UIView? = self.view.superview
    while currentView != nil {
      currentView?.backgroundColor = .clear
      currentView?.isOpaque = false
      currentView = currentView?.superview
    }
  }

  private func setupSwiftUI() {
    let rootView = ShareView(
      onAction: { type in self.handleShare(type) },
      onCancel: { self.dismiss() }
    )

    let hostingController = UIHostingController(rootView: rootView)

    // 2. Force the hosting container to be clear
    hostingController.view.backgroundColor = .clear
    hostingController.view.isOpaque = false

    addChild(hostingController)
    view.addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.bottomAnchor.constraint(
        equalTo: view.bottomAnchor
      ),
      hostingController.view.leadingAnchor.constraint(
        equalTo: view.leadingAnchor
      ),
      hostingController.view.trailingAnchor.constraint(
        equalTo: view.trailingAnchor
      ),
    ])
  }

  private func handleShare(_ type: String) {
    print("Selected: \(type)")
    dismiss()
  }

  private func dismiss() {
    self.extensionContext?.completeRequest(
      returningItems: [],
      completionHandler: nil
    )
  }
}
