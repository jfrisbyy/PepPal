import SwiftUI

@Observable
final class ProfileBannerStore {
    static let shared = ProfileBannerStore()

    private let fileName = "profile_banner.jpg"
    private let lastUrlKey = "profile_banner_last_url"

    var bannerData: Data?

    private init() {
        bannerData = loadFromDisk()
    }

    var bannerImage: UIImage? {
        guard let bannerData else { return nil }
        return UIImage(data: bannerData)
    }

    func setBanner(_ data: Data?) {
        bannerData = data
        if let data {
            try? data.write(to: fileURL(), options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: fileURL())
            UserDefaults.standard.removeObject(forKey: lastUrlKey)
        }
    }

    func syncRemote(urlString: String?) {
        guard let urlString, !urlString.isEmpty, let url = URL(string: urlString) else {
            if bannerData != nil {
                setBanner(nil)
            }
            return
        }
        let lastUrl = UserDefaults.standard.string(forKey: lastUrlKey)
        if lastUrl == urlString && bannerData != nil { return }

        Task { @MainActor in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                self.bannerData = data
                try? data.write(to: self.fileURL(), options: .atomic)
                UserDefaults.standard.set(urlString, forKey: self.lastUrlKey)
            } catch {
                print("BANNER_SYNC: failed to fetch \(urlString): \(error)")
            }
        }
    }

    private func loadFromDisk() -> Data? {
        try? Data(contentsOf: fileURL())
    }

    private func fileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(fileName)
    }
}
