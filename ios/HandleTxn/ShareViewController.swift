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
    // Run UIViewController's own setup first
    super.viewDidLoad()

    // 1. Force the controller view to be completely clear
    // Remove the default opaque background color
    self.view.backgroundColor = .clear
    // Tell UIKit this view has transparent regions so it doesn't optimize them away
    self.view.isOpaque = false

    // Build and attach the SwiftUI content on top of this cleared view
    setupSwiftUI()
  }

  override func viewWillAppear(_ animated: Bool) {
    // Run UIViewController's own pre-appearance logic first
    super.viewWillAppear(animated)

    // 1. Re-assert our own view is clear
    // The system can reset this before the view appears, so set it again
    self.view.backgroundColor = .clear
    self.view.isOpaque = false

    // 2. Climb up the view hierarchy and force Apple's wrapper views to be transparent
    // Start at the immediate superview
    var currentView: UIView? = self.view.superview
    // Walk up every ancestor until we reach the top (nil superview)
    while currentView != nil {
      // Clear this ancestor's background too
      currentView?.backgroundColor = .clear
      // Prevent UIKit from treating it as opaque
      currentView?.isOpaque = false
      // Move up to the next ancestor
      currentView = currentView?.superview
    }
  }

  private func setupSwiftUI() {
    // Build the SwiftUI view, wiring its callbacks back to this controller's methods
    let rootView = ShareView(
      onAction: { type in self.handleShare(type) },
      onCancel: { self.dismiss() }
    )

    // Wrap the SwiftUI view in a UIKit-compatible hosting controller
    let hostingController = UIHostingController(rootView: rootView)

    // 2. Force the hosting container to be clear
    hostingController.view.backgroundColor = .clear
    hostingController.view.isOpaque = false

    // Register the hosting controller as a child so it participates in the view controller hierarchy
    addChild(hostingController)
    // Insert its view into this controller's view
    view.addSubview(hostingController.view)
    // Disable the auto-generated autoresizing mask so our explicit constraints below take effect
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false

    // Pin the hosting view's edges to this controller's view, filling the whole screen
    NSLayoutConstraint.activate([
      // Top edge matches the parent's top edge
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      // Bottom edge matches the parent's bottom edge
      hostingController.view.bottomAnchor.constraint(
        equalTo: view.bottomAnchor
      ),
      // Leading edge matches the parent's leading edge
      hostingController.view.leadingAnchor.constraint(
        equalTo: view.leadingAnchor
      ),
      // Trailing edge matches the parent's trailing edge
      hostingController.view.trailingAnchor.constraint(
        equalTo: view.trailingAnchor
      ),
    ])
  }

  private func handleShare(_ type: String) {
    print("Selected Action: \(type)")  // "Sent" or "Received"

    // 1. Access the shared item (the receipt image)
    guard
      // Get the extension's first input item, cast to the type that carries attachments
      let extensionItem = extensionContext?.inputItems.first
        as? NSExtensionItem,
      // Get the first attachment (the shared image) off that item
      let attachment = extensionItem.attachments?.first
    else {
      // No usable item/attachment was shared, so bail out and close the extension
      self.dismiss()
      return
    }

    // 2. Load the image data
    // Only proceed if this attachment actually offers an image representation
    if attachment.hasItemConformingToTypeIdentifier("public.image") {
      // Asynchronously load the image payload
      attachment.loadItem(forTypeIdentifier: "public.image", options: nil) {
        (item, error) in
        // Will hold the decoded image once we figure out which form it arrived in
        var image: UIImage?

        if let url = item as? URL {
          // Loaded as a file URL, so read the image from disk
          image = UIImage(contentsOfFile: url.path)
        } else if let img = item as? UIImage {
          // Already handed to us as a UIImage
          image = img
        }

        if let finalImage = image {
          // 3. Process the image using ML Kit
          // Run OCR/amount extraction on the loaded image
          self.extractAmountAppleVision(from: finalImage) { amount in
            print("Extracted Amount for \(type): \(amount)")

            // TODO: Save 'amount' and 'type' to UserDefaults/AppGroup here

            // Dismiss the extension back on the main thread once extraction completes
            DispatchQueue.main.async {
              self.dismiss()
            }
          }
        } else {
          // Image failed to decode, nothing to extract, so just close
          self.dismiss()
        }
      }
    } else {
      // Attachment isn't an image, so there's nothing this extension can do
      self.dismiss()
    }
  }
  
  // MARK: - Main Extraction Pipeline
  func extractAmountAppleVision(
          from image: UIImage,
          completion: @escaping (String) -> Void
      ) {
          // Vision needs a CGImage, not a UIImage, so unwrap it first
          guard let cgImage = image.cgImage else {
              // No underlying CGImage available, so report "no amount found"
              completion("0")
              return
          }

          // Run OCR off the main thread since Vision recognition is slow
          DispatchQueue.global(qos: .userInitiated).async { [weak self] in
              // Wrap in an autoreleasepool to free intermediate image buffers promptly
              autoreleasepool {
                  // Bail out if the controller was deallocated while we were waiting to run
                  guard let self = self else { return }
                  // Hand off to the actual OCR pipeline
                  self.runNativeVisionOCR(cgImage: cgImage, completion: completion)
              }
          }
      }

      // MARK: - Native Vision OCR Engine (Size & Position Prioritized)
      private func runNativeVisionOCR(cgImage: CGImage, completion: @escaping (String) -> Void) {
          // Pass A: recognize text on the image as-is.
          // Run the baseline OCR pass and start accumulating all observations found so far
          var observations = recognizeTextObservations(in: cgImage)

          // Pass B: some receipts render the amount as large stylized digits sitting on top of a
          // busy decorative background (e.g. CRED's star/rosette graphic behind "₹1"). Vision's text
          // detector can fail to segment that region as text at all on the first pass — not a parsing
          // issue, a detection one. Re-running on a higher-contrast, desaturated variant of the image
          // often recovers text Vision missed entirely; merge in anything newly found without
          // discarding what pass A already recognized.
          // Build a higher-contrast, desaturated copy of the image, if the filter succeeds
          if let enhanced = highContrastVariant(of: cgImage) {
              // Re-run OCR on it and merge any newly found text into the running list
              observations.append(contentsOf: recognizeTextObservations(in: enhanced))
          }

          // Pass C: oversized glyphs relative to the frame (a huge ornate digit filling much of the
          // vertical space) can fall outside what Vision's line-detector expects as a normal text
          // line, causing it to reject the region as non-text entirely, independent of contrast.
          // Shrinking the whole image brings that glyph back into a more typical relative size.
          // Shrink the image to half size, if the filter succeeds
          if let downscaled = downscaledVariant(of: cgImage, scale: 0.5) {
              // Re-run OCR on the downscaled copy and merge its results in too
              observations.append(contentsOf: recognizeTextObservations(in: downscaled))
          }

          // Pass D: hard-binarize to solid black-on-white, which strips out faint decorative line
          // art (e.g. the star outline behind the amount) that can otherwise get segmented together
          // with the real digit strokes and confuse detection.
          // Hard-binarize to black-on-white, if the filter succeeds
          if let binarized = binarizedVariant(of: cgImage) {
              // Re-run OCR on the binarized copy and merge its results in too
              observations.append(contentsOf: recognizeTextObservations(in: binarized))
          }

          // If none of the four passes found any text at all, there's nothing to parse
          guard !observations.isEmpty else {
              // Report back on the main thread since completion may touch UI
              DispatchQueue.main.async { completion("0") }
              return
          }

          // 1. Sort observations by font height (Largest text on screen first)
          // Amounts are almost always the largest text on a receipt, so check big text first
          let sortedByFontSize = observations.sorted { (obs1, obs2) -> Bool in
              return obs1.boundingBox.height > obs2.boundingBox.height
          }

          // 2. Collect valid (non-noise) candidates once, keeping their raw text and whether
          // Vision cleanly recognized an explicit currency marker ("₹"/"Rs"/"INR") on them.
          // Accumulates one entry per usable observation, largest text first
          var candidates: [(text: String, candidate: VNRecognizedText, hasExplicitCurrency: Bool)] = []
          for observation in sortedByFontSize {
              // Ask Vision for its top 5 guesses at what this line of text says
              let alternates = observation.topCandidates(5)
              // Skip this observation if Vision produced no readings at all
              guard let topCandidate = alternates.first else { continue }
              // Trim whitespace/newlines off Vision's best guess for this line
              let rawText = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)

              // Skip dates, timestamps, account numbers, and transaction/reference IDs explicitly
              if self.isHeaderFooterNoise(rawText) {
                  continue
              }

              // Local helper: does this string contain an explicit currency marker?
              func hasCurrencyMarker(_ s: String) -> Bool {
                  s.contains("₹") || s.lowercased().contains("rs") || s.uppercased().contains("INR")
              }

              // Default to the top candidate's text/object and whether it already has a currency marker
              var chosenText = rawText
              var chosenCandidate = topCandidate
              var hasExplicitCurrency = hasCurrencyMarker(rawText)

              // Vision keeps several alternate readings per line. When the top guess misreads "₹"
              // as a plain digit, a lower-ranked alternate for the same line sometimes recognized
              // the currency marker correctly — prefer that over guessing which digit it became.
              if !hasExplicitCurrency {
                  // Look through the remaining (lower-ranked) alternate readings
                  for alt in alternates.dropFirst() {
                      // Trim this alternate's text the same way as the top candidate
                      let altText = alt.string.trimmingCharacters(in: .whitespacesAndNewlines)
                      if hasCurrencyMarker(altText) {
                          // Found an alternate that does carry a currency marker, so switch to it
                          chosenText = altText
                          chosenCandidate = alt
                          hasExplicitCurrency = true
                          // Stop at the first such alternate found
                          break
                      }
                  }
              }

              // Record this observation's chosen text, its Vision candidate object, and currency flag
              candidates.append((chosenText, chosenCandidate, hasExplicitCurrency))
          }

          // 3. Pass 1: prefer lines where Vision cleanly recognized the currency marker itself —
          // these need no artifact guessing and are far less likely to be a stray ID/number
          // (e.g. a "TXN ID: 644714564274" line) mistaken for the amount. We run OCR 4 times (on the
          // original image plus 3 processed variants), so the same line is usually seen multiple
          // times, sometimes with different misreads (e.g. "81,206" once vs "71,206" three times) —
          // take the value most passes agree on rather than whichever candidate happens to come
          // first, since the first one is not necessarily the correct one.
          // Try only the candidates that had an explicit currency marker first
          if let consensus = self.consensusAmount(from: candidates.filter { $0.hasExplicitCurrency }) {
              // Found a consensus amount, so report it back on the main thread
              DispatchQueue.main.async { completion(consensus) }
              return
          }

          // 4. Pass 2: same consensus approach, falling back to the artifact-guessing heuristics.
          // No currency-marked consensus found, so try the remaining (non-currency-marked) candidates
          if let consensus = self.consensusAmount(from: candidates.filter { !$0.hasExplicitCurrency }) {
              // Found a consensus amount this way, so report it back on the main thread
              DispatchQueue.main.async { completion(consensus) }
              return
          }

          // Neither pass produced anything usable, so report "no amount found"
          DispatchQueue.main.async { completion("0") }
      }

      // MARK: - Cross-Pass Consensus
      // Parses every candidate and returns the amount the most candidates agree on. Running OCR
      // across multiple image variants means the same line is often recognized several times, and
      // a majority reading is far more trustworthy than whichever single candidate is checked first.
      private func consensusAmount(from entries: [(text: String, candidate: VNRecognizedText, hasExplicitCurrency: Bool)]) -> String? {
          // Tracks how many times each parsed amount string has been seen
          var counts: [String: Int] = [:]
          // Tracks the order amounts were first encountered, so ties favor the earliest (largest-text) one
          var order: [String] = []
          for entry in entries {
              // Clean/parse this entry's raw text into a normalized amount string, skip if unparseable
              guard let amount = cleanAndParseAmount(entry.text, candidate: entry.candidate) else { continue }
              if counts[amount] == nil {
                  // First time seeing this amount, record its position
                  order.append(amount)
              }
              // Increment this amount's vote count
              counts[amount, default: 0] += 1
          }
          // No parseable amounts at all, so there's no consensus to return
          guard var best = order.first else { return nil }
          // Scan the rest, replacing "best" whenever a later amount has strictly more votes
          for amount in order.dropFirst() where counts[amount]! > counts[best]! {
              best = amount
          }
          return best
      }

      // MARK: - Text Recognition Helper
      private func recognizeTextObservations(in cgImage: CGImage) -> [VNRecognizedTextObservation] {
          // Build a Vision text-recognition request
          let request = VNRecognizeTextRequest()
          // Use the slower but more accurate recognition engine
          request.recognitionLevel = .accurate
          // Disable Vision's language "auto-correction" so raw digits/symbols aren't rewritten into words
          request.usesLanguageCorrection = false
          // "₹" is an Indian-locale glyph; without a locale hint Vision's default (en-US) language
          // model has little exposure to it and is more prone to misclassifying it as a plain digit.
          // This targets the actual root cause (recognition, not post-hoc string guessing) — the
          // artifact-stripping rules below remain as a fallback for whatever still gets through.
          request.recognitionLanguages = ["en-IN", "en-GB", "en-US"]

          // Handler that actually runs Vision requests against this image
          let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
          do {
              // Execute the text-recognition request synchronously
              try handler.perform([request])
              // Return the recognized observations, or an empty list if the cast fails
              return (request.results as? [VNRecognizedTextObservation]) ?? []
          } catch {
              // Recognition failed outright, so return no observations
              return []
          }
      }

      // MARK: - Contrast Enhancement for Stylized/Decorative Text
      private func highContrastVariant(of cgImage: CGImage) -> CGImage? {
          // Wrap the CGImage in a CIImage so Core Image filters can operate on it
          let ciImage = CIImage(cgImage: cgImage)
          // Load the contrast/brightness/saturation filter, bail if unavailable
          guard let filter = CIFilter(name: "CIColorControls") else { return nil }
          // Feed in the source image
          filter.setValue(ciImage, forKey: kCIInputImageKey)
          // Boost contrast well above normal (1.0) to make stylized text pop
          filter.setValue(1.6, forKey: kCIInputContrastKey)
          // Leave brightness unchanged
          filter.setValue(0.0, forKey: kCIInputBrightnessKey)
          // Desaturate fully so color noise doesn't interfere with text detection
          filter.setValue(0.0, forKey: kCIInputSaturationKey)
          // Pull the filtered image out, bail if the filter produced nothing
          guard let output = filter.outputImage else { return nil }
          // Render the CIImage back into a concrete CGImage
          return CIContext().createCGImage(output, from: output.extent)
      }

      // MARK: - Downscale for Oversized Glyphs
      private func downscaledVariant(of cgImage: CGImage, scale: CGFloat) -> CGImage? {
          // Wrap in a CIImage and apply a uniform scale transform
          let ciImage = CIImage(cgImage: cgImage).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
          // Render the scaled CIImage back into a concrete CGImage
          return CIContext().createCGImage(ciImage, from: ciImage.extent)
      }

      // MARK: - Binarization to Strip Decorative Line Art
      private func binarizedVariant(of cgImage: CGImage) -> CGImage? {
          // Wrap the CGImage in a CIImage so Core Image filters can operate on it
          let ciImage = CIImage(cgImage: cgImage)

          // Otsu thresholding auto-picks the split point between foreground/background, which
          // handles varying decorative-background brightness better than a fixed contrast bump.
          // Try the Otsu auto-threshold filter first, if it's available on this OS
          if let otsu = CIFilter(name: "CIColorThresholdOtsu") {
              // Feed in the source image
              otsu.setValue(ciImage, forKey: kCIInputImageKey)
              if let output = otsu.outputImage {
                  // Render the thresholded CIImage back into a concrete CGImage and return it
                  return CIContext().createCGImage(output, from: output.extent)
              }
          }

          // Fallback for OS versions without the Otsu filter: grayscale + aggressive contrast.
          // Load the contrast/saturation filter, bail if unavailable
          guard let filter = CIFilter(name: "CIColorControls") else { return nil }
          // Feed in the source image
          filter.setValue(ciImage, forKey: kCIInputImageKey)
          // Push contrast very high to push pixels toward pure black or white
          filter.setValue(4.0, forKey: kCIInputContrastKey)
          // Desaturate fully
          filter.setValue(0.0, forKey: kCIInputSaturationKey)
          // Pull the filtered image out, bail if the filter produced nothing
          guard let output = filter.outputImage else { return nil }
          // Render the CIImage back into a concrete CGImage
          return CIContext().createCGImage(output, from: output.extent)
      }

      // MARK: - Skip Noise Filtering
      private func isHeaderFooterNoise(_ text: String) -> Bool {
          // Lowercase once so all the substring checks below are case-insensitive
          let lower = text.lowercased()

          // True if the text contains any month abbreviation (signals a date, not an amount)
          let hasMonth = ["jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
              .contains { lower.contains($0) }

          // "am"/"pm" as bare substrings false-positive on common words like "Amount" or "Sample" —
          // only flag them when they actually form a clock time (e.g. "07:38 PM").
          let hasClockTime: Bool = {
              // Build the "H:MM am/pm" regex, bail out (treat as no match) if it fails to compile
              guard let regex = try? NSRegularExpression(pattern: "\\d{1,2}:\\d{2}\\s*(am|pm)", options: .caseInsensitive) else {
                  return false
              }
              // Search the whole string for a match
              let range = NSRange(location: 0, length: lower.utf16.count)
              return regex.firstMatch(in: lower, options: [], range: range) != nil
          }()

          // Masked account/card numbers ("XXXXXXXXXX1237") carry real digits that can otherwise
          // parse as a plausible-looking amount and pollute consensus voting.
          // True if the text contains a run of "x"s, typical of a masked account/card number
          let hasMaskedNumber = lower.contains("xxxx")

          // 10-digit Indian mobile numbers (optionally with a leading +91/91) show up in "Contact"/
          // "Support"/footer lines and, unformatted, parse as a huge but syntactically valid amount.
          let hasPhoneNumber: Bool = {
              // Build the Indian mobile-number regex, bail out (treat as no match) if it fails to compile
              guard let regex = try? NSRegularExpression(pattern: "(?:\\+?91[\\s-]?)?\\b[6-9][0-9]{9}\\b") else {
                  return false
              }
              // Search the whole string for a match
              let range = NSRange(location: 0, length: lower.utf16.count)
              return regex.firstMatch(in: lower, options: [], range: range) != nil
          }()

          // Flag as noise if any of the structural checks above matched, or the line contains
          // any of these known receipt boilerplate phrases
          if hasMonth || hasClockTime || hasMaskedNumber || hasPhoneNumber || lower.contains("savings") ||
             lower.contains("refcl") || lower.contains("account") || lower.contains("credited") ||
             lower.contains("upi send money") || lower.contains("transaction summary") ||
             lower.contains("txn id") || lower.contains("transaction id") || lower.contains("utr") ||
             lower.contains("ref no") || lower.contains("reference") || lower.contains("paid securely") ||
             lower.contains("powered by") {
              return true
          }
          // None of the noise signals matched, so this line is treated as legitimate content
          return false
      }

      // MARK: - Comprehensive Rupee Artifact Engine
      private func cleanAndParseAmount(_ text: String, candidate: VNRecognizedText) -> String? {
          // Mutable working copy of the text we'll progressively strip currency markers from
          var rawText = text
          // Remember whether an explicit ₹/Rs marker was present before we strip it out
          let hadExplicitRupee = rawText.contains("₹") || rawText.lowercased().contains("rs")

          // Strip explicit currency prefixes
          // Remove the rupee symbol
          rawText = rawText.replacingOccurrences(of: "₹", with: "")
          // Remove "Rs." (with the period), case-insensitively
          rawText = rawText.replacingOccurrences(of: "Rs.", with: "", options: .caseInsensitive)
          // Remove bare "Rs", case-insensitively
          rawText = rawText.replacingOccurrences(of: "Rs", with: "", options: .caseInsensitive)
          // Remove "INR", case-insensitively
          rawText = rawText.replacingOccurrences(of: "INR", with: "", options: .caseInsensitive)
          // Trim any leftover whitespace from removing those markers
          var cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
          // Alignment anchor: when hadExplicitRupee is false, none of the replacements above did
          // anything, so `cleaned` still lines up character-for-character with the original `text`.
          // Rule 1/2 below may then strip more leading characters — track how many so the glyph-width
          // check in Rule 4 can offset back into `text` correctly.
          // Snapshot how many characters are left after currency-prefix stripping, used later to
          // offset back into the original `text` for glyph-width lookups
          let lengthBeforeArtifactRules = cleaned.count

          // Fix Rule 1: Leading artifact ('2', '7', '3', '1', 'z', 'Z', '?') attached to 2-digit numbers
          // e.g. "275" -> "75", "175" -> "75", "375" -> "75", "71206" -> "1206"
          // Matches one of these stray leading characters only when exactly 2 digits follow it
          let artifactPrefixPattern = "^[2731zZJ\\?](?=[0-9]{2}$)"
          if let regex = try? NSRegularExpression(pattern: artifactPrefixPattern) {
              // Search the whole cleaned string
              let range = NSRange(location: 0, length: cleaned.utf16.count)
              // Remove the matched leading artifact character, if any
              let result = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
              // Only accept the strip if it left something behind and actually changed the string
              if !result.isEmpty && result != cleaned {
                  cleaned = result
              }
          }

          // Fix Rule 2: Remove leading artifact before larger formatted amounts (e.g., "71,206" -> "1,206")
          // Matches a stray leading character before a comma-formatted number or a 3+ digit run
          let formattedArtifactPattern = "^[273zZJ\\?](?=[0-9]{1,3}(?:,[0-9]{3})+|[0-9]{3,})"
          if let regex = try? NSRegularExpression(pattern: formattedArtifactPattern) {
              // Search the whole cleaned string
              let range = NSRange(location: 0, length: cleaned.utf16.count)
              // Strip the matched leading artifact character, if any
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
          // Only try the glyph-width heuristic when Vision never recognized an explicit ₹/Rs marker —
          // if it did, there's no fused-currency-glyph artifact to strip
          if !hadExplicitRupee {
              // Work out how many characters Rules 1/2 already stripped, to realign with `text`
              let frontOffset = lengthBeforeArtifactRules - cleaned.count
              // Attempt to detect and strip a misread-currency-glyph digit by comparing rendered widths
              cleaned = stripArtifactGlyphByWidth(
                  cleaned: cleaned,
                  originalText: text,
                  frontOffset: frontOffset,
                  candidate: candidate
              )
          }

          // Fix Rule 4: Direct explicit overrides for small edge cases, kept only as a last-resort
          // fallback for when glyph-width data above isn't available (e.g. boundingBox lookup fails).
          // Known misread patterns that always mean "1"
          if cleaned == "31" || cleaned == "71" || cleaned == "21" { return "1" }
          // "12" only means "2" when we have other evidence (currency marker or a very short original text)
          if cleaned == "12" && (hadExplicitRupee || text.count <= 3) { return "2" }

          // Standard numeric extraction engine (supports 75, 1,206, and 1206.50)
          // Matches a comma-grouped number or a plain digit run, with an optional decimal part
          let standardAmountPattern = "([0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\\.[0-9]{1,2})?"
          if let regex = try? NSRegularExpression(pattern: standardAmountPattern),
             // Find the first numeric match in the cleaned string
             let match = regex.firstMatch(in: cleaned, range: NSRange(location: 0, length: cleaned.utf16.count)),
             // Convert the NSRange match back into a Swift String range
             let range = Range(match.range(at: 0), in: cleaned) {

              // Extract the matched substring and strip thousands-separator commas
              let amountStr = String(cleaned[range]).replacingOccurrences(of: ",", with: "")
              // Guard against reference numbers/IDs/phone numbers that slip through (e.g.
              // "CL58933319481774000799381" or a bare 10-digit mobile number) matching this same
              // digit pattern. Real personal-expense amounts don't run into the crores, so cap well
              // below that rather than only rejecting values large enough to overflow Int.
              // Parse to a number and only accept it if it's positive and below the sanity cap
              if let val = Double(amountStr), val > 0, val < 10_000_000 {
                  if val.truncatingRemainder(dividingBy: 1) == 0 {
                      // Whole number, so format it without a trailing ".0"
                      return String(Int(val))
                  }
                  // Has a fractional part, so keep it as-is
                  return String(val)
              }
          }

          // Nothing in this text parsed as a plausible amount
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
          // Only applies when there's a leading digit and at least one more character to compare it to
          guard let first = cleaned.first, first.isNumber, cleaned.count >= 2 else { return cleaned }

          // Collect the run of digits immediately following the first character
          let digitsAfterFirst = cleaned.dropFirst().prefix(while: { $0.isNumber })
          // Need at least one neighbouring digit to compare widths against
          guard digitsAfterFirst.count >= 1 else { return cleaned }

          // Look up the rendered width of the first (suspect) glyph, bail if unavailable
          guard let firstWidth = glyphWidth(at: frontOffset, in: originalText, candidate: candidate) else { return cleaned }

          // Sample up to 4 neighbouring digits (not just the immediate next one) and use the median,
          // not the mean, as the baseline. '1' is naturally much narrower than other digits in most
          // fonts, so a plain average of only 1-2 neighbours can be skewed enough by a stray '1' to
          // hide a real artifact (e.g. "81206" from "₹1,206" — averaging '1' and '2' pulls the
          // baseline down enough that '8' no longer looks anomalous). A median over more digits is
          // far less sensitive to any single outlier-width digit.
          // Compare against at most 4 neighbouring digits
          let sampleCount = min(4, digitsAfterFirst.count)
          // Look up rendered widths for each of those neighbouring digit positions
          let sampleWidths = (1...sampleCount).compactMap {
              glyphWidth(at: frontOffset + $0, in: originalText, candidate: candidate)
          }
          // Need at least one successful width lookup to compare against
          guard !sampleWidths.isEmpty else { return cleaned }

          // Use the median neighbouring width as the "normal digit width" baseline
          let baselineWidth = median(of: sampleWidths)
          // A zero-width baseline would make the ratio meaningless
          guard baselineWidth > 0 else { return cleaned }

          // How much wider/narrower the first glyph is compared to its neighbours
          let ratio = firstWidth / baselineWidth

          // With only one neighbouring digit to compare against, a genuine '1' (naturally much
          // narrower than other digits in most fonts) can look like a false match — so require a
          // more extreme deviation before stripping when we only have a single sample to go on.
          // Tighter bounds when we have 2+ samples, looser (more tolerant) bounds with just 1
          let (lowerBound, upperBound) = sampleWidths.count >= 2 ? (0.6, 1.6) : (0.4, 2.2)

          if ratio < lowerBound || ratio > upperBound {
              // Width is anomalous enough to be a misread currency glyph, so drop it
              return String(cleaned.dropFirst())
          }
          // Width looks like a normal digit, so leave the string untouched
          return cleaned
      }

      private func median(of values: [CGFloat]) -> CGFloat {
          // Sort ascending so the middle element(s) can be picked directly
          let sorted = values.sorted()
          let mid = sorted.count / 2
          if sorted.count % 2 == 0 {
              // Even count: average the two middle values
              return (sorted[mid - 1] + sorted[mid]) / 2
          }
          // Odd count: the single middle value is the median
          return sorted[mid]
      }

      private func glyphWidth(at offset: Int, in text: String, candidate: VNRecognizedText) -> CGFloat? {
          // Convert the integer offset into a String.Index, bail if it's out of bounds
          guard let start = text.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex),
                start < text.endIndex else { return nil }
          // The range covers exactly one character, starting at `start`
          let end = text.index(after: start)
          // Ask Vision for the bounding box of that single character, bail if it can't compute one
          guard let box = try? candidate.boundingBox(for: start..<end) else { return nil }
          // Return just the width of that bounding box
          return box.boundingBox.width
      }

  private func dismiss() {
    // Tell the share extension host we're done, with no items to hand back
    self.extensionContext?.completeRequest(
      returningItems: [],
      completionHandler: nil
    )
  }
}
