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

/// Describes an [OpenRTB](https://www.iab.com/wp-content/uploads/2016/03/OpenRTB-API-Specification-Version-2-5-FINAL.pdf) app: content object

@objcMembers
public class AUMORTBAppContent: NSObject {
    /// ID uniquely identifying the content.
    public var id: String?
    /// Episode number.
    public var episode: NSNumber?
    /// Content title.
    public var title: String?
    /// Content series.
    public var series: String?
    /// Content season.
    public var season: String?
    /// Artist credited with the content.
    public var artist: String?
    /// Genre that best describes the content.
    public var genre: String?
    /// Album to which the content belongs; typically for audio.
    public var album: String?
    /// International Standard Recording Code conforming to ISO- 3901.
    public var isrc: String?
    /// This object defines the producer of the content in which the ad will be shown.
    public var producer: AUMORTBContentProducer?
    /// URL of the content, for buy-side contextualization or review.
    public var url: String?
    /// Array of IAB content categories that describe the content producer.
    public var cat: [String]?
    /// Production quality.
    public var prodq: NSNumber?
    /// Type of content (game, video, text, etc.).
    public var context: NSNumber?
    /// Content rating.
    public var contentrating: String?
    /// User rating of the content.
    public var userrating: String?
    /// Media rating per IQG guidelines.
    public var qagmediarating: NSNumber?
    /// Comma separated list of keywords describing the content.
    public var keywords: String?
    /// 0 = not live, 1 = content is live.
    public var livestream: NSNumber?
    /// 0 = indirect, 1 = direct.
    public var sourcerelationship: NSNumber?
    /// Length of content in seconds; appropriate for video or audio.
    public var len: NSNumber?
    /// Content language using ISO-639-1-alpha-2.
    public var language: String?
    /// Indicator of whether or not the content is embeddable (e.g., an embeddable video player), where 0 = no, 1 = yes.
    public var embeddable: NSNumber?
    /// The data and segment objects together allow additional data about the related object (e.g., user, content) to be specified.
    public var data: [AUMORTBContentData]?
    /// Placeholder for exchange-specific extensions to OpenRTB.
    public var ext: [String: NSObject]?
}
