import UIKit
import Photos
import AVFoundation

class View_Final_Picker: UIViewController {
    
    @IBOutlet weak var view_preview_camera: UIView!
    @IBOutlet weak var view_button_camera: UIView!
    @IBOutlet weak var view_switch_camera: UIView!
    @IBOutlet weak var view_button_capture: UIView!
    
    @IBOutlet weak var img_btn_flash: UIImageView!
    @IBOutlet weak var img_icon_switch_camera_video: UIImageView!
    @IBOutlet weak var img_switch_back_front_camera: UIImageView!
    @IBOutlet weak var lbl_video_time: UILabel!
    
    //Variables de permisos
    var is_view_finish_load = false
    var permission_camara   = false
    var permission_microfono = false
    var flashMode = AVCaptureDevice.FlashMode.on
    
    //Video y camara raiz
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    //Camaras y Dispositivos
    var camera_front: AVCaptureDevice?
    var camera_rear:  AVCaptureDevice?
    var audio_device: AVCaptureDevice?

    //Variables de camara
    var camara_position: CameraPosition?
    
    //Dispositivos de entrada
    var front_camera_input: AVCaptureDeviceInput?
    var rear_camera_input: AVCaptureDeviceInput?
    
    //Salida
    var videoFileOutput: AVCaptureMovieFileOutput?
    var photoOutput: AVCapturePhotoOutput?
    var photo_capture_completion_block: ((UIImage?, Error?) ->Void)?
    
    //Variables de uso flotante
    var timer_up_video: Timer?
    var segundos_transcurridos = 0
    let zoom_minValue: CGFloat = 1.0
    let zoom_maxValue: CGFloat = 10.0
    var zoom_lastFactor: CGFloat = 1.0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.config_buttons()
        self.config_views()
        self.config_pinch_action()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !self.is_view_finish_load {
            self.request_for_photos()
            { photo_access in
                if photo_access {
                    self.request_for_camera_access()
                    { access in
                        self.permission_camara = access
                        self.request_for_audio_access()
                        { microfono in
                            self.permission_microfono = microfono
                        }
                        self.prepare()
                        { _ in
                            try? self.display_preview(on: self.view_preview_camera)
                        }
                    }
                }
            }
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        if keyPath == "recording" {
            if let video = self.videoFileOutput {
                if video.isRecording {
                    self.change_button_capture_backgruound()
                } else  {
                    self.finish_recording_video()
                    self.change_button_capture_backgruound()
                }
            }
        }
    }
}

//Funciones => Capturar, Cambiar camara, video
extension View_Final_Picker {
    enum Camera_Error: Error {
        case captureSessionAlreadyRunnig
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case noCameraPermission
        case noAudioPermission
        case unknown
    }
    
    enum CameraPosition {
        case front
        case rear //back
    }
    
    
    func display_preview(on view_player: UIView) throws
    {
        guard let sesion = self.captureSession,
              sesion.isRunning
            else { throw Camera_Error.captureSessionIsMissing }
        
        view_player.layer.sublayers?.forEach({
            if $0.name == "player_preview"
            {
                $0.removeFromSuperlayer()
            }
        })
        self.previewLayer = AVCaptureVideoPreviewLayer(session: sesion)
        self.previewLayer?.videoGravity = .resizeAspectFill
        self.previewLayer?.name = "player_preview"
        view_player.layer.insertSublayer(self.previewLayer!,
                                         at: 0)
        
        self.previewLayer?.frame = view_player.bounds
    }
    
    func switch_cameras() throws
    {
        guard let position = self.camara_position,
              let sesion = self.captureSession,
            sesion.isRunning
            else {  throw Camera_Error.captureSessionIsMissing }
        
        sesion.beginConfiguration()
        
        switch position {
        case .front:
            try self.switch_to_rear_camera()
            break
        case .rear:
            try self.switch_to_front_camera()
            break
        }
        sesion.commitConfiguration()
    }
    
    private func switch_to_front_camera() throws
    {
        guard let inputs = self.captureSession?.inputs,
              let rear_cameraInput = self.rear_camera_input,
              inputs.contains(rear_cameraInput),
              let frontCamera = self.camera_front
            else {
                throw Camera_Error.invalidOperation
        }
        
        self.front_camera_input = try AVCaptureDeviceInput(device: frontCamera)
        self.captureSession?.removeInput(rear_cameraInput)
        
        if let newInput = self.front_camera_input {
            if self.captureSession?.canAddInput(newInput) ?? false
            {
                self.captureSession?.addInput(newInput)
                self.camara_position = .front
            }
        }
    }
    
    private func switch_to_rear_camera() throws
    {
        guard let inputs = self.captureSession?.inputs,
              let front_cameraInput = self.front_camera_input,
              inputs.contains(front_cameraInput),
              let rearCamera = self.camera_rear
            else { throw Camera_Error.invalidOperation }
        
        self.rear_camera_input = try AVCaptureDeviceInput(device: rearCamera)
        self.captureSession?.removeInput(front_cameraInput)
        
        if let newInput = self.rear_camera_input {
            if let sesion = self.captureSession
            {
                if sesion.canAddInput(newInput) {
                    sesion.addInput(newInput)
                    self.camara_position = .rear
                }
            }
        }
    }
    
