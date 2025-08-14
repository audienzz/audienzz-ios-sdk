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

import Foundation
import UIKit

struct ScreenImpressionModel {
    let name: String
    let hash: Int
    let nibName: String?
}

class AUScreenImpressionManager: NSObject {
    var screenMapper: [ScreenImpressionModel] = []
    
    func shouldAddEvent(of adView: AUAdView) -> (Bool, String?) {
        guard let vc = adView.parentViewController else {
            return (false, nil)
        }

        let name = String(describing: type(of: vc))
        let nibName = vc.nibName
        let hash = vc.hash
        AULogEvent.logDebug(name)
        
        let model = ScreenImpressionModel(name: name, hash: hash, nibName: nibName)
        
        let isModelAvailable = checkModel(model)
        AULogEvent.logDebug("model available: \(isModelAvailable)")
        
        if !isModelAvailable {
            appendModel(model)
        }
        
        return (!isModelAvailable, model.name)
    }
    
    private func checkModel(_ model: ScreenImpressionModel) -> Bool {
        screenMapper.contains(where: { $0.hash == model.hash })
    }
    
    private func appendModel(_ model: ScreenImpressionModel) {
        screenMapper.append(model)
    }
}
