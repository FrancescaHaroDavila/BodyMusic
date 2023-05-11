//
//  VideoPreviewViewController.swift
//  Body Music
//
//  Created by Francesca Haro on 28/04/21.
//

import UIKit
import AVFoundation

protocol ARSceneViewControllerDelegate {
    func saveVideo(videoUrl: URL,  completion: @escaping (Bool) -> Void)
    func clearVideoRecorderCache()
}

class VideoPreviewViewController: UIViewController {
    
   
    let activityIndicator = UIActivityIndicatorView(style: .large)
    let fileManager = FileManager.default
    
    var videoUrl: URL!
    var songName: String!
    var temporaryFilePath: String?
    var playerLooper: AVPlayerLooper!
    var queuePlayer: AVQueuePlayer!
    var delegate: ARSceneViewControllerDelegate?
    
    @IBOutlet weak var videoPlayerView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoPlayer()
        setupActivityIndicator()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.clearVideoRecorderCache()
        if let temporaryFilePath = temporaryFilePath {
            try? fileManager.removeItem(atPath: temporaryFilePath)
        }
    }
    
    @IBAction func shareButtonTapped(_ sender: UIBarButtonItem) {
        shareVideo()
    }
    
    @IBAction func saveButtonTapped(_ sender: UIBarButtonItem) {
        showActivityIndicator()
        delegate?.saveVideo(videoUrl: videoUrl, completion: { saved in
            DispatchQueue.main.async {
                self.hideActivityIndicator()
                self.showVideoSavedAlert()
            }
        })
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIBarButtonItem) {
        dismiss(animated: true)
    }
    
    private func setupVideoPlayer() {
        let playerItem = AVPlayerItem(url: videoUrl)
        queuePlayer = AVQueuePlayer(playerItem: playerItem)
        playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
        let playerLayer = AVPlayerLayer(player: queuePlayer)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = videoPlayerView.bounds
        videoPlayerView.layer.addSublayer(playerLayer)
        queuePlayer.play()
    }
    
    private func shareVideo() {
        showActivityIndicator()
        DispatchQueue.global(qos: .background).async {
            if let urlData = NSData(contentsOf: self.videoUrl){
                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                let documentsDirectory = paths.first!
                self.temporaryFilePath = "\(documentsDirectory)/\(self.songName!) video.mp4"
                DispatchQueue.main.async {
                    urlData.write(toFile: self.temporaryFilePath!, atomically: true)

                    self.hideActivityIndicator()
                    
                    let activityVC = UIActivityViewController(activityItems: [NSURL(fileURLWithPath: self.temporaryFilePath!)], applicationActivities: nil)
                    activityVC.excludedActivityTypes = [.addToReadingList, .assignToContact]
                    self.present(activityVC, animated: true, completion: nil)
                }
            }
        }
    }
    
    private func showVideoSavedAlert(){
        let alert = UIAlertController(title: "Video saved", message: "The video has been saved in the Photos app", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { _ in
            self.dismiss(animated: true)
        }))
        self.present(alert, animated: true, completion: nil)
    }


    
    private func setupActivityIndicator(){
        activityIndicator.center = self.view.center
        activityIndicator.isHidden = true
        view.addSubview(activityIndicator)
    }
    
    private func showActivityIndicator() {
        activityIndicator.isHidden = false
        activityIndicator.layoutIfNeeded()
        activityIndicator.startAnimating()
    }
    
    private func hideActivityIndicator() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        activityIndicator.layoutIfNeeded()
    }

}

extension VideoPreviewViewController: UINavigationBarDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}
