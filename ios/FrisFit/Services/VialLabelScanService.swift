import Foundation
import UIKit

nonisolated struct ScannedVialLabel: Sendable, Codable {
    var compoundName: String
    var vialSizeMg: Double?
    var lotNumber: String
    var vialNumber: String = ""
    var expirationDate: Date?
    var manufacturer: String
    var confidence: [String: Confidence]
    var sources: [String: Source]
    var isDiluent: Bool
    var diluentVolumeMl: Double?
    var labelImageFilename: String?
    var handwrittenNotes: String = ""
    var reconstitutedOn: Date? = nil
    var unknownCompound: Bool = false

    nonisolated enum Confidence: String, Sendable, Codable {
        case high
        case low
        case missing
    }

    nonisolated enum Source: String, Sendable, Codable {
        case barcode
        case ocr
        case user
        case none
    }

    enum CodingKeys: String, CodingKey {
        case compoundName, vialSizeMg, lotNumber, vialNumber, expirationDate
        case manufacturer, confidence, sources, isDiluent, diluentVolumeMl
        case labelImageFilename, handwrittenNotes, reconstitutedOn, unknownCompound
    }

    init(
        compoundName: String,
        vialSizeMg: Double?,
        lotNumber: String,
        vialNumber: String = "",
        expirationDate: Date?,
        manufacturer: String,
        confidence: [String: Confidence],
        sources: [String: Source],
        isDiluent: Bool,
        diluentVolumeMl: Double?,
        labelImageFilename: String?,
        handwrittenNotes: String = "",
        reconstitutedOn: Date? = nil,
        unknownCompound: Bool = false
    ) {
        self.compoundName = compoundName
        self.vialSizeMg = vialSizeMg
        self.lotNumber = lotNumber
        self.vialNumber = vialNumber
        self.expirationDate = expirationDate
        self.manufacturer = manufacturer
        self.confidence = confidence
        self.sources = sources
        self.isDiluent = isDiluent
        self.diluentVolumeMl = diluentVolumeMl
        self.labelImageFilename = labelImageFilename
        self.handwrittenNotes = handwrittenNotes
        self.reconstitutedOn = reconstitutedOn
        self.unknownCompound = unknownCompound
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        compoundName = try c.decodeIfPresent(String.self, forKey: .compoundName) ?? ""
        vialSizeMg = try c.decodeIfPresent(Double.self, forKey: .vialSizeMg)
        lotNumber = try c.decodeIfPresent(String.self, forKey: .lotNumber) ?? ""
        vialNumber = try c.decodeIfPresent(String.self, forKey: .vialNumber) ?? ""
        expirationDate = try c.decodeIfPresent(Date.self, forKey: .expirationDate)
        manufacturer = try c.decodeIfPresent(String.self, forKey: .manufacturer) ?? ""
        confidence = try c.decodeIfPresent([String: Confidence].self, forKey: .confidence) ?? [:]
        sources = try c.decodeIfPresent([String: Source].self, forKey: .sources) ?? [:]
        isDiluent = try c.decodeIfPresent(Bool.self, forKey: .isDiluent) ?? false
        diluentVolumeMl = try c.decodeIfPresent(Double.self, forKey: .diluentVolumeMl)
        labelImageFilename = try c.decodeIfPresent(String.self, forKey: .labelImageFilename)
        handwrittenNotes = try c.decodeIfPresent(String.self, forKey: .handwrittenNotes) ?? ""
        reconstitutedOn = try c.decodeIfPresent(Date.self, forKey: .reconstitutedOn)
        unknownCompound = try c.decodeIfPresent(Bool.self, forKey: .unknownCompound) ?? false
    }

    static let empty = ScannedVialLabel(
        compoundName: "",
        vialSizeMg: nil,
        lotNumber: "",
        vialNumber: "",
        expirationDate: nil,
        manufacturer: "",
        confidence: [:],
        sources: [:],
        isDiluent: false,
        diluentVolumeMl: nil,
        labelImageFilename: nil,
        handwrittenNotes: "",
        reconstitutedOn: nil,
        unknownCompound: false
    )
}

