import Foundation

nonisolated struct VialScanPrefill: Sendable, Equatable {
    var compoundName: String
    var vialSizeMg: Double
    var lotNumber: String
    var vialNumber: String = ""
    var expirationDate: Date?
    var manufacturer: String = ""
    var isDiluent: Bool = false
    var diluentVolumeMl: Double? = nil
    var labelImageFilename: String? = nil
}

extension VialScanPrefill {
    init(scan: ScannedVialLabel) {
        self.compoundName = scan.compoundName
        self.vialSizeMg = scan.vialSizeMg ?? 0
        self.lotNumber = scan.lotNumber
        self.vialNumber = scan.vialNumber
        self.expirationDate = scan.expirationDate
        self.manufacturer = scan.manufacturer
        self.isDiluent = scan.isDiluent
        self.diluentVolumeMl = scan.diluentVolumeMl
        self.labelImageFilename = scan.labelImageFilename
    }
}

struct VialScanHandoff: Identifiable {
    enum Kind {
        case inventory
        case reconstitute
        case protocolSetup
    }

    let id = UUID()
    let kind: Kind
    let prefill: VialScanPrefill
}
