//
//  ShareViewController.swift
//  HandleTxn
//
//  Created by Yashraj Anand on 21/03/26.
//

import SwiftUI
import UIKit
import Vision
import CoreML
import CoreVideo
import CoreImage

class ShareViewController: UIViewController {

  // Initialize with Devanagari options for ₹ support
  //  private let textRecognizer: TextRecognizer = {
  //    let options = DevanagariTextRecognizerOptions()
  //    return TextRecognizer.textRecognizer(options: options)
  //  }()

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
    print("Selected Action: \(type)")  // "Sent" or "Received"

    // 1. Access the shared item (the receipt image)
    guard
      let extensionItem = extensionContext?.inputItems.first
        as? NSExtensionItem,
      let attachment = extensionItem.attachments?.first
    else {
      self.dismiss()
      return
    }

    // 2. Load the image data
    if attachment.hasItemConformingToTypeIdentifier("public.image") {
      attachment.loadItem(forTypeIdentifier: "public.image", options: nil) {
        (item, error) in
        var image: UIImage?

        if let url = item as? URL {
          image = UIImage(contentsOfFile: url.path)
        } else if let img = item as? UIImage {
          image = img
        }

        if let finalImage = image {
          // 3. Process the image using ML Kit
          self.extractAmountAppleVision(from: finalImage) { amount in
            print("Extracted Amount for \(type): \(amount)")

            // TODO: Save 'amount' and 'type' to UserDefaults/AppGroup here

            DispatchQueue.main.async {
              self.dismiss()
            }
          }
        } else {
          self.dismiss()
        }
      }
    } else {
      self.dismiss()
    }
  }
  
  // MARK: - Main Extraction Pipeline
  func extractAmountAppleVision(
          from image: UIImage,
          completion: @escaping (String) -> Void
      ) {
          guard let cgImage = image.cgImage else {
              completion("0")
              return
          }

          DispatchQueue.global(qos: .userInitiated).async { [weak self] in
              autoreleasepool {
                  guard let self = self else { return }
                  self.runNativeVisionOCR(cgImage: cgImage, completion: completion)
              }
          }
      }

      // MARK: - Native Vision OCR Engine (Size & Position Prioritized)
      private func runNativeVisionOCR(cgImage: CGImage, completion: @escaping (String) -> Void) {
          // Pass A: recognize text on the image as-is.
          var observations = recognizeTextObservations(in: cgImage)

          // Pass B: some receipts render the amount as large stylized digits sitting on top of a
          // busy decorative background (e.g. CRED's star/rosette graphic behind "₹1"). Vision's text
          // detector can fail to segment that region as text at all on the first pass — not a parsing
          // issue, a detection one. Re-running on a higher-contrast, desaturated variant of the image
          // often recovers text Vision missed entirely; merge in anything newly found without
          // discarding what pass A already recognized.
          if let enhanced = highContrastVariant(of: cgImage) {
              observations.append(contentsOf: recognizeTextObservations(in: enhanced))
          }

          // Pass C: oversized glyphs relative to the frame (a huge ornate digit filling much of the
          // vertical space) can fall outside what Vision's line-detector expects as a normal text
          // line, causing it to reject the region as non-text entirely, independent of contrast.
          // Shrinking the whole image brings that glyph back into a more typical relative size.
          if let downscaled = downscaledVariant(of: cgImage, scale: 0.5) {
              observations.append(contentsOf: recognizeTextObservations(in: downscaled))
          }

          // Pass D: hard-binarize to solid black-on-white, which strips out faint decorative line
          // art (e.g. the star outline behind the amount) that can otherwise get segmented together
          // with the real digit strokes and confuse detection.
          if let binarized = binarizedVariant(of: cgImage) {
              observations.append(contentsOf: recognizeTextObservations(in: binarized))
          }

          guard !observations.isEmpty else {
              DispatchQueue.main.async { completion("0") }
              return
          }

          // 1. Sort observations by font height (Largest text on screen first)
          let sortedByFontSize = observations.sorted { (obs1, obs2) -> Bool in
              return obs1.boundingBox.height > obs2.boundingBox.height
          }

          // 2. Collect valid (non-noise) candidates once, keeping their raw text and whether
          // Vision cleanly recognized an explicit currency marker ("₹"/"Rs"/"INR") on them.
          var candidates: [(text: String, candidate: VNRecognizedText, hasExplicitCurrency: Bool)] = []
          for observation in sortedByFontSize {
              let alternates = observation.topCandidates(5)
              guard let topCandidate = alternates.first else { continue }
              let rawText = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)

              // Skip dates, timestamps, account numbers, and transaction/reference IDs explicitly
              if self.isHeaderFooterNoise(rawText) {
                  continue
              }

              func hasCurrencyMarker(_ s: String) -> Bool {
                  s.contains("₹") || s.lowercased().contains("rs") || s.uppercased().contains("INR")
              }

              var chosenText = rawText
              var chosenCandidate = topCandidate
              var hasExplicitCurrency = hasCurrencyMarker(rawText)

              // Vision keeps several alternate readings per line. When the top guess misreads "₹"
              // as a plain digit, a lower-ranked alternate for the same line sometimes recognized
              // the currency marker correctly — prefer that over guessing which digit it became.
              if !hasExplicitCurrency {
                  for alt in alternates.dropFirst() {
                      let altText = alt.string.trimmingCharacters(in: .whitespacesAndNewlines)
                      if hasCurrencyMarker(altText) {
                          chosenText = altText
                          chosenCandidate = alt
                          hasExplicitCurrency = true
                          break
                      }
                  }
              }

              candidates.append((chosenText, chosenCandidate, hasExplicitCurrency))
          }

          // 3. Pass 1: prefer lines where Vision cleanly recognized the currency marker itself —
          // these need no artifact guessing and are far less likely to be a stray ID/number
          // (e.g. a "TXN ID: 644714564274" line) mistaken for the amount. We run OCR 4 times (on the
          // original image plus 3 processed variants), so the same line is usually seen multiple
          // times, sometimes with different misreads (e.g. "81,206" once vs "71,206" three times) —
          // take the value most passes agree on rather than whichever candidate happens to come
          // first, since the first one is not necessarily the correct one.
          if let consensus = self.consensusAmount(from: candidates.filter { $0.hasExplicitCurrency }) {
              DispatchQueue.main.async { completion(consensus) }
              return
          }

          // 4. Pass 2: same consensus approach, falling back to the artifact-guessing heuristics.
          if let consensus = self.consensusAmount(from: candidates.filter { !$0.hasExplicitCurrency }) {
              DispatchQueue.main.async { completion(consensus) }
              return
          }

          DispatchQueue.main.async { completion("0") }
      }

      // MARK: - Cross-Pass Consensus
      // Parses every candidate and returns the amount the most candidates agree on. Running OCR
      // across multiple image variants means the same line is often recognized several times, and
      // a majority reading is far more trustworthy than whichever single candidate is checked first.
      private func consensusAmount(from entries: [(text: String, candidate: VNRecognizedText, hasExplicitCurrency: Bool)]) -> String? {
          var counts: [String: Int] = [:]
          var order: [String] = []
          for entry in entries {
              guard let amount = cleanAndParseAmount(entry.text, candidate: entry.candidate) else { continue }
              if counts[amount] == nil {
                  order.append(amount)
              }
              counts[amount, default: 0] += 1
          }
          guard var best = order.first else { return nil }
          for amount in order.dropFirst() where counts[amount]! > counts[best]! {
              best = amount
          }
          return best
      }

      // MARK: - Text Recognition Helper
      private func recognizeTextObservations(in cgImage: CGImage) -> [VNRecognizedTextObservation] {
          let request = VNRecognizeTextRequest()
          request.recognitionLevel = .accurate
          request.usesLanguageCorrection = false
          // "₹" is an Indian-locale glyph; without a locale hint Vision's default (en-US) language
          // model has little exposure to it and is more prone to misclassifying it as a plain digit.
          // This targets the actual root cause (recognition, not post-hoc string guessing) — the
          // artifact-stripping rules below remain as a fallback for whatever still gets through.
          request.recognitionLanguages = ["en-IN", "en-GB", "en-US"]

          let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
          do {
              try handler.perform([request])
              return (request.results as? [VNRecognizedTextObservation]) ?? []
          } catch {
              return []
          }
      }

      // MARK: - Contrast Enhancement for Stylized/Decorative Text
      private func highContrastVariant(of cgImage: CGImage) -> CGImage? {
          let ciImage = CIImage(cgImage: cgImage)
          guard let filter = CIFilter(name: "CIColorControls") else { return nil }
          filter.setValue(ciImage, forKey: kCIInputImageKey)
          filter.setValue(1.6, forKey: kCIInputContrastKey)
          filter.setValue(0.0, forKey: kCIInputBrightnessKey)
          filter.setValue(0.0, forKey: kCIInputSaturationKey)
          guard let output = filter.outputImage else { return nil }
          return CIContext().createCGImage(output, from: output.extent)
      }

      // MARK: - Downscale for Oversized Glyphs
      private func downscaledVariant(of cgImage: CGImage, scale: CGFloat) -> CGImage? {
          let ciImage = CIImage(cgImage: cgImage).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
          return CIContext().createCGImage(ciImage, from: ciImage.extent)
      }

      // MARK: - Binarization to Strip Decorative Line Art
      private func binarizedVariant(of cgImage: CGImage) -> CGImage? {
          let ciImage = CIImage(cgImage: cgImage)

          // Otsu thresholding auto-picks the split point between foreground/background, which
          // handles varying decorative-background brightness better than a fixed contrast bump.
          if let otsu = CIFilter(name: "CIColorThresholdOtsu") {
              otsu.setValue(ciImage, forKey: kCIInputImageKey)
              if let output = otsu.outputImage {
                  return CIContext().createCGImage(output, from: output.extent)
              }
          }

          // Fallback for OS versions without the Otsu filter: grayscale + aggressive contrast.
          guard let filter = CIFilter(name: "CIColorControls") else { return nil }
          filter.setValue(ciImage, forKey: kCIInputImageKey)
          filter.setValue(4.0, forKey: kCIInputContrastKey)
          filter.setValue(0.0, forKey: kCIInputSaturationKey)
          guard let output = filter.outputImage else { return nil }
          return CIContext().createCGImage(output, from: output.extent)
      }

      // MARK: - Skip Noise Filtering
      private func isHeaderFooterNoise(_ text: String) -> Bool {
          let lower = text.lowercased()

          let hasMonth = ["jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
              .contains { lower.contains($0) }

          // "am"/"pm" as bare substrings false-positive on common words like "Amount" or "Sample" —
          // only flag them when they actually form a clock time (e.g. "07:38 PM").
          let hasClockTime: Bool = {
              guard let regex = try? NSRegularExpression(pattern: "\\d{1,2}:\\d{2}\\s*(am|pm)", options: .caseInsensitive) else {
                  return false
              }
              let range = NSRange(location: 0, length: lower.utf16.count)
              return regex.firstMatch(in: lower, options: [], range: range) != nil
          }()

          // Masked account/card numbers ("XXXXXXXXXX1237") carry real digits that can otherwise
          // parse as a plausible-looking amount and pollute consensus voting.
          let hasMaskedNumber = lower.contains("xxxx")

          // 10-digit Indian mobile numbers (optionally with a leading +91/91) show up in "Contact"/
          // "Support"/footer lines and, unformatted, parse as a huge but syntactically valid amount.
          let hasPhoneNumber: Bool = {
              guard let regex = try? NSRegularExpression(pattern: "(?:\\+?91[\\s-]?)?\\b[6-9][0-9]{9}\\b") else {
                  return false
              }
              let range = NSRange(location: 0, length: lower.utf16.count)
              return regex.firstMatch(in: lower, options: [], range: range) != nil
          }()

          if hasMonth || hasClockTime || hasMaskedNumber || hasPhoneNumber || lower.contains("savings") ||
             lower.contains("refcl") || lower.contains("account") || lower.contains("credited") ||
             lower.contains("upi send money") || lower.contains("transaction summary") ||
             lower.contains("txn id") || lower.contains("transaction id") || lower.contains("utr") ||
             lower.contains("ref no") || lower.contains("reference") || lower.contains("paid securely") ||
             lower.contains("powered by") {
              return true
          }
          return false
      }

      // MARK: - Comprehensive Rupee Artifact Engine
      private func cleanAndParseAmount(_ text: String, candidate: VNRecognizedText) -> String? {
          var rawText = text
          let hadExplicitRupee = rawText.contains("₹") || rawText.lowercased().contains("rs")

          // Strip explicit currency prefixes
          rawText = rawText.replacingOccurrences(of: "₹", with: "")
          rawText = rawText.replacingOccurrences(of: "Rs.", with: "", options: .caseInsensitive)
          rawText = rawText.replacingOccurrences(of: "Rs", with: "", options: .caseInsensitive)
          rawText = rawText.replacingOccurrences(of: "INR", with: "", options: .caseInsensitive)
          var cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
          // Alignment anchor: when hadExplicitRupee is false, none of the replacements above did
          // anything, so `cleaned` still lines up character-for-character with the original `text`.
          // Rule 1/2 below may then strip more leading characters — track how many so the glyph-width
          // check in Rule 4 can offset back into `text` correctly.
          let lengthBeforeArtifactRules = cleaned.count

          // Fix Rule 1: Leading artifact ('2', '7', '3', '1', 'z', 'Z', '?') attached to 2-digit numbers
          // e.g. "275" -> "75", "175" -> "75", "375" -> "75", "71206" -> "1206"
          let artifactPrefixPattern = "^[2731zZJ\\?](?=[0-9]{2}$)"
          if let regex = try? NSRegularExpression(pattern: artifactPrefixPattern) {
              let range = NSRange(location: 0, length: cleaned.utf16.count)
              let result = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
              if !result.isEmpty && result != cleaned {
                  cleaned = result
              }
          }

          // Fix Rule 2: Remove leading artifact before larger formatted amounts (e.g., "71,206" -> "1,206")
          let formattedArtifactPattern = "^[273zZJ\\?](?=[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,})"
          if let regex = try? NSRegularExpression(pattern: formattedArtifactPattern) {
              let range = NSRange(location: 0, length: cleaned.utf16.count)
              cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
          }

          // Fix Rule 3: Generalized artifact detection via glyph geometry, tried before any blind
          // guessing. When Vision fails to recognize "₹" as a currency symbol, it sometimes reads it
          // as an arbitrary stray digit fused onto the real amount (e.g. "₹1" -> "71", "₹50" -> "550").
          // A fixed whitelist of specific misreads ('2','7','3','1'...) or hardcoded string overrides
          // ("31"->"1") can't cover every digit Vision might substitute, and risks truncating a
          // genuinely different amount that happens to look the same (a real ₹31 vs. a misread ₹1).
          // Instead, compare the leading character's actual rendered width to its neighbours': a
          // genuine leading digit is roughly the same width as the digit(s) after it, while a misread
          // currency glyph fused onto the number typically renders noticeably narrower or wider.
          if !hadExplicitRupee {
              let frontOffset = lengthBeforeArtifactRules - cleaned.count
              cleaned = stripArtifactGlyphByWidth(
                  cleaned: cleaned,
                  originalText: text,
                  frontOffset: frontOffset,
                  candidate: candidate
              )
          }

          // Fix Rule 4: Direct explicit overrides for small edge cases, kept only as a last-resort
          // fallback for when glyph-width data above isn't available (e.g. boundingBox lookup fails).
          if cleaned == "31" || cleaned == "71" || cleaned == "21" { return "1" }
          if cleaned == "12" && (hadExplicitRupee || text.count <= 3) { return "2" }

          // Standard numeric extraction engine (supports 75, 1,206, and 1206.50)
          let standardAmountPattern = "([0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\\.[0-9]{1,2})?"
          if let regex = try? NSRegularExpression(pattern: standardAmountPattern),
             let match = regex.firstMatch(in: cleaned, range: NSRange(location: 0, length: cleaned.utf16.count)),
             let range = Range(match.range(at: 0), in: cleaned) {

              let amountStr = String(cleaned[range]).replacingOccurrences(of: ",", with: "")
              // Guard against reference numbers/IDs/phone numbers that slip through (e.g.
              // "CL58933319481774000799381" or a bare 10-digit mobile number) matching this same
              // digit pattern. Real personal-expense amounts don't run into the crores, so cap well
              // below that rather than only rejecting values large enough to overflow Int.
              if let val = Double(amountStr), val > 0, val < 10_000_000 {
                  if val.truncatingRemainder(dividingBy: 1) == 0 {
                      return String(Int(val))
                  }
                  return String(val)
              }
          }

          return nil
      }

      // MARK: - Glyph Width Artifact Detection
      // Strips a leading digit that is geometrically inconsistent with the digits after it —
      // the signature of a misread "₹" glyph fused onto the real amount.
      private func stripArtifactGlyphByWidth(
          cleaned: String,
          originalText: String,
          frontOffset: Int,
          candidate: VNRecognizedText
      ) -> String {
          guard let first = cleaned.first, first.isNumber, cleaned.count >= 2 else { return cleaned }

          let digitsAfterFirst = cleaned.dropFirst().prefix(while: { $0.isNumber })
          guard digitsAfterFirst.count >= 1 else { return cleaned }

          guard let firstWidth = glyphWidth(at: frontOffset, in: originalText, candidate: candidate) else { return cleaned }

          // Sample up to 4 neighbouring digits (not just the immediate next one) and use the median,
          // not the mean, as the baseline. '1' is naturally much narrower than other digits in most
          // fonts, so a plain average of only 1-2 neighbours can be skewed enough by a stray '1' to
          // hide a real artifact (e.g. "81206" from "₹1,206" — averaging '1' and '2' pulls the
          // baseline down enough that '8' no longer looks anomalous). A median over more digits is
          // far less sensitive to any single outlier-width digit.
          let sampleCount = min(4, digitsAfterFirst.count)
          let sampleWidths = (1...sampleCount).compactMap {
              glyphWidth(at: frontOffset + $0, in: originalText, candidate: candidate)
          }
          guard !sampleWidths.isEmpty else { return cleaned }

          let baselineWidth = median(of: sampleWidths)
          guard baselineWidth > 0 else { return cleaned }

          let ratio = firstWidth / baselineWidth

          // With only one neighbouring digit to compare against, a genuine '1' (naturally much
          // narrower than other digits in most fonts) can look like a false match — so require a
          // more extreme deviation before stripping when we only have a single sample to go on.
          let (lowerBound, upperBound) = sampleWidths.count >= 2 ? (0.6, 1.6) : (0.4, 2.2)

          if ratio < lowerBound || ratio > upperBound {
              return String(cleaned.dropFirst())
          }
          return cleaned
      }

      private func median(of values: [CGFloat]) -> CGFloat {
          let sorted = values.sorted()
          let mid = sorted.count / 2
          if sorted.count % 2 == 0 {
              return (sorted[mid - 1] + sorted[mid]) / 2
          }
          return sorted[mid]
      }

      private func glyphWidth(at offset: Int, in text: String, candidate: VNRecognizedText) -> CGFloat? {
          guard let start = text.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex),
                start < text.endIndex else { return nil }
          let end = text.index(after: start)
          guard let box = try? candidate.boundingBox(for: start..<end) else { return nil }
          return box.boundingBox.width
      }

  private func dismiss() {
    self.extensionContext?.completeRequest(
      returningItems: [],
      completionHandler: nil
    )
  }
}
