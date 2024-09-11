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

extension AUMORTBAppContent {
    internal func unwrap() -> PBMORTBAppContent {
        let appContent = PBMORTBAppContent()
        
        appContent.id = id
        
        appContent.episode = episode
        
        appContent.title = title
        
        appContent.series = series
        
        appContent.season = season
        
        appContent.artist = artist
        
        appContent.genre = genre
        
        appContent.album = album
        
        appContent.isrc = isrc
        
        if let producer = producer {
            appContent.producer = producer.unwrap()
        }
        
        appContent.url = url
        
        appContent.cat = cat
        
        appContent.prodq = prodq
        
        appContent.context = context
        
        appContent.contentrating = contentrating
        
        appContent.userrating = userrating
        
        appContent.qagmediarating = qagmediarating
        
        appContent.keywords = keywords
        
        appContent.livestream = livestream
        
        appContent.sourcerelationship = sourcerelationship
        
        appContent.len = len
        
        appContent.language = language
        
        appContent.embeddable = embeddable
        
        if let data = data {
            appContent.data = data.compactMap { $0.unwrap() }
        }
        
        if let ext = ext {
            appContent.ext = NSMutableDictionary(dictionary: ext)
        }

        return appContent
    }
    
    internal convenience init(_ content: PBMORTBAppContent?) {
        self.init()
        
        self.id = content?.id
        
        self.episode =  content?.episode
        
        self.title =  content?.title
        
        self.series =  content?.series
        
        self.season =  content?.season
        
        self.artist =  content?.artist
        
        self.genre =  content?.genre
        
        self.album =  content?.album
        
        self.isrc =  content?.isrc
        
        if let producer =  content?.producer {
            self.producer = AUMORTBContentProducer(producer)
        }
        
        self.url =  content?.url
        
        self.cat =  content?.cat
        
        self.prodq =  content?.prodq
        
        self.context =  content?.context
        
        self.contentrating =  content?.contentrating
        
        self.userrating =  content?.userrating
        
        self.qagmediarating =  content?.qagmediarating
        
        self.keywords =  content?.keywords
        
        self.livestream =  content?.livestream
        
        self.sourcerelationship =  content?.sourcerelationship
        
        self.len =  content?.len
        
        self.language =  content?.language
        
        self.embeddable =  content?.embeddable
        
        if let data = content?.data, !data.isEmpty {
            self.data =  data.compactMap { AUMORTBContentData($0) }
        }
        
        if let ext =  content?.ext {
            self.ext = ext as? [String: NSObject]
        }
    }
}
