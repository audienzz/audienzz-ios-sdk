//
//  ExampleNativeView.swift
//  DemoSwiftApp
//
//  Created by Konstantin Vasyliev on 04.04.2024.
//

import UIKit
import AudienzziOSSDK

class ExampleNativeView: UIView {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var mainImageView: UIImageView!
    @IBOutlet private weak var bodyLabel: UILabel!
    @IBOutlet weak var callToActionButton: UIButton!
    @IBOutlet private weak var sponsoredLabel: UILabel!
    
    public override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func setupFromAd(ad: NativeAd) {
        if let iconString = ad.iconUrl {
            download(iconString) { result in
                if case let icon = result {
                    DispatchQueue.main.async {
                        self.iconView.image = icon
                    }
                }
            }
        }
        
        if let imageString = ad.imageUrl {
            download(imageString) { result in
                if case let image = result {
                    DispatchQueue.main.async {
                        self.mainImageView.image = image
                    }
                }
            }
        }
        
        DispatchQueue.main.async {
            self.titleLabel.text = ad.title
            self.bodyLabel.text = ad.text
            self.callToActionButton.setTitle(ad.callToAction, for: .normal)
            self.sponsoredLabel.text = ad.sponsoredBy
        }
        
        ad.registerView(view: self, clickableViews: [callToActionButton])
    }
    
    private func download(_ urlString: String, completion: @escaping(UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url) {
                DispatchQueue.main.async {
                    if let image = UIImage(data:data) {
                        completion(image)
                    } else {
                        completion(nil)
                    }
                }
            } else {
                return completion(nil)
            }
        }
    }
}
