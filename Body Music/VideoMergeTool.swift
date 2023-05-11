//
//  VideoMergeTool.swift
//  Body Music
//
//  Created by Carlo Aguilar on 13/04/21.
//

import AVFoundation

class VideoMergeTool {
    
    class func mergeAudioIntoVideo(videoUrl: URL,
                                   audioUrl: URL,
                                   completion: @escaping (_ error: Error?) -> Void) {
        
        let composition = AVMutableComposition()
        
        let videoAsset = AVAsset(url: videoUrl)
        let audioAsset = AVAsset(url: audioUrl)
        
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let videoAssetTrack: AVAssetTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first!
        let audioAssetTrack: AVAssetTrack = audioAsset.tracks(withMediaType: AVMediaType.audio).first!
        
        compositionVideoTrack!.preferredTransform = videoAssetTrack.preferredTransform
        
        do {
            try compositionVideoTrack!.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration), of: videoAssetTrack, at: CMTime.zero)
            try compositionAudioTrack!.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration), of: audioAssetTrack, at: CMTime.zero)
        } catch {
            print(error.localizedDescription)
        }
        
        let savePathUrl: URL = videoUrl
        do { // delete old video
            try FileManager.default.removeItem(at: savePathUrl)
        } catch {
            print(error.localizedDescription)
        }
        
        let assetExportSession: AVAssetExportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)!
        assetExportSession.outputFileType = AVFileType.mp4
        assetExportSession.outputURL = savePathUrl
        assetExportSession.shouldOptimizeForNetworkUse = true
        assetExportSession.exportAsynchronously { () -> Void in
            switch assetExportSession.status {
            case AVAssetExportSession.Status.completed:
                print("success")
                completion(nil)
            case AVAssetExportSession.Status.failed:
                print("failed \(assetExportSession.error?.localizedDescription ?? "error nil")")
                completion(assetExportSession.error)
            case AVAssetExportSession.Status.cancelled:
                print("cancelled \(assetExportSession.error?.localizedDescription ?? "error nil")")
                completion(assetExportSession.error)
            default:
                print("complete")
                completion(assetExportSession.error)
            }
        }
    }
}
