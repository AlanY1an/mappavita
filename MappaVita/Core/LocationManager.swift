import SwiftUI
import MapKit
import CoreLocation

// This class is used to manage the location of the user
@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var isRequestingLocation = false
    private var lastMonitoredLocation: CLLocation?

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?
    @Published var error: Error?
    
    // Callback properties
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onSignificantLocationChange: ((CLLocation, Double) -> Void)?
    
    // Parameters for monitoring
    var monitoringDistance: Double = 50.0  // 默认50米监控半径
    var isMonitoringLocation: Bool = false {
        didSet {
            if isMonitoringLocation {
                startUpdatingLocation()
            } else {
                stopUpdatingLocation()
            }
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
        locationManager.activityType = .other
        
     
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        checkInitialAuthorization()
    }

    func requestLocationPermission() {
        print("📍 Requesting location permission...")
    
        locationManager.requestAlwaysAuthorization()
    }
    
    func requestLocation() {
        print("📍 Requesting single location update...")
        guard !isRequestingLocation else { return }
        
        isRequestingLocation = true
        locationManager.requestLocation()
    }

    private func checkInitialAuthorization() {
        let status = locationManager.authorizationStatus
        print("📍 Initial Authorization Status: \(status.rawValue)")

        switch status {
        case .notDetermined:
            requestLocationPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .restricted, .denied:
            print("❌ Location access restricted or denied.")
        @unknown default:
            break
        }
    }

    func startUpdatingLocation() {
        print("🚀 Starting location updates...")
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        print("🛑 Stopping location updates...")
        locationManager.stopUpdatingLocation()
    }
    
    // Start monitoring significant location changes
    func startMonitoringSignificantLocationChanges() {
        isMonitoringLocation = true
        print("👁️ Started monitoring significant location changes (min distance: \(monitoringDistance)m)")
        lastMonitoredLocation = lastLocation
    }
    
    // Stop monitoring significant location changes
    func stopMonitoringSignificantLocationChanges() {
        isMonitoringLocation = false
        lastMonitoredLocation = nil
        print("🚫 Stopped monitoring significant location changes")
    }
    
    // Calculate distance between current and last monitored location
    private func checkForSignificantLocationChange(newLocation: CLLocation) {
   
        if !isMonitoringLocation {
            return
        }

        if lastMonitoredLocation == nil {
            lastMonitoredLocation = newLocation
            print("📍 Set initial monitoring location: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
            onSignificantLocationChange?(newLocation, 0)
            return
        }
        
        let lastMonitored = lastMonitoredLocation!
        let distance = newLocation.distance(from: lastMonitored)
        print("📏 Distance to last monitored location: \(distance) meters")
        
       
        if distance >= monitoringDistance {
            print("🔔 Detected significant location change: \(distance) meters")
            onSignificantLocationChange?(newLocation, distance)
            lastMonitoredLocation = newLocation
        } else {
   
            print("📍 Still in the same location, triggering location update to maintain tracking")
            onSignificantLocationChange?(newLocation, 0)
        }
    }

    // MARK: - CLLocationManagerDelegate
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            print("📥 Authorization status changed to: \(newStatus.rawValue)")
            authorizationStatus = newStatus
            onAuthorizationChange?(newStatus)

            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                startUpdatingLocation()
            case .restricted, .denied:
                print("❌ Location access denied after change.")
            case .notDetermined:
                print("⏳ Authorization still not determined after change.")
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            self.lastLocation = location
            onLocationUpdate?(location)
            isRequestingLocation = false
            
            // Check if this is a significant change that needs to be monitored
            checkForSignificantLocationChange(newLocation: location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ Location manager failed: \(error.localizedDescription)")
            self.error = error
            isRequestingLocation = false
        }
    }
}
