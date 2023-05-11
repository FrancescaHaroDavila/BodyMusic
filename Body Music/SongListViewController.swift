//
//  SongListViewController.swift
//  Body Music
//
//  Created by Francesca Haro on 11/04/21.
//

import UIKit
import AudioKit
import SPPermissions
import AVFoundation
import Photos

class SongListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var songs: [Song] = [Song(name: "I Got What You Want", genre: "Pop", fileName: "IGotWhatYouWant.mp3"), Song(name: "Hype", genre: "Electronica", fileName: "Hype.mp3"), Song(name: "Someone New", genre: "Pop", fileName: "SomeoneNew.mp3")]
    
    private var cameraPermissionStatus: AVAuthorizationStatus {
        let cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        return cameraPermissionStatus
    }
    
    private var photoLibraryPermissionStatus: PHAuthorizationStatus {
        let photoLibraryPermissionStatus = PHPhotoLibrary.authorizationStatus()
        return photoLibraryPermissionStatus
    }
    
    var selectedSong: Song?
    
    @IBOutlet weak var songsTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.sizeToFit()
        navigationItem.title = "Songs"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        try? AKManager.stop()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if cameraPermissionStatus == .notDetermined || photoLibraryPermissionStatus == .notDetermined, cameraPermissionStatus != .denied, photoLibraryPermissionStatus != .denied {
            showPermissionsVC()
        }
    }
    @IBAction func instructionsTapped(_ sender: Any) {
        performSegue(withIdentifier: "showInstructions", sender: self)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        songs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let song = songs[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell")!
        cell.textLabel?.text = song.name
        cell.detailTextLabel?.text = song.genre
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedSong = songs[indexPath.row]
        if cameraPermissionStatus == .authorized && photoLibraryPermissionStatus == .authorized {
            performSegue(withIdentifier: "showARScene", sender: self)
        } else if cameraPermissionStatus == .denied || photoLibraryPermissionStatus == .denied {
            showPermissionDeniedAlert()
        } else {
            showPermissionsVC()
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destinationVC = segue.destination as? ARSceneViewController {
            destinationVC.song = selectedSong
        }
    }
    // Si el usuario no acepta los permisos de cámara, se le notificará que no podrá usar todas las funciones de la app
    private func showPermissionDeniedAlert() {
        let alertController = UIAlertController (title: "Permissions denied", message: "In order for the app to work properly, it needs certain permissions to be granted. If you want to continue, please go to Settings and grant the missing permissions", preferredStyle: .alert)

            let settingsAction = UIAlertAction(title: "Settings", style: .default) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }

                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        print("Settings opened: \(success)") // Prints true
                    })
                }
            }
            alertController.addAction(settingsAction)
            let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)
            alertController.addAction(cancelAction)

            present(alertController, animated: true, completion: nil)
    }
    
}

extension SongListViewController: SPPermissionsDelegate {
    
    func didAllow(permission: SPPermission) {
        if cameraPermissionStatus == .authorized && photoLibraryPermissionStatus == .authorized, let _ = selectedSong {
            performSegue(withIdentifier: "showARScene", sender: self)
        }
    }
    
    func showPermissionsVC() {
        let permissionsController = SPPermissions.dialog([.camera, .photoLibrary])
        permissionsController.titleText = "Need Permissions"
        permissionsController.headerText = "Permissions request"
        permissionsController.footerText = "These permissions are needed for recording videos and saving them to the photo library."
        permissionsController.delegate = self
        permissionsController.present(on: self)
    }
}
