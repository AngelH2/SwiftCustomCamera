import UIKit
import Photos

//Configuracion de componentes
extension View_Final_Picker {
    func prepare(completion: ((Error?) -> ())? = nil)
    {
        if !self.permission_camara {
            completion?(nil)
            return
        }
        DispatchQueue(label: "prepare_queue").async {
            self.create_capture_session()
            do {
                try self.configure_capture_devices()
                try self.configure_device_inputs()
                try self.configure_photo_output()
            } catch let err as NSError {
                print(err.localizedDescription)
                DispatchQueue.main.async {
                    completion?(err)
                }
                return
            }
            
            DispatchQueue.main.async {
                completion?(nil)
            }
        }
    }
    
    private func create_capture_session()
    {
        self.captureSession = AVCaptureSession()
        self.captureSession?.sessionPreset = .medium
    }
    
    private func configure_capture_devices() throws
    {
        if !self.permission_camara {
            throw Camera_Error.noCameraPermission
        }
        
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera,
                                                                     .builtInMicrophone],
                                                       mediaType: nil,
                                                       position: .unspecified)
        let dispositivos = (session.devices.flatMap({ $0 }))
        guard !dispositivos.isEmpty
            else {  throw Camera_Error.noCamerasAvailable }
        
        for device in dispositivos
        {   if device.hasMediaType(.video)
        {
            if device.position == .front {
                self.camera_front = device
            }
            if device.position == .back {
                self.camera_rear = device
                try device.lockForConfiguration()
                device.focusMode = .continuousAutoFocus
                device.unlockForConfiguration()
            }
            
        } else if self.permission_microfono {
            if device.hasMediaType(.audio)
            {
                self.audio_device = device
            }
            }
        }
    }
    
    private func configure_device_inputs() throws
    {
        guard let captureSession = self.captureSession
            else { throw Camera_Error.captureSessionIsMissing }
        
        if let rearCamera = self.camera_rear {
            self.rear_camera_input = try AVCaptureDeviceInput(device: rearCamera)
            if captureSession.canAddInput(self.rear_camera_input!)
            {
                captureSession.addInput(self.rear_camera_input!)
                self.camara_position = .rear
            }
        }
        else if let frontCamera = self.camera_front {
            self.front_camera_input = try AVCaptureDeviceInput(device: frontCamera)
            if captureSession.canAddInput(self.front_camera_input!)
            {
                captureSession.addInput(self.front_camera_input!)
                self.camara_position = .front
            }
        } else {
            throw Camera_Error.noCamerasAvailable
        }
        
        self.configure_audio_input()
    }
    
    private func configure_audio_input()
    {
        if let audioDevice = self.audio_device,
            let input = try? AVCaptureDeviceInput(device: audioDevice),
            let session = self.captureSession
        {
            if session.canAddInput(input)
            {
                session.addInput(input)
            }
        }
    }
    
    private func configure_photo_output() throws
    {
        guard let session = self.captureSession
            else { throw Camera_Error.captureSessionIsMissing }
        
        self.photoOutput = AVCapturePhotoOutput()
        self.videoFileOutput = AVCaptureMovieFileOutput()
        
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])
        self.photoOutput?.setPreparedPhotoSettingsArray( [settings],
                                                         completionHandler: nil)
        
        if let photo = self.photoOutput {
            if session.canAddOutput(photo)
            {
                session.addOutput(photo)
            }
        }
        
        if let video = self.videoFileOutput {
            if session.canAddOutput(video){
                video.addObserver(self,
                                  forKeyPath: "recording",
                                  options: [.new, .old], context: nil)
                session.addOutput(video)
            }
        }
        session.startRunning()
    }
}

// Pedir acceso a la camara, microfono e imagenes
extension View_Final_Picker {
    func request_for_camera_access(completion: @escaping(Bool) ->())
    {
        AVCaptureDevice.requestAccess(for: .video)
        { access in
            completion(access)
        }
    }
    
    func request_for_audio_access(completion: @escaping(Bool) ->())
    {
        AVAudioSession.sharedInstance().requestRecordPermission()
            { access in
                completion(access)
        }
    }
    
    func request_for_photos(completion: @escaping(Bool) -> ())
    {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined, .denied, .restricted:
            PHPhotoLibrary.requestAuthorization({
                status in
                completion(status == .authorized)
            })
            break
        }
    }
}
