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

public class AdVideoParameters: NSObject {
    /**
    # OpenRTB - Protocols #
    ```
    | Value | Description       |
    |-------|-------------------|
    | 1     | VAST 1.0          |
    | 2     | VAST 2.0          |
    | 3     | VAST 3.0          |
    | 4     | VAST 1.0 Wrapper  |
    | 5     | VAST 2.0 Wrapper  |
    | 6     | VAST 3.0 Wrapper  |
    | 7     | VAST 4.0          |
    | 8     | VAST 4.0 Wrapper  |
    | 9     | DAAST 1.0         |
    | 10    | DAAST 1.0 Wrapper |
    ```
    */
    public enum Protocols: Int {
        case VAST_1_0          = 1
        case VAST_2_0          = 2
        case VAST_3_0          = 3
        case VAST_1_0_Wrapped  = 4
        case VAST_2_0_Wrapped  = 5
        case VAST_3_0_Wrapped  = 6
        case VAST_4_0          = 7
        case VAST_4_0_Wrapped  = 8
        case DAAST_1_0         = 9
        case DAAST_1_0_Wrapped = 10
        
        internal var toProtocol: Signals.Protocols {
            Signals.Protocols(integerLiteral: self.rawValue)
        }
    }
    
    /**
    # OpenRTB - Playback Methods #
    ```
    | Value | Description                                              |
    |-------|----------------------------------------------------------|
    | 1     | Initiates on Page Load with Sound On                     |
    | 2     | Initiates on Page Load with Sound Off by Default         |
    | 3     | Initiates on Click with Sound On                         |
    | 4     | Initiates on Mouse-Over with Sound On                    |
    | 5     | Initiates on Entering Viewport with Sound On             |
    | 6     | Initiates on Entering Viewport with Sound Off by Default |
    ```
    */
    public enum PlaybackMethod: Int {
        case AutoPlaySoundOn  = 1
        case AutoPlaySoundOff = 2
        case ClickToPlay      = 3
        case MouseOver        = 4
        case EnterSoundOn     = 5
        case EnterSoundOff    = 6
        
        internal var toPlaybackMethod: Signals.PlaybackMethod? {
            Signals.PlaybackMethod(integerLiteral: self.rawValue)
        }
    }
    
    /**
     # OpenRTB - API Frameworks #
     ```
     | Value | Description |
     |-------|-------------|
     | 1     | VPAID 1.0   |
     | 2     | VPAID 2.0   |
     | 3     | MRAID-1     |
     | 4     | ORMMA       |
     | 5     | MRAID-2     |
     | 6     | MRAID-3     |
     | 7     | OMID-1      |
     ```
     */
    
    public enum Api: Int {
        case VPAID_1 = 1
        case VPAID_2 = 2
        case MRAID_1 = 3
        case ORMMA   = 4
        case MRAID_2 = 5
        case MRAID_3 = 6
        case OMID_1 = 7
        
        internal var toAPI: Signals.Api {
            Signals.Api(integerLiteral: self.rawValue)
        }
    }
    
    /**
    # OpenRTB - Start Delay #
    ```
    | Value | Description                                      |
    |-------|--------------------------------------------------|
    | > 0   | Mid-Roll (value indicates start delay in second) |
    | 0     | Pre-Roll                                         |
    | -1    | Generic Mid-Roll                                 |
    | -2    | Generic Post-Roll                                |
    ```
    */
    public enum StartDelay: Int {
        case PreRoll         = 0
        case GenericMidRoll  = -1
        case GenericPostRoll = -2
        
        internal var toStartDelay: Signals.StartDelay {
            Signals.StartDelay(integerLiteral: self.rawValue)
        }
    }
    
    /**
    # OpenRTB - Video Placement Types #
    ```
    | Value | Description                  |
    |-------|------------------------------|
    | 1     | In-Stream                    |
    | 2     | In-Banner                    |
    | 3     | In-Article                   |
    | 4     | In-Feed                      |
    | 5     | Interstitial/Slider/Floating |
    ```
    */
    
    public enum Placement: Int {
        case InStream
        case InBanner
        case InArticle
        case InFeed
        case Interstitial
        
        internal var toPlacement: Signals.Placement {
            Signals.Placement(integerLiteral: self.rawValue)
        }
    }
}
