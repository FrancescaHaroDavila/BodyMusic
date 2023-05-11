//
//  ARSceneViewController.swift
//  Body Music
//
//  Created by Francesca Haro on 28/03/21.
//

import UIKit
import ARKit
import SceneKit
import AudioKit
import ARVideoKit

class ARSceneViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, RecordButtonDelegate {
    
    let standardVolume = 0.4
    let maximumKneeAngle = 160.0
    let minimumKneeAngle = 40.0
    let minimumArmVolumeAngle = 90.0
    let minimumArmSoundActivationAngle = 110.0
    let minimumArmSoundDeactivationAngle = 95.0
    let maximumArmAngle = 135.0
    let minimumLegActivationAngle = 120.0
    let minimumLegDeactivationAngle = 95.0
    let minimumHeadAngle = 60.0
    let headDeactivationAngle = 90.0
    
    let standardPlaybackSpeed = 1.0
    let minimumPlaybackSpeed = 0.8
    let videoResolution = CGSize(width: 1920, height: 1080)
    
    let maximumRecordingTime = 60.0
    
    let session = ARSession()
    let activityIndicator = UIActivityIndicatorView(style: .large)
    let processingAlert = UIAlertController(title: "Processing", message: "Processing video and audio", preferredStyle: UIAlertController.Style.alert)
    
    var updateTimeTimer: Timer?
    var maximumTimeTimer: Timer?
    
    var activatedLeftArmSound = false
    var activatedRightArmSound = false
    var activatedLeftLegSound = false
    var activatedLeftHeadSound = false
    var activatedRightHeadSound = false
    var activatedRightLegSound = false
    var sessionConfig: ARConfiguration = ARBodyTrackingConfiguration()
    var song: Song!
    var didAppearForFirstTime = false
    var totalSeconds = 0
    lazy var videoRecorder = RecordAR(ARSceneKit: sceneView)
    lazy var audioRecorder = try! AKNodeRecorder(node: AKManager.output)
    lazy var songFile = try! AKAudioFile(readFileName: song.fileName, baseDir: .resources)
    lazy var songAudioPlayer = try! AKAudioPlayer(file: songFile)
    lazy var midDrumAudioFile = try! AKAudioFile(readFileName: "mid-drum.mp3", baseDir: .resources)
    lazy var lowDrumAudioFile = try! AKAudioFile(readFileName: "low-drum.mp3", baseDir: .resources)
    lazy var headSound1AudioFile = try! AKAudioFile(readFileName: "EggShakerHead.mp3", baseDir: .resources)
    lazy var bassDrumAudioFile = try! AKAudioFile(readFileName: "BassDrum.mp3", baseDir: .resources)
    lazy var headSound2AudioFile = try! AKAudioFile(readFileName: "DrumSticksHead.mp3", baseDir: .resources)
    lazy var percussionHitAudioFile = try! AKAudioFile(readFileName: "PercussionHit.mp3", baseDir: .resources)
    lazy var leftLegAudioPlayer = try! AKAudioPlayer(file: midDrumAudioFile)
    lazy var rightLegAudioPlayer = try! AKAudioPlayer(file: lowDrumAudioFile)
    lazy var leftHeadAudioPlayer = try! AKAudioPlayer(file: headSound1AudioFile)
    lazy var rightHeadAudioPlayer = try! AKAudioPlayer(file: headSound2AudioFile)
    lazy var leftArmAudioPlayer = try! AKAudioPlayer(file: bassDrumAudioFile)
    lazy var rightArmAudioPlayer = try! AKAudioPlayer(file: percussionHitAudioFile)
    lazy var songPlayerVariSpeed = AKVariSpeed(songAudioPlayer)
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var recordButton: RecordButton!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var timeLabelContainerView: UIView!
    @IBOutlet weak var maximumTimeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        hideViewfinder()
        setupActivityIndicator()
        showActivityIndicator()
        setupScene()
        navigationItem.title = song.name
        recordButton.delegate = self
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        restartPlaneDetection()
        hideTimer()
        enableRecordButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didAppearForFirstTime {
            setupAudio()
            didAppearForFirstTime = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        sceneView.session.pause()
    }
    
