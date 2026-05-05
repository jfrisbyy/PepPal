import Foundation

nonisolated enum ProtocolExportService {
    static func csvForDoctor(_ proto: PeptideProtocol, notes: [ProtocolNote]) -> String {
        var out = ""

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dtf = DateFormatter()
        dtf.dateFormat = "yyyy-MM-dd HH:mm"

        out += "# Protocol Summary\n"
        out += "Name,\(escape(proto.name))\n"
        out += "Goal,\(escape(proto.goal.rawValue))\n"
        out += "Start Date,\(df.string(from: proto.startDate))\n"
        out += "Current Day,\(proto.currentDay)\n"
        out += "Current Phase,\(proto.currentPhase.rawValue)\n"
        out += "Active,\(proto.isActive ? "Yes" : "No")\n"
        out += "\n"

        out += "# Compounds\n"
        out += "Name,Dose (mcg),Frequency,Route,Vial Size (mg),Reconstitution (mL),Vendor,Batch,Expiration\n"
        for c in proto.compounds {
            let row: [String] = [
                c.compoundName,
                String(format: "%g", c.doseMcg),
                c.frequency,
                c.injectionRoute.rawValue,
                c.vialSizeMg.map { String(format: "%g", $0) } ?? "",
                c.reconstitutionVolume.map { String(format: "%g", $0) } ?? "",
                c.vendorName ?? "",
                c.batchNumber ?? "",
                c.expirationDate.map { df.string(from: $0) } ?? ""
            ]
            out += row.map(escape).joined(separator: ",") + "\n"
        }
        out += "\n"

        out += "# Dose Log\n"
        out += "Timestamp,Compound,Dose (mcg),Injection Site,Skipped,Skip Reason,Notes\n"
        for d in proto.doseLog.sorted(by: { $0.timestamp > $1.timestamp }) {
            let row: [String] = [
                dtf.string(from: d.timestamp),
                d.compoundName,
                String(format: "%g", d.doseMcg),
                d.injectionSite.rawValue,
                d.wasSkipped ? "Yes" : "No",
                d.skipReason ?? "",
                d.notes
            ]
            out += row.map(escape).joined(separator: ",") + "\n"
        }
        out += "\n"

        out += "# Side Effects\n"
        out += "Timestamp,Effect,Severity,Notes\n"
        for s in proto.sideEffectLog.sorted(by: { $0.timestamp > $1.timestamp }) {
            let row: [String] = [
                dtf.string(from: s.timestamp),
                s.effect,
                String(s.severity),
                s.notes
            ]
            out += row.map(escape).joined(separator: ",") + "\n"
        }
        out += "\n"

        out += "# Supplements\n"
        out += "Name,Dose,Frequency\n"
        for sup in proto.supplements {
            out += [sup.name, sup.dose, sup.frequency].map(escape).joined(separator: ",") + "\n"
        }
        out += "\n"

        out += "# Notes\n"
        out += "Date,Note\n"
        for n in notes.sorted(by: { $0.timestamp > $1.timestamp }) {
            out += [dtf.string(from: n.timestamp), n.text].map(escape).joined(separator: ",") + "\n"
        }

        return out
    }

    static func writeTempFile(csv: String, filenameHint: String) -> URL? {
        let safe = filenameHint.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("EPTI_\(safe).csv")
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }
}
