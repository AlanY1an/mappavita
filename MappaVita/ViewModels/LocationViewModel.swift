import Foundation
import CoreLocation
import MapKit
import SwiftUI

@MainActor
class LocationViewModel: ObservableObject {
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var showLocationAlert = false
    
    let locationManager = LocationManager()
    private var mapPositionBinding: Binding<MapCameraPosition>?
    
    init() {
        setupBindings()
        locationManager.requestLocationPermission()
    }
    
    private func setupBindings() {
        locationManager.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.lastLocation = location
                self?.updateMapPosition(with: location)
            }
        }
        
        locationManager.onAuthorizationChange = { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
            }
        }
    }
    
    private func updateMapPosition(with location: CLLocation) {
        guard let mapPosition = mapPositionBinding else { return }
        
        withAnimation {
            mapPosition.wrappedValue = .camera(MapCamera(
                centerCoordinate: location.coordinate,
                distance: 1000,
                heading: 0,
                pitch: 0
            ))
        }
    }
    
    func requestLocationPermission() {
        locationManager.requestLocationPermission()
    }
    
    func centerOnUserLocation(with mapPosition: Binding<MapCameraPosition>?, forceCenter: Bool = true) {
      
        if authorizationStatus == .denied || authorizationStatus == .restricted {
            showLocationAlert = true
            return
        }
        
        if forceCenter {
         
            self.mapPositionBinding = mapPosition
            
       
            if let location = lastLocation {
                updateMapPosition(with: location)
            }
        }
        
   
        locationManager.requestLocation()
    }
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
} 