    @objc func appMovedToBackground() {
        stopTimer()
        stopAudioPlayers()
        audioRecorder.stop()
        videoRecorder?.stop()
        navigationItem.hidesBackButton = false
        navigationController?.popViewController(animated: false)
    }
    
    private func showVideoPreview(videoUrl: URL) {
        if let videoPreviewViewController = storyboard?.instantiateViewController(identifier: "VideoPreviewViewController") as? VideoPreviewViewController {
            videoPreviewViewController.videoUrl = videoUrl
            videoPreviewViewController.delegate = self
            videoPreviewViewController.songName = song.name
            videoPreviewViewController.modalPresentationStyle = .fullScreen
            videoPreviewViewController.modalTransitionStyle = .coverVertical
            present(videoPreviewViewController, animated: true)
        }
    }
    
    @objc func updateTimer() {
        totalSeconds += 1
        let minutes = totalSeconds / 60
        let seconds = totalSeconds - (minutes * 60)
        let timeString = String(format:"%02i:%02i", minutes, seconds)
        timeLabel.text = timeString
        timeLabel.layoutIfNeeded()
    }
    
    private func startTimer() {
        timeLabelContainerView.isHidden = false
        timeLabel.text = "00:00"
        timeLabelContainerView.layoutIfNeeded()
        maximumTimeLabel.isHidden = false
        maximumTimeLabel.layoutIfNeeded()
        updateTimeTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }
    
    private func stopTimer() {
        updateTimeTimer?.invalidate()
        updateTimeTimer = nil
        totalSeconds = 0
    }
    
    private func automaticallyEndRecordingAfterMaxTime() {
        maximumTimeTimer = Timer.scheduledTimer(withTimeInterval: maximumRecordingTime, repeats: false) { _ in
            self.recordButton.endRecording()
            self.recordButton.delegate?.tapButton(isRecording: false)
        }
    }
    
    private func hideTimer() {
        timeLabelContainerView.isHidden = true
        timeLabelContainerView.layoutIfNeeded()
        maximumTimeLabel.isHidden = true
        maximumTimeLabel.layoutIfNeeded()
    }
    
    private func enableRecordButton() {
        recordButton.isUserInteractionEnabled = true
    }
    
    private func disableRecordButton() {
        recordButton.isUserInteractionEnabled = false
    }
    
    func tapButton(isRecording: Bool) {
        if isRecording {
            songAudioPlayer.start()
            videoRecorder?.record()
            try! audioRecorder.record()
            navigationItem.hidesBackButton = true
            startTimer()
            automaticallyEndRecordingAfterMaxTime()
        } else {
            stopTimer()
            maximumTimeTimer?.invalidate()
            disableRecordButton()
            navigationItem.hidesBackButton = false
            audioRecorder.stop()
            present(processingAlert, animated: true, completion: nil)
            let recordedAudio = self.audioRecorder.audioFile!
            videoRecorder?.stop({ [weak self] (videoUrl) in
                VideoMergeTool.mergeAudioIntoVideo(videoUrl: videoUrl, audioUrl: recordedAudio.url) { (error) in
                    try? self?.audioRecorder.reset()
                    if error == nil {
                        DispatchQueue.main.async {
                            self?.processingAlert.dismiss(animated: true, completion: {
                                self?.showVideoPreview(videoUrl: videoUrl)
                            })
                        }
                    }
                }
            })
            stopAudioPlayers()
        }
    }
    
    private func restartPlaneDetection() {
        if let worldSessionConfig = sessionConfig as? ARBodyTrackingConfiguration {
            worldSessionConfig.planeDetection = .horizontal
            session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        }
    }
    
    private func stopAudioPlayers(){
        songAudioPlayer.stop()
        rightLegAudioPlayer.stop()
        leftLegAudioPlayer.stop()
        leftArmAudioPlayer.stop()
        rightArmAudioPlayer.stop()
        leftHeadAudioPlayer.stop()
        rightHeadAudioPlayer.stop()
    }
    
