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

import UIKit
import AudienzziOSSDK
import GoogleInteractiveMediaAds

fileprivate let videoContentURL = "https://storage.googleapis.com/gvabox/media/samples/stock.mp4"
fileprivate let storedImpVideo = "prebid-demo-video-interstitial-320-480-original-api"
fileprivate let gamAdUnitVideo = "/21808260008/prebid_demo_app_instream"

extension ExamplesViewController {
    func createInstreamView() {
        let videoParameters = AUVideoParameters(mimes: ["video/mp4"])
        videoParameters.protocols = [AUVideoProtocols(type: .VAST_2_0)]
        videoParameters.playbackMethod = [AUVideoPlaybackMethod(type: .AutoPlaySoundOff)]
        
        instreamView = AUInstreamView(configId: storedImpVideo, adSize: adSize, isLazyLoad: false)
        instreamView.frame = CGRect(origin: CGPoint(x: 0, y: getPositionY(adContainerView)), size: CGSize(width: 640, height: 480))
        instreamView.backgroundColor = .clear
        instreamView.parameters = videoParameters
        adContainerView.addSubview(instreamView)
        
        setupPlayerForInstreamExample()
        
        adsLoader = IMAAdsLoader(settings: nil)
        adsLoader.delegate = self
    }
    
    func setupPlayerForInstreamExample() {
        // Setup content player
        guard let contentURL = URL(string: videoContentURL) else {
            print("Please, use a valid URL for the content URL.")
            return
        }
        
        playButton = UIButton(frame: CGRect(x: 0, y: 0, width: 85, height: 125))
        playButton.setTitle("▶", for: .normal)
        playButton.titleLabel?.font = .systemFont(ofSize: 75)
        playButton.addTarget(self, action: #selector(onPlayButtonPressed), for: .touchUpInside)
        
        contentPlayer = AVPlayer(url: contentURL)
        
        // Create a player layer for the player.
        playerLayer = AVPlayerLayer(player: contentPlayer)
        
        // Size, position, and display the AVPlayer.
        playerLayer?.frame = instreamView.layer.bounds
        instreamView.layer.addSublayer(playerLayer!)
        
        // Set up our content playhead and contentComplete callback.
        if let contentPlayer = contentPlayer {
            contentPlayhead = IMAAVPlayerContentPlayhead(avPlayer: contentPlayer)
        }
        
        instreamView.addSubview(playButton)
        playButton.center = instreamView.center
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentDidFinishPlaying(_:)),
            name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
            object: contentPlayer?.currentItem)
    }
    
   @objc func onPlayButtonPressed(_ sender: AnyObject) {
        playButton.isHidden = true
        // Setup and load in-stream video
       
       instreamView.createAd(size: CGSize(width: 640, height: 480))
       
       instreamView.onLoadInstreamRequest = { [weak self] keywords in
           guard let self = self, let customKeywords = keywords else {
               self?.contentPlayer?.play()
               return
           }

           do {
               let adServerTag = try AUIMAUtils.shared.generateInstreamUriForGAM(adUnitID: gamAdUnitVideo,
                                                                                 adSlotSizes: [.Size640x480],
                                                                                 customKeywords: customKeywords)
               
               DispatchQueue.main.async {
                   let adDisplayContainer = IMAAdDisplayContainer(adContainer: self.instreamView, viewController: self)
                   let request = IMAAdsRequest(adTagUrl: adServerTag, adDisplayContainer: adDisplayContainer, contentPlayhead: nil, userContext: nil)
                   self.adsLoader.requestAds(with: request)
               }
           } catch {
               self.contentPlayer?.play()
           }
       }
    }
    
    @objc func contentDidFinishPlaying(_ notification: Notification) {
        // Make sure we don't call contentComplete as a result of an ad completing.
        if (notification.object as! AVPlayerItem) == contentPlayer?.currentItem {
            adsLoader.contentComplete()
        }
    }
}

extension ExamplesViewController: IMAAdsLoaderDelegate, IMAAdsManagerDelegate {
    // MARK: - IMAAdsLoaderDelegate
    
    func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
        // Grab the instance of the IMAAdsManager and set ourselves as the delegate.
        adsManager = adsLoadedData.adsManager
        adsManager?.delegate = self
        
        // Initialize the ads manager.
        adsManager?.initialize(with: nil)
    }
    
    func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
        print("IMA did fail with error: \(adErrorData.adError)")
        contentPlayer?.play()
    }
    
    // MARK: - IMAAdsManagerDelegate
    
    func adsManager(_ adsManager: IMAAdsManager, didReceive event: IMAAdEvent) {
        if event.type == IMAAdEventType.LOADED {
            // When the SDK notifies us that ads have been loaded, play them.
            adsManager.start()
        }
    }
    
    func adsManager(_ adsManager: IMAAdsManager, didReceive error: IMAAdError) {
        print("AdsManager error: \(error.message ?? "nil")")
        contentPlayer?.play()
    }
    
    func adsManagerDidRequestContentPause(_ adsManager: IMAAdsManager) {
        // The SDK is going to play ads, so pause the content.
        contentPlayer?.pause()
    }
    
    func adsManagerDidRequestContentResume(_ adsManager: IMAAdsManager) {
        // The SDK is done playing ads (at least for now), so resume the content.
        contentPlayer?.play()
    }
}