nonisolated enum VialScanError: Error, Sendable {
    case noTextDetected
    case networkError
    case decodingError
}

nonisolated final class VialLabelScanService: Sendable {
    static let shared = VialLabelScanService()

    private let model = "google/gemini-3-flash"

    private let systemPrompt = """
    You are a precise optical character recognition assistant for pharmaceutical vial labels.
    You may receive MULTIPLE images of the SAME vial taken from different angles (front label, back label, top/cap).
    Combine evidence across all images. If a field is visible in any one image, use it. Prefer printed text over handwritten when they conflict, but always include handwritten text in the handwrittenNotes field.

    Vials can be:
    A) Research peptide / compounded drug vials (semaglutide, tirzepatide, BPC-157, etc.)
    B) Diluent vials — bacteriostatic water, sterile water for injection, or bacteriostatic saline.

    Extract these fields when visible:
    - compoundName: the peptide / drug name OR the diluent name. Use the canonical name. Examples: "Retatrutide", "BPC-157", "Tirzepatide", "Semaglutide", "Bacteriostatic Water", "Sterile Water", "Bacteriostatic Saline". If the label shows multiple drugs (a blend), pick the primary/first one.
    - vialSizeMg: total peptide content in milligrams (numeric only). If the label says "5mg" → 5. If it says "2000mcg" → 2. Null for diluent vials or if unclear.
    - diluentVolumeMl: for diluent vials only, the total volume in mL (e.g. "30 mL" → 30). Null for peptide vials.
    - isDiluent: true if this is a diluent vial (bacteriostatic water, sterile water, saline), false otherwise.
    - lotNumber: the lot/batch number — usually labeled "Lot", "Batch", "LOT", or "L:". Copy verbatim. Empty string if missing.
    - vialNumber: a printed serial / vial / unit / reference number specific to THIS vial — usually labeled "Vial #", "Serial", "Unit", "Ref", "REF", or "S/N". This is DIFFERENT from lotNumber. Copy verbatim. Empty string if missing.
    - expirationDate: expiration / use-by date as ISO-8601 (YYYY-MM-DD). If only month+year is printed, use the last day of that month. Null if missing.
    - manufacturer: company / brand / compounding pharmacy name. Empty string if missing.
    - handwrittenNotes: any handwritten text on the vial — dose scribbles, "opened on" dates, reconstitution dates, initials. Copy verbatim. Empty string if none.
    - reconstitutedOnDate: if a "mixed on", "opened", or "reconstituted" date is visible (printed or handwritten), return as YYYY-MM-DD. Null if missing.
    - For each field, rate your confidence as "high", "low", or "missing".

    Respond with ONLY a JSON object, no markdown, no commentary. Schema:
    {
      "compoundName": "string",
      "vialSizeMg": number_or_null,
      "diluentVolumeMl": number_or_null,
      "isDiluent": boolean,
      "lotNumber": "string",
      "vialNumber": "string",
      "expirationDate": "YYYY-MM-DD" or null,
      "manufacturer": "string",
      "handwrittenNotes": "string",
      "reconstitutedOnDate": "YYYY-MM-DD" or null,
      "confidence": {
        "compoundName": "high|low|missing",
        "vialSizeMg": "high|low|missing",
        "lotNumber": "high|low|missing",
        "vialNumber": "high|low|missing",
        "expirationDate": "high|low|missing",
        "manufacturer": "high|low|missing"
      }
    }
    """

    /// Run both on-device barcode decoding and AI OCR, then merge results.
    /// Barcode data (lot + expiration) takes precedence when present — it's authoritative.
    func scan(imageData: Data) async throws -> ScannedVialLabel {
        try await scan(imagesData: [imageData])
    }

    /// Multi-angle scan — sends all images in a single Gemini request and merges in any barcode data found across them.
    func scan(imagesData: [Data]) async throws -> ScannedVialLabel {
        guard !imagesData.isEmpty else { throw VialScanError.noTextDetected }

        async let ocrTask = runOCR(imagesData: imagesData)

        // Run barcode decoding across every image; first hit wins.
        var barcode: DecodedBarcode? = nil
        for data in imagesData {
            if let b = await VisionBarcodeDecoder.shared.decode(data) {
                barcode = b
                break
            }
        }

        var result = try await ocrTask

        if let b = barcode {
            if let lot = b.lotNumber, !lot.isEmpty {
                result.lotNumber = lot
                result.confidence["lotNumber"] = .high
                result.sources["lotNumber"] = .barcode
            }
            if let exp = b.expirationDate {
                result.expirationDate = exp
                result.confidence["expirationDate"] = .high
                result.sources["expirationDate"] = .barcode
            }
        }

        return result
    }

    /// Barcode-only decode — returns nil if no useful code found.
    func decodeBarcodeOnly(imageData: Data) async -> DecodedBarcode? {
        await VisionBarcodeDecoder.shared.decode(imageData)
    }

    private func runOCR(imagesData: [Data]) async throws -> ScannedVialLabel {
        let angleLabels = ["front", "back", "cap"]

        var userContent: [[String: Any]] = [[
            "type": "text",
            "text": imagesData.count == 1
                ? "Extract the fields from this vial label (peptide or diluent)."
                : "You are looking at \(imagesData.count) photos of the SAME vial from different angles. Combine evidence across all images to extract every visible field."
        ]]

        for (idx, imageData) in imagesData.enumerated() {
            let compressed = compress(imageData: imageData) ?? imageData
            let base64 = compressed.base64EncodedString()
            let dataURL = "data:image/jpeg;base64,\(base64)"
            let angle = idx < angleLabels.count ? angleLabels[idx] : "angle \(idx + 1)"
            userContent.append(["type": "text", "text": "Image \(idx + 1) (\(angle)):"])
            userContent.append(["type": "image_url", "image_url": ["url": dataURL]])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "temperature": 0.1,
            "max_tokens": 600
        ]

        let responseText = try await callProxy(body: body)
        return try parse(responseText)
    }

    private func compress(imageData: Data) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }
        let maxDim: CGFloat = 1280
        let size = image.size
        let scale = min(1, maxDim / max(size.width, size.height))
        if scale >= 1 {
            return image.jpegData(compressionQuality: 0.7)
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized?.jpegData(compressionQuality: 0.7)
    }

    private func callProxy(body: [String: Any]) async throws -> String {
        let base = Config.EXPO_PUBLIC_TOOLKIT_URL
        let key = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard let url = URL(string: "\(base)/v2/vercel/v1/chat/completions") else {
            throw VialScanError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            print("[VialScan] HTTP \(http.statusCode): \(bodyStr)")
            throw VialScanError.networkError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw VialScanError.decodingError
        }
        return content
    }

    private func parse(_ text: String) throws -> ScannedVialLabel {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") { cleaned = String(cleaned.dropFirst(7)) }
        else if cleaned.hasPrefix("```") { cleaned = String(cleaned.dropFirst(3)) }
        if cleaned.hasSuffix("```") { cleaned = String(cleaned.dropLast(3)) }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        guard let jsonData = cleaned.data(using: .utf8),
              let raw = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw VialScanError.decodingError
        }

        let name = (raw["compoundName"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let vialMg: Double? = {
            if let n = raw["vialSizeMg"] as? Double { return n }
            if let n = raw["vialSizeMg"] as? Int { return Double(n) }
            if let s = raw["vialSizeMg"] as? String { return Double(s) }
            return nil
        }()
        let diluentMl: Double? = {
            if let n = raw["diluentVolumeMl"] as? Double { return n }
            if let n = raw["diluentVolumeMl"] as? Int { return Double(n) }
            if let s = raw["diluentVolumeMl"] as? String { return Double(s) }
            return nil
        }()
        let lot = (raw["lotNumber"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let vialNumber = (raw["vialNumber"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let mfg = (raw["manufacturer"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        let handwritten = (raw["handwrittenNotes"] as? String ?? "").trimmingCharacters(in: .whitespaces)
        var isDiluent = (raw["isDiluent"] as? Bool) ?? false

        var reconOn: Date? = nil
        if let reconStr = raw["reconstitutedOnDate"] as? String, !reconStr.isEmpty {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            reconOn = f.date(from: reconStr)
        }

        var exp: Date? = nil
        if let expStr = raw["expirationDate"] as? String, !expStr.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            exp = formatter.date(from: expStr)
        }

        var conf: [String: ScannedVialLabel.Confidence] = [:]
        if let confDict = raw["confidence"] as? [String: String] {
            for (k, v) in confDict {
                conf[k] = ScannedVialLabel.Confidence(rawValue: v) ?? .missing
            }
        }

        let canonical = canonicalizeName(name)

        // Auto-detect diluent from the name if the model forgot to set the flag.
        if !isDiluent {
            let lower = canonical.lowercased()
            if lower.contains("bacteriostatic") || lower.contains("sterile water") || lower.contains("bac water") || lower.contains("saline") {
                isDiluent = true
            }
        }

        if canonical.isEmpty && vialMg == nil && lot.isEmpty && exp == nil && diluentMl == nil {
            throw VialScanError.noTextDetected
        }

        var sources: [String: ScannedVialLabel.Source] = [:]
        for key in ["compoundName", "vialSizeMg", "lotNumber", "vialNumber", "expirationDate", "manufacturer"] {
            let c = conf[key] ?? .missing
            sources[key] = c == .missing ? Source.none : Source.ocr
        }

        // Detect unknown compound: not in DB, not a recognized diluent.
        let unknown: Bool = {
            guard !canonical.isEmpty, !isDiluent else { return false }
            let lower = canonical.lowercased()
            if CompoundDatabase.all.contains(where: { $0.name.lowercased() == lower }) { return false }
            if CompoundDatabase.all.contains(where: { lower.contains($0.name.lowercased()) || $0.name.lowercased().contains(lower) }) { return false }
            return true
        }()

        return ScannedVialLabel(
            compoundName: canonical,
            vialSizeMg: vialMg,
            lotNumber: lot,
            vialNumber: vialNumber,
            expirationDate: exp,
            manufacturer: mfg,
            confidence: conf,
            sources: sources.mapValues { $0 },
            isDiluent: isDiluent,
            diluentVolumeMl: diluentMl,
            labelImageFilename: nil,
            handwrittenNotes: handwritten,
            reconstitutedOn: reconOn,
            unknownCompound: unknown
        )
    }

    /// Bridge for Source enum (avoids repeating the type path above).
    private typealias Source = ScannedVialLabel.Source

    /// Try to match OCR output to a compound in the local database for cleaner display.
    private func canonicalizeName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        let lower = trimmed.lowercased()

        // Diluent canonicalization
        if lower.contains("bacteriostatic") && lower.contains("water") { return "Bacteriostatic Water" }
        if lower.contains("bac") && lower.contains("water") { return "Bacteriostatic Water" }
        if lower.contains("sterile") && lower.contains("water") { return "Sterile Water" }
        if lower.contains("saline") { return "Bacteriostatic Saline" }

        if let match = CompoundDatabase.all.first(where: { $0.name.lowercased() == lower }) {
            return match.name
        }
        if let match = CompoundDatabase.all.first(where: { lower.contains($0.name.lowercased()) || $0.name.lowercased().contains(lower) }) {
            return match.name
        }
        return trimmed
    }
}