    private func setupAudio() {
        songPlayerVariSpeed.rate = standardPlaybackSpeed
        let mixer = AKMixer(songPlayerVariSpeed, leftLegAudioPlayer, rightLegAudioPlayer, leftArmAudioPlayer, rightArmAudioPlayer, leftHeadAudioPlayer, rightHeadAudioPlayer)
        AKManager.output = mixer
        songAudioPlayer.volume = standardVolume
        leftLegAudioPlayer.volume = standardVolume
        rightLegAudioPlayer.volume = standardVolume
        leftArmAudioPlayer.volume = standardVolume
        rightArmAudioPlayer.volume = standardVolume
        leftHeadAudioPlayer.volume = standardVolume
        rightHeadAudioPlayer.volume = standardVolume
        songAudioPlayer.looping = true
        try! AKManager.start()
        hideActivityIndicator()
        showViewfinder()
    }
    
    private func setupScene() {
        sceneView.session = session
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.antialiasingMode = .multisampling4X
        sceneView.automaticallyUpdatesLighting = false
        sceneView.preferredFramesPerSecond = 60
        sceneView.contentScaleFactor = 1.3
        if let videoFormat = ARBodyTrackingConfiguration.supportedVideoFormats.first(where: {$0.imageResolution == videoResolution}) {
            sessionConfig.videoFormat = videoFormat
        }
        sessionConfig.isLightEstimationEnabled = false
        session.run(sessionConfig)
        videoRecorder?.prepare(sessionConfig)
        videoRecorder?.enableAudio = false
    }
    
    private func addMusicNotes() {
        let musicNode1 = EmojiNode(with: ["🎵"])
        sceneView.scene.rootNode.addChildNode(musicNode1)
        
        
        let randomX = Float.random(in: (-0.5)...(0.5))
        let randomY = Float.random(in: (-0.5)...(0.5))
        
        let rotateActionXY = SCNAction.repeatForever(SCNAction.rotate(by: 2 * .pi, around: SCNVector3(1, 1, 0), duration: 1.5))
        let rotateActionZ = SCNAction.repeatForever(SCNAction.rotate(by: 2 * .pi, around: SCNVector3(0, 0, 1), duration: 3))
        musicNode1.runAction(rotateActionXY)
        musicNode1.runAction(rotateActionZ)
        
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 8
        musicNode1.opacity = 0
        musicNode1.position.x = (musicNode1.position.x + randomX)
        musicNode1.position.y = (musicNode1.position.y + randomY)
        musicNode1.position.z = (musicNode1.position.z + 1)
        SCNTransaction.completionBlock = {
            musicNode1.removeFromParentNode()
        }
        SCNTransaction.commit()
    }
    
    //lista de articulaciones reconocidas por la app
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard songAudioPlayer.isPlaying else { return }
        
