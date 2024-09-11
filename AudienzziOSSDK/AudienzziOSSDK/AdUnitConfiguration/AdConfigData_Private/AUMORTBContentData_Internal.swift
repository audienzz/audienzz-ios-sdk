/*   Copyright 2018-2024 Audienzz.org, Inc.
 
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
import PrebidMobile

extension AUMORTBContentData {
    internal func unwrap() -> PBMORTBContentData {
        let contentData = PBMORTBContentData()
        
        contentData.id = id

        contentData.name = name

        if let segment = segment {
            contentData.segment = segment.compactMap { $0.unwrapSegment() }
        }

        if let ext = ext {
            contentData.ext = NSMutableDictionary(dictionary: ext)
        }
        
        return contentData
    }
    
    internal convenience init(_ contentData: PBMORTBContentData?) {
        self.init()
        
        self.id = contentData?.id

        self.name = contentData?.name

        if let segment = contentData?.segment, !segment.isEmpty {
            self.segment = segment.compactMap { AUMORTBContentSegment($0) }
        }

        if let ext = contentData?.ext {
            self.ext = ext as? [String: NSObject]
        }
    }
}

extension AUMORTBContentSegment {
    internal func unwrapSegment() -> PBMORTBContentSegment {
        let segment = PBMORTBContentSegment()
        
        segment.id = id

        segment.name = name

        segment.value = value

        if let ext = ext {
            segment.ext = NSMutableDictionary(dictionary: ext)
        }
        
        return segment
    }
    
    internal convenience init(_ segment: PBMORTBContentSegment?) {
        self.init()
        
        self.id = segment?.id

        self.name = segment?.name

        self.value = segment?.value

        if let ext = segment?.ext {
            self.ext = ext as? [String: NSObject]
        }
    }
}

extension AUMORTBContentProducer {
    internal func unwrap() -> PBMORTBContentProducer {
        let producer = PBMORTBContentProducer()
        
        producer.id = id

        producer.name = name

        producer.cat = cat?.compactMap { $0 }

        if let ext = ext {
            producer.ext = NSMutableDictionary(dictionary: ext)
        }
        
        return producer
    }
    
    internal convenience init(_ producer: PBMORTBContentProducer?) {
        self.init()
        
        self.id = producer?.id

        self.name = producer?.name

        self.cat = producer?.cat?.compactMap { $0 }

        if let ext = producer?.ext {
            self.ext = ext as? [String: NSObject]
        }
    }
}
