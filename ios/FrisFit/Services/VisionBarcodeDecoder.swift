import Foundation
import Vision
import UIKit

nonisolated struct DecodedBarcode: Sendable {
    let rawValue: String
    let symbology: String
    let lotNumber: String?
    let expirationDate: Date?
    let gtin: String?
}

nonisolated final class VisionBarcodeDecoder: Sendable {
    static let shared = VisionBarcodeDecoder()

    /// Detect barcodes / QR / DataMatrix on-device. Returns the first one that produced useful data.
    func decode(_ imageData: Data) async -> DecodedBarcode? {
        guard let cgImage = UIImage(data: imageData)?.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { req, _ in
                let observations = (req.results as? [VNBarcodeObservation]) ?? []
                for obs in observations {
                    guard let raw = obs.payloadStringValue else { continue }
                    let decoded = VisionBarcodeDecoder.parseGS1(raw: raw, symbology: obs.symbology.rawValue)
                    continuation.resume(returning: decoded)
                    return
                }
                continuation.resume(returning: nil)
            }
            request.revision = VNDetectBarcodesRequestRevision3
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    /// Parse GS1 application identifiers commonly used on pharmacy DataMatrix codes.
    /// (01) GTIN-14, (10) Lot, (17) Expiry YYMMDD, (21) Serial
    private static func parseGS1(raw: String, symbology: String) -> DecodedBarcode {
        var lot: String? = nil
        var expiry: Date? = nil
        var gtin: String? = nil

        var s = raw.replacingOccurrences(of: "\u{001D}", with: "|")
        s = s.replacingOccurrences(of: "\u{00E8}", with: "|")

        func capture(_ ai: String, fixedLength: Int?) {
            guard let range = s.range(of: "(\(ai))") ?? s.range(of: ai) else { return }
            let afterStart = range.upperBound
            guard afterStart < s.endIndex else { return }
            let rest = String(s[afterStart...])
            let value: String
            if let len = fixedLength {
                value = String(rest.prefix(len))
            } else if let sep = rest.firstIndex(where: { $0 == "|" || $0 == "(" }) {
                value = String(rest[..<sep])
            } else {
                value = rest
            }
            switch ai {
            case "01": gtin = value
            case "10": lot = value.trimmingCharacters(in: .whitespaces)
            case "17":
                if value.count == 6 {
                    let f = DateFormatter()
                    f.dateFormat = "yyMMdd"
                    f.locale = Locale(identifier: "en_US_POSIX")
                    if var d = f.date(from: value) {
                        // Day "00" means end of month.
                        let dd = value.suffix(2)
                        if dd == "00" {
                            let cal = Calendar(identifier: .gregorian)
                            var comps = cal.dateComponents([.year, .month], from: d)
                            comps.month = (comps.month ?? 1) + 1
                            comps.day = 0
                            if let end = cal.date(from: comps) { d = end }
                        }
                        expiry = d
                    }
                }
            default: break
            }
        }

        capture("01", fixedLength: 14)
        capture("17", fixedLength: 6)
        capture("10", fixedLength: nil)

        return DecodedBarcode(rawValue: raw, symbology: symbology, lotNumber: lot, expirationDate: expiry, gtin: gtin)
    }

}
