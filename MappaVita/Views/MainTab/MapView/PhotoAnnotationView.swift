import SwiftUI
import MapKit
import Photos
import UIKit

// This annotation view will be used to display photos from the photo library
class PhotoAnnotationView: MKAnnotationView {
    private var imageView: UIImageView?
    private var photoManager = PhotoLocationManager.shared
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        // bubble
        canShowCallout = true
        isEnabled = true
        
        // Create a circular frame for the annotation
        frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        centerOffset = CGPoint(x: 0, y: -20)
        
        // Create an image view
        imageView = UIImageView(frame: bounds)
        imageView?.contentMode = .scaleAspectFill
        imageView?.clipsToBounds = true
        imageView?.layer.cornerRadius = bounds.width / 2
        imageView?.layer.borderWidth = 2
        imageView?.layer.borderColor = UIColor.white.cgColor
        
        if let imageView = imageView {
            addSubview(imageView)
        }
        
        // Set default image
        imageView?.image = UIImage(systemName: "photo")
        imageView?.tintColor = .red
        imageView?.backgroundColor = .white
        
        // Add info button
        rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
    }
    
    // Load the image from the photo library
    func loadImage(from assetIdentifier: String?) {
        guard let assetIdentifier = assetIdentifier else {
            return
        }
        
        // Fetch the asset using its identifier
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            return
        }
        
        // Request the image
        photoManager.getImage(from: asset, targetSize: CGSize(width: 100, height: 100)) { [weak self] image in
            DispatchQueue.main.async {
                self?.imageView?.image = image ?? UIImage(systemName: "photo")
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView?.image = UIImage(systemName: "photo")
    }
} 