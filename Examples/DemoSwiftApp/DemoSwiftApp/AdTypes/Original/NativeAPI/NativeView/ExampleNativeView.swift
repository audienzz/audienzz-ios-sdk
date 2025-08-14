/*   Copyright 2018-2025 Audienzz.org, Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import AudienzziOSSDK
import UIKit

class ExampleNativeView: UIView {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var mainImageView: UIImageView!
    @IBOutlet private weak var bodyLabel: UILabel!
    @IBOutlet private weak var callToActionButton: UIButton!
    @IBOutlet private weak var sponsoredLabel: UILabel!

    public override func awakeFromNib() {
        super.awakeFromNib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func setupFromAd(ad: AUNativeAd) {
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

    private func download(
        _ urlString: String,
        completion: @escaping (UIImage?) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url) {
                DispatchQueue.main.async {
                    if let image = UIImage(data: data) {
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