        if let person: ARBody2D = frame.detectedBody {
            let skeleton = person.skeleton
            let head = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "head_joint"))!
            let neck = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "neck_1_joint"))!
            let rightForearm = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "right_forearm_joint"))!
            let leftForearm = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "left_forearm_joint"))!
            let rightShoulder = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "right_shoulder_1_joint"))!
            let leftShoulder = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "left_shoulder_1_joint"))!
            let rightUpLeg = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "right_upLeg_joint"))!
            let leftUpLeg = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "left_upLeg_joint"))!
            let leftLeg = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "left_leg_joint"))!
            let rightLeg = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "right_leg_joint"))!
            let leftFoot = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "left_foot_joint"))!
            let rightFoot = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "right_foot_joint"))!
            let hip = skeleton.landmark(for: ARSkeleton.JointName(rawValue: "root"))!
            
            if let leftHeadAngle = angleBetweenThreePoints(a: leftShoulder, b: neck, c: head) {
                handleLeftHeadAngle(angle: abs(leftHeadAngle))
            }
            if let rightHeadAngle = angleBetweenThreePoints(a: rightShoulder, b: neck, c: head) {
                handleRightHeadAngle(angle: abs(rightHeadAngle))
            }
            
            if let leftKneeAngle = angleBetweenThreePoints(a: leftUpLeg, b: leftLeg, c: leftFoot),  let rightKneeAngle = angleBetweenThreePoints(a: rightUpLeg, b: rightLeg, c: rightFoot) {
                let averageKneeAngle = (abs(leftKneeAngle) + abs(rightKneeAngle)) / 2
                setSpeedForKneesAngle(kneesAngle: averageKneeAngle)
                
                if averageKneeAngle >= maximumKneeAngle, let leftLegAngle = angleBetweenThreePoints(a: leftLeg, b: leftUpLeg, c: hip), let rightLegAngle = angleBetweenThreePoints(a: hip, b: rightUpLeg, c: rightLeg) {
                    handleLeftLegAngle(angle: abs(leftLegAngle))
                    handleRightLegAngle(angle: abs(rightLegAngle))
                }
            }
            
            if let rightArmAngle = angleBetweenThreePoints(a: rightForearm, b: rightShoulder, c: rightUpLeg),  let leftArmAngle = angleBetweenThreePoints(a: leftForearm, b: leftShoulder, c: leftUpLeg) {
                if abs(rightArmAngle) > minimumArmVolumeAngle, abs(leftArmAngle) > minimumArmVolumeAngle {
                    let averageArmAngle = (abs(rightArmAngle) + abs(leftArmAngle)) / 2
                    setVolumeForArmsAngle(armsAngle: averageArmAngle)
                } else {
                    handleLeftArmAngle(angle: abs(leftArmAngle))
                    handleRightArmAngle(angle: abs(rightArmAngle))
                }
            }
        } else {
            setSpeed(speed: standardPlaybackSpeed)
            songAudioPlayer.volume = standardVolume
        }
    }
    
    //Funciones para detectar cada ángulo
    private func handleLeftArmAngle(angle: Double) {
        if angle >= minimumArmSoundActivationAngle, !activatedLeftArmSound {
            activatedLeftArmSound = true
            leftArmAudioPlayer.start()
            addMusicNotes()
        } else if angle <= minimumArmSoundDeactivationAngle, activatedLeftArmSound {
            leftArmAudioPlayer.stop()
            activatedLeftArmSound = false
        }
    }
    
    private func handleRightArmAngle(angle: Double) {
        if angle >= minimumArmSoundActivationAngle, !activatedRightArmSound {
            activatedRightArmSound = true
            rightArmAudioPlayer.start()
            addMusicNotes()
        } else if angle <= minimumArmSoundDeactivationAngle, activatedRightArmSound {
            rightArmAudioPlayer.stop()
            activatedRightArmSound = false
        }
    }
    
    private func setVolumeForArmsAngle(armsAngle: Double) {
        let volume: Double
        if armsAngle >= maximumArmAngle {
            volume = 1
        } else if armsAngle > minimumArmVolumeAngle {
            volume = standardVolume + ((armsAngle-minimumArmVolumeAngle)/(maximumArmAngle-minimumArmVolumeAngle)) * (1-standardVolume)
            
        } else {
            volume = standardVolume
        }
        songAudioPlayer.volume = volume
        leftLegAudioPlayer.volume = volume
        rightLegAudioPlayer.volume = volume
        leftArmAudioPlayer.volume = volume
        rightArmAudioPlayer.volume = volume
        leftHeadAudioPlayer.volume = volume
        rightHeadAudioPlayer.volume = volume
    }
    
    private func handleLeftLegAngle(angle: Double) {
        if angle >= minimumLegActivationAngle, !activatedLeftLegSound, !activatedRightLegSound {
            activatedLeftLegSound = true
            leftLegAudioPlayer.start()
            addMusicNotes()
        } else if angle <= minimumLegDeactivationAngle, activatedLeftLegSound {
            leftLegAudioPlayer.stop()
            activatedLeftLegSound = false
        }
    }
    
    private func handleRightLegAngle(angle: Double) {
        if angle >= minimumLegActivationAngle, !activatedRightLegSound, !activatedLeftLegSound {
            activatedRightLegSound = true
            rightLegAudioPlayer.start()
            addMusicNotes()
        } else if angle <= minimumLegDeactivationAngle, activatedRightLegSound {
            rightLegAudioPlayer.stop()
            activatedRightLegSound = false
        }
    }
    
    private func handleLeftHeadAngle(angle: Double) {
        if angle <= minimumHeadAngle, !activatedLeftHeadSound {
            activatedLeftHeadSound = true
            leftHeadAudioPlayer.start()
            addMusicNotes()
        } else if angle > headDeactivationAngle, activatedLeftHeadSound {
            leftHeadAudioPlayer.stop()
            activatedLeftHeadSound = false
        }
    }
    
    private func handleRightHeadAngle(angle: Double) {
        if angle <= minimumHeadAngle, !activatedRightHeadSound {
            activatedRightHeadSound = true
            rightHeadAudioPlayer.start()
            addMusicNotes()
        } else if angle > headDeactivationAngle, activatedRightHeadSound {
            rightHeadAudioPlayer.stop()
            activatedRightHeadSound = false
        }
    }
    
    private func setSpeedForKneesAngle(kneesAngle: Double) {
        var speed: Double
        if kneesAngle >= maximumKneeAngle {
            speed = standardPlaybackSpeed
        } else if kneesAngle > minimumKneeAngle {
            speed = minimumPlaybackSpeed + ((kneesAngle-minimumKneeAngle)/(maximumKneeAngle - minimumKneeAngle)) * (standardPlaybackSpeed - minimumPlaybackSpeed)
        } else {
            speed = minimumPlaybackSpeed
        }
        setSpeed(speed: speed)
    }
    
    private func positiveAngleBetweenThreePoints(a: simd_float2, b: simd_float2, c: simd_float2) -> Double? {
        guard a.hasValidNumbers, b.hasValidNumbers, c.hasValidNumbers else {
            return nil
        }
        let angle_ab = atan2(a.y - b.y, abs(a.x - b.x))
        let angle_cb = atan2(c.y - b.y, abs(c.x - b.x))
        let angle_abc = angle_ab - angle_cb
        return Double(angle_abc) * 180 / Double.pi
    }
    
    private func angleBetweenThreePoints(a: simd_float2, b: simd_float2, c: simd_float2) -> Double? {
        guard a.hasValidNumbers, b.hasValidNumbers, c.hasValidNumbers else {
            return nil
        }
        let angle_ab = atan2(a.y - b.y, a.x - b.x)
        let angle_cb = atan2(c.y - b.y, c.x - b.x)
        let angle_abc = angle_ab - angle_cb
        return Double(angle_abc) * 180 / Double.pi
    }
    
    private func angleBetweenVectors(a: SCNVector3, b: SCNVector3) -> SCNFloat {
        
        //cos(angle) = (A.B)/(|A||B|)
        let cosineAngleInRadians = (a.dotProduct(b) / (a.magnitude * b.magnitude))
        let arcCosineAngleInRadians = acos(cosineAngleInRadians)
        let arcCosineAngleInDegrees = arcCosineAngleInRadians * 180 / Float.pi
        return SCNFloat(arcCosineAngleInDegrees)
    }
    
    private func setSpeed(speed: Double) {
        songPlayerVariSpeed.rate = speed
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
    
    private func hideViewfinder() {
        sceneView.isHidden = true
        sceneView.alpha = 0
        recordButton.isHidden = true
        recordButton.alpha = 0
    }
    
    private func showViewfinder() {
        UIView.animate(withDuration: 0.7) {
            self.sceneView.isHidden = false
            self.sceneView.alpha = 1
            self.recordButton.isHidden = false
            self.recordButton.alpha = 1
        }
    }
    
    private func showProcessingAlert(){
        self.present(processingAlert, animated: true, completion: nil)
    }
}

extension ARSceneViewController: ARSceneViewControllerDelegate {
    func saveVideo(videoUrl: URL,  completion: @escaping (Bool) -> Void) {
        videoRecorder?.export(video: videoUrl, { saved, _ in
            completion(saved)
        })
    }
    
    func clearVideoRecorderCache() {
        videoRecorder?.cancel()
    }
}

extension ARSceneViewController: UINavigationBarDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

