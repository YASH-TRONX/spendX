//
//  UIImage+OCR.swift
//  SpendX
//
//  Created by Yashraj Anand on 22/03/26.
//

import CoreImage
import UIKit

extension UIImage {
  func preProcessForOCR() -> UIImage? {
    guard let ciImage = CIImage(image: self) else { return nil }

    // 1. Grayscale Filter
    //              let grayscale = ciImage.applyingFilter("CIPhotoEffectMono")
    //
    // 2. High Contrast Filter
    let highContrast = ciImage.applyingFilter(
      "CIColorControls",
      parameters: [
        kCIInputContrastKey: 1.5,
        kCIInputBrightnessKey: 0.0,
      ]
    )
    //
    // 3. Negative (Color Invert) Filter
    //              let negative = ciImage.applyingFilter("CIColorInvert")

    let context = CIContext(options: nil)
    if let cgImage = context.createCGImage(
      highContrast,
      from: highContrast.extent
    ) {
      return UIImage(cgImage: cgImage)
    }
    return nil
  }
}
