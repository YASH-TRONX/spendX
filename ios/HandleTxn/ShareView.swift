//
//  ShareView.swift
//  SpendX
//
//  Created by Yashraj Anand on 21/03/26.
//

import SwiftUI

struct ShareView: View {
  var onAction: (String) -> Void
  var onCancel: () -> Void

  var body: some View {
    ZStack(alignment: .bottom) {
      // 1. The Dimmer
      Color.black.opacity(0)
        .ignoresSafeArea()
        .onTapGesture { onCancel() }

      // 2. The Card
      VStack(spacing: 20) {
        Capsule()
          .fill(Color.gray.opacity(0.4))
          .frame(width: 40, height: 6)
          .padding(.top, 12)

        Text("Debit or Credit?")
          .font(.system(size: 20, weight: .bold))

        HStack(spacing: 60) {
          ActionButton(title: "Debit", icon: "paperplane.fill", color: .blue) {
            onAction("Debit")
          }
          ActionButton(
            title: "Credit",
            icon: "tray.and.arrow.down.fill",
            color: .green
          ) {
            onAction("Credit")
          }
        }
        .padding(.top, 10)

        Button(action: onCancel) {
          Text("Cancel")
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)

        Spacer().frame(height: 50)
      }
      .frame(maxWidth: .infinity)
      .background(Color(UIColor.systemBackground))
      .cornerRadius(30)
      .offset(y: 50)
    }
    // This ensures the ZStack actually reaches the bottom edge
    .ignoresSafeArea(edges: .bottom)
  }
}

// MARK: - Action Button
struct ActionButton: View {
  let title: String
  let icon: String
  let color: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(color.opacity(0.15))
            .frame(width: 70, height: 70)

          Image(systemName: icon)
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(color)
        }

        Text(title)
          .font(.system(size: 15, weight: .medium))
          .foregroundColor(.primary)
      }
    }
  }
}