    func captureImage(completion: @escaping(UIImage?, Error?) -> Void)
    {
        guard let sesion = self.captureSession,
                  sesion.isRunning
            else {
                completion(nil, nil)
                return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photo_capture_completion_block = completion
    }
    
    func start_video_record()
    {
        guard let video = self.videoFileOutput,
            let sesion = self.captureSession
            else { return }
        
        if video.isRecording {
            video.stopRecording()
            //self.finish_recording_video()
        } else {
            self.switch_flash_image(isEnable: false,
                                    isVideo: true)
            if sesion.outputs.contains(video){
                self.start_recording(video: video)
            } else if sesion.canAddOutput(video) {
                sesion.addOutput(video)
                self.start_recording(video: video)
            }
        }
    }
}

// Imagen capturada
extension View_Final_Picker: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("\n\n\(error.localizedDescription)\n\n")
            self.photo_capture_completion_block?(nil, error)
        } else if let image_data = photo.fileDataRepresentation() {
            
            if let imagen = UIImage(data: image_data) {
                do {
                    try PHPhotoLibrary.shared().performChangesAndWait({
                        PHAssetChangeRequest.creationRequestForAsset(from: imagen)
                        self.photo_capture_completion_block?(nil, nil)
                    })
                } catch let err as NSError {
                    print("\n\n\(err.localizedDescription) \n\n")
                    self.photo_capture_completion_block?(nil, err)
                }
            }
        }
    }
}

// Video Capturado
extension View_Final_Picker: AVCaptureFileOutputRecordingDelegate
{
    enum file_extension {
        case video
        case image
    }
    
    private func start_recording(video: AVCaptureMovieFileOutput)
    {
        let file_url = self.get_url_for_video()
        self.config_video_options(video: video)
        video.startRecording(to: file_url,
                             recordingDelegate: self)
        
        self.view_switch_camera.isHidden = true
        self.config_timer()
    }
    
    //Detiene el timer de video y devuelve ciertos valores a su estado inicial
    private func finish_recording_video()
    {
        self.segundos_transcurridos = 0
        self.timer_up_video?.invalidate()
        self.view_switch_camera.isHidden = false
    }
    
    //Configura el maximo de tiempo y peso del video
    private func config_video_options(video: AVCaptureMovieFileOutput)
    {
        let maxMB = 10
        let maxRecordedFileSize = Int64(maxMB * (1024 * 1024))
        video.maxRecordedFileSize = maxRecordedFileSize
    }
    
    private func config_timer()
    {
        self.lbl_video_time.text = "00:00"
        self.timer_up_video = Timer.scheduledTimer(timeInterval: 1,
                                                    target: self,
                                                    selector: #selector(timer_update),
                                                    userInfo: nil,
                                                    repeats: true)
    }
    
    @objc func timer_update()
    {
        self.segundos_transcurridos += 1
        let (minutos, segundos) = self.get_time()
        self.lbl_video_time.text = minutos + ":" + segundos
    }
    
    private func get_time() -> (String, String)
    {
        let minutos  = self.segundos_transcurridos / 60
        let segundos = self.segundos_transcurridos - (minutos * 60)
        
        let minutos_string  = minutos > 9 ? "\(minutos)" : "0\(minutos)"
        let segundos_string = segundos > 9 ? "\(segundos)" : "0\(segundos)"
        return (minutos_string, segundos_string)
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        let file_path = outputFileURL.path
        self.saveFile(url_archivo: outputFileURL,
                      type: .video)
        { _ in
            let manager = FileManager.default
            if manager.isDeletableFile(atPath: file_path){
                do {
                    try manager.removeItem(atPath: file_path)
                } catch let err as NSError {
                    print(err)
                }
            }
        }
    }
    
    func saveFile(url_archivo: URL,
                  type: file_extension,
                  completion: @escaping(_ assetID: String?) -> ())
    {
        var videoAssetLibrary: PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges({
            var request: PHAssetChangeRequest?
            
            switch type {
            case .video:
                request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url_archivo)
                break
            case .image:
                request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url_archivo)
                break
            }
            videoAssetLibrary = request?.placeholderForCreatedAsset
            
        }){ saved, ph_error in
            if saved {
                if let localID = videoAssetLibrary?.localIdentifier
                {
                    let assetID = localID.replacingOccurrences(of: "/.*",
                                                               with: "",
                                                               options: String.CompareOptions.regularExpression,
                                                               range: nil)
                    completion(assetID)
                }
            } else {
                print(ph_error?.localizedDescription ?? "Error al guardar video")
                completion(nil)
            }
        }
    }
    
    private func get_url_for_video() -> URL
    {
        let fileName = "\(arc4random()).mp4"
        let documentURL = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask)[0]
        let filePath = documentURL.appendingPathComponent(fileName)
        return filePath
    }
}



















