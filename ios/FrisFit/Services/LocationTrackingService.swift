import Foundation
import CoreLocation

nonisolated enum GPSSignalQuality: Sendable {
    case none
    case poor
    case fair
    case good
    case excellent

    var label: String {
        switch self {
        case .none: "No Signal"
        case .poor: "Poor"
        case .fair: "Fair"
        case .good: "Good"
        case .excellent: "Excellent"
        }
    }

    var iconName: String {
        switch self {
        case .none: "location.slash.fill"
        case .poor: "location.fill"
        case .fair: "location.fill"
        case .good: "location.fill"
        case .excellent: "location.fill"
        }
    }

    var barCount: Int {
        switch self {
        case .none: 0
        case .poor: 1
        case .fair: 2
        case .good: 3
        case .excellent: 4
        }
    }

    static func from(accuracy: Double) -> GPSSignalQuality {
        switch accuracy {
        case ..<0: .none
        case 0..<5: .excellent
        case 5..<10: .good
        case 10..<20: .fair
        case 20..<50: .poor
        default: .none
        }
    }
}

@Observable
final class LocationTrackingService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationTrackingService()

    private let manager = CLLocationManager()

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?
    var gpsSignal: GPSSignalQuality = .none
    var isTracking: Bool = false

    private var onLocationUpdate: ((CLLocation) -> Void)?

    private let minHorizontalAccuracy: Double = 30
    private let maxSpeedMps: Double = 50
    private let minDistanceFilter: Double = 3

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = minDistanceFilter
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    var hasLocationPermission: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func startTracking(onUpdate: @escaping (CLLocation) -> Void) {
        onLocationUpdate = onUpdate
        isTracking = true
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] != nil {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        isTracking = false
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
        onLocationUpdate = nil
        gpsSignal = .none
    }

    func isLocationValid(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= minHorizontalAccuracy else {
            return false
        }
        guard location.speed >= 0,
              location.speed <= maxSpeedMps else {
            return false
        }
        let age = abs(location.timestamp.timeIntervalSinceNow)
        guard age < 10 else { return false }
        return true
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else { return }
            gpsSignal = GPSSignalQuality.from(accuracy: location.horizontalAccuracy)
            currentLocation = location
            if isLocationValid(location) {
                onLocationUpdate?(location)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            gpsSignal = .none
        }
    }

    static func distanceInMiles(from: CLLocation, to: CLLocation) -> Double {
        from.distance(from: to) / 1609.344
    }

    static func speedInMph(metersPerSecond: Double) -> Double {
        guard metersPerSecond > 0 else { return 0 }
        return metersPerSecond * 2.23694
    }

    static func elevationInFeet(meters: Double) -> Double {
        meters * 3.28084
    }
}
