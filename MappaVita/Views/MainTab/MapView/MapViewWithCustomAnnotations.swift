import SwiftUI
import MapKit

struct MapViewWithCustomAnnotations: UIViewRepresentable {
    @Binding var position: MapCameraPosition
    @Binding var selectedPlace: Place?
    @Binding var selectedMemory: Memory?
    var places: [Place]
    var showPhotoAnnotations: Bool
    
    // Create the MKMapView
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        return mapView
    }
    
    // Update the MKMapView
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update camera position
        if let mapCamera = position.camera {
            // Convert MapCamera to MKMapCamera
            let mkMapCamera = MKMapCamera(
                lookingAtCenter: mapCamera.centerCoordinate,
                fromDistance: mapCamera.distance,
                pitch: mapCamera.pitch,
                heading: mapCamera.heading
            )
            mapView.setCamera(mkMapCamera, animated: true)
        }
        
        // Update annotations
        updateAnnotations(mapView)
    }
    
    // Create the coordinator for MKMapViewDelegate methods
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Update annotations on the map
    private func updateAnnotations(_ mapView: MKMapView) {
        // Remove all existing annotations except user location
        mapView.annotations.forEach { annotation in
            if !(annotation is MKUserLocation) {
                mapView.removeAnnotation(annotation)
            }
        }
        
        // Print debug logs
        print("🔄 Updating map annotations with \(places.count) places")
        
        // Filter places to display based on showPhotoAnnotations
        let filteredPlaces: [Place]
        if showPhotoAnnotations {
            // Display all places
            filteredPlaces = places
        } else {
            // Display only places without photoAssetIdentifier (i.e., non-photo imported places)
            filteredPlaces = places.filter { $0.photoAssetIdentifier == nil }
        }
        
        // Add new annotations for places
        let placeAnnotations = filteredPlaces.map { place -> PlaceAnnotation in
            let annotation = PlaceAnnotation.fromPlace(place)
            print("📌 Created annotation for place: \(place.name), ID: \(place.id), Type: \(place.placeType ?? "place")")
            return annotation
        }
        
        mapView.addAnnotations(placeAnnotations)
    }
    
    // Coordinator class to handle MKMapViewDelegate methods
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWithCustomAnnotations
        
        init(_ parent: MapViewWithCustomAnnotations) {
            self.parent = parent
        }
        
        // Provide custom annotation views
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Return nil for user location annotation to use default blue dot
            if annotation is MKUserLocation {
                return nil
            }
            
            // Create custom annotation view for place annotations
            if let placeAnnotation = annotation as? PlaceAnnotation {
                let annotationType = placeAnnotation.type
                
           
                let isPhotoAnnotation = (annotationType == .photo || 
                                        (annotationType == .place && placeAnnotation.photoAssetIdentifier != nil))
                
                if isPhotoAnnotation {
                    // Photo annotation gets a photo view
                    let identifier = "PhotoAnnotation"
                    
                    // Dequeue an annotation view or create a new one
                    var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? PhotoAnnotationView
                    if annotationView == nil {
                        annotationView = PhotoAnnotationView(annotation: placeAnnotation, reuseIdentifier: identifier)
                    } else {
                        annotationView?.annotation = placeAnnotation
                    }
                    
                    // Configure the annotation view
                    annotationView?.canShowCallout = true
                    
                    // Load image if we have a photo asset identifier
                    annotationView?.loadImage(from: placeAnnotation.photoAssetIdentifier)
                    
                    // Add info button
                    annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
                    
                    return annotationView
                } else {
                    // Simple pin for location and regular places
                    let identifier = "PinAnnotation"
                    
                    // Dequeue an annotation view or create a new one
                    var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                    if annotationView == nil {
                        annotationView = MKMarkerAnnotationView(annotation: placeAnnotation, reuseIdentifier: identifier)
                    } else {
                        annotationView?.annotation = placeAnnotation
                    }
                    
                    // Configure the pin annotation view
                    annotationView?.canShowCallout = true
                    
                    // Set pin color based on type
                    if annotationType == .location {
                        annotationView?.markerTintColor = .blue
                        annotationView?.glyphImage = UIImage(systemName: "location.fill")
                    } else {
                        annotationView?.markerTintColor = .red
                    }
                    
                    // Add info button
                    annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
                    
                    return annotationView
                }
            }
            
            return nil
        }
        
        // Handle annotation callout accessory taps
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            print("👉 Info button tapped!")
            
            if let placeAnnotation = view.annotation as? PlaceAnnotation {
                print("🔍 PlaceAnnotation found: \(placeAnnotation.title ?? "Unknown")")
                print("🔑 Annotation ID: \(placeAnnotation.id)")
                print("📍 Coordinates: \(placeAnnotation.coordinate.latitude), \(placeAnnotation.coordinate.longitude)")
                
                // Try to find the corresponding Place through multiple methods
                let matchingPlace: Place?
                
                // 1. Exact match by ID
                if let place = parent.places.first(where: { place in place.id == placeAnnotation.id }) {
                    print("✅ Found matching Place by ID: \(place.name)")
                    matchingPlace = place
                }
                // 2. Match by coordinates and name
                else if let place = parent.places.first(where: { place in
                    place.name == placeAnnotation.title &&
                    abs(place.latitude - placeAnnotation.coordinate.latitude) < 0.0001 &&
                    abs(place.longitude - placeAnnotation.coordinate.longitude) < 0.0001
                }) {
                    print("✅ Found matching Place by coordinates and name: \(place.name)")
                    matchingPlace = place
                }
                // 3. Match by coordinates only (if very close)
                else if let place = parent.places.first(where: { place in
                    abs(place.latitude - placeAnnotation.coordinate.latitude) < 0.0001 &&
                    abs(place.longitude - placeAnnotation.coordinate.longitude) < 0.0001
                }) {
                    print("✅ Found matching Place by coordinates only: \(place.name)")
                    matchingPlace = place
                }
                // 4. Try to match by name (less reliable, but worth a try)
                else if let place = parent.places.first(where: { place in place.name == placeAnnotation.title }) {
                    print("✅ Found matching Place by name only: \(place.name)")
                    matchingPlace = place
                }
                else {
                    print("❌ Could not find matching Place")
                    matchingPlace = nil
                }
                
                // If a matching Place is found, send notification
                if let place = matchingPlace {
                    Task { @MainActor in
                        // Send a notification to show details
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SelectedPlaceChanged"),
                            object: place
                        )
                    }
                }
            }
        }
        
        // Handle annotation selection
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let placeAnnotation = view.annotation as? PlaceAnnotation {
                // Print detailed information
                print("Selected annotation: \(placeAnnotation.title ?? "Unknown") (ID: \(placeAnnotation.id), Type: \(placeAnnotation.type))")
                
                // Get the coordinate of the annotation
                let coordinate = placeAnnotation.coordinate
                
                // Create a new camera position and zoom in
                let camera = MKMapCamera(
                    lookingAtCenter: coordinate,
                    fromDistance: 1000, // 1000 meters, adjust as needed
                    pitch: 45, // 45 degrees tilt, adds 3D effect
                    heading: 0 // 0 degrees heading (north)
                )
                
                // Use animation to smoothly transition to the new location
                UIView.animate(withDuration: 0.5) {
                    mapView.setCamera(camera, animated: true)
                }
                
                // Try to find the corresponding Place through multiple methods
                let matchingPlace: Place?
                
                // 1. Exact match by ID
                if let place = parent.places.first(where: { place in place.id == placeAnnotation.id }) {
                    print("Found matching Place by ID: \(place.name)")
                    matchingPlace = place
                }
                // 2. Match by coordinates and name
                else if let place = parent.places.first(where: { place in
                    place.name == placeAnnotation.title &&
                    abs(place.latitude - placeAnnotation.coordinate.latitude) < 0.0001 &&
                    abs(place.longitude - placeAnnotation.coordinate.longitude) < 0.0001
                }) {
                    print("Found matching Place by coordinates and name: \(place.name)")
                    matchingPlace = place
                }
                // 3. Match by coordinates only (if very close)
                else if let place = parent.places.first(where: { place in
                    abs(place.latitude - placeAnnotation.coordinate.latitude) < 0.0001 &&
                    abs(place.longitude - placeAnnotation.coordinate.longitude) < 0.0001
                }) {
                    print("Found matching Place by coordinates only: \(place.name)")
                    matchingPlace = place
                }
                else {
                    print("Could not find matching Place")
                    matchingPlace = nil
                }
                
                // If a matching Place is found, send notification
                if let place = matchingPlace {
                    Task { @MainActor in
                        // Send a custom notification to indicate location change but don't show details
                        NotificationCenter.default.post(
                            name: NSNotification.Name("AnnotationSelected"),
                            object: place
                        )
                    }
                }
            }
        }
    }
} 