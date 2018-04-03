import UIKit
import AVFoundation

// Configuracion simple
extension View_Final_Picker {
    public func config_buttons()
    {
        self.config_view_with_selector(self.view_button_camera, selector: #selector(tap_button_camera))
        self.config_view_with_selector(self.view_switch_camera, selector: #selector(tap_switch_camera))
        self.config_view_with_selector(self.view_button_capture, selector: #selector(tap_button_capture))
        self.config_view_with_selector(self.img_btn_flash, selector: #selector(tap_use_flash))
    }
    
    public func config_views()
    {
        self.lbl_video_time.text = "00:00"
        self.lbl_video_time.isHidden = true
        self.view_button_camera.circle()
        self.view_switch_camera.circle()
        
        self.view_button_capture.layer.borderColor = UIColor.black.cgColor
        self.view_button_capture.layer.borderWidth = 2
        self.view_button_capture.circle()
        
        self.switch_flash_image()
    }
    
    public func config_pinch_action()
    {
        let pinch = UIPinchGestureRecognizer(target: self,
                                             action: #selector(tap_pinch_to_zoom(_:)))
        self.view_preview_camera.addGestureRecognizer(pinch)
    }
    
    func config_view_with_selector(_ elemento: UIView, selector: Selector)
    {
        let tap = UITapGestureRecognizer(target: self, action: selector)
        elemento.addGestureRecognizer(tap)
    }
}

//Funcion de los botones
extension View_Final_Picker {
    @objc func tap_button_camera()
    {
        let isRecording = (self.view_button_capture.backgroundColor == .white) ? false : true
        if isRecording {
            self.mensaje(mensaje: "Video en grabacion")
        } else {
            let newImage = (self.img_icon_switch_camera_video.image == #imageLiteral(resourceName: "icon_camara")) ? #imageLiteral(resourceName: "icon_video") : #imageLiteral(resourceName: "icon_camara")
            self.img_icon_switch_camera_video.image = newImage
            
            let isTapVideo = (newImage == #imageLiteral(resourceName: "icon_camara")) ? true : false
            self.lbl_video_time.isHidden = isTapVideo
            self.switch_flash_image(isEnable: isTapVideo)
        }
    }
    
    @objc func tap_switch_camera()
    {
        try? self.switch_cameras()
        let isEnabled = self.camara_position == .front ? false : true
        self.switch_flash_image(isEnable: isEnabled)
    }
    
    @objc func tap_button_capture()
    {
        let isVideoMode =  !self.lbl_video_time.isHidden
        
        if isVideoMode {
            self.start_video_record()
        } else {
            self.change_button_capture_backgruound(isEnabled: false)
            self.captureImage(completion: {
                _, _ in
                self.change_button_capture_backgruound()
            })
        }
    }
    
    func change_button_capture_backgruound(isEnabled: Bool = true)
    {
        self.view_button_capture.isUserInteractionEnabled = isEnabled
        let newBackGround = (self.view_button_capture.backgroundColor == .white) ? #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1) : .white
        self.view_button_capture.backgroundColor = newBackGround
    }
    
    @objc func tap_use_flash()
    {
        self.switch_flash_image()
    }
    
    func switch_flash_image(isEnable: Bool = true,
                            isVideo: Bool = false)
    {
        self.img_btn_flash.isUserInteractionEnabled = isEnable
        if isVideo || self.camara_position == .front || !self.lbl_video_time.isHidden {
            self.img_btn_flash.image = #imageLiteral(resourceName: "icon_flash_off")
            self.flashMode = .off
        } else {
            if self.flashMode == .on {
                self.img_btn_flash.image = #imageLiteral(resourceName: "icon_flash_off")
                self.flashMode = .off
            } else if self.flashMode == .off {
                self.img_btn_flash.image = #imageLiteral(resourceName: "icon_flash_on")
                self.flashMode = .on
            }
        }
    }
    
    @objc func tap_pinch_to_zoom(_ pinch: UIPinchGestureRecognizer)
    {
        guard let position = self.camara_position else { return }
        
        var device_selected: AVCaptureDevice?
        if position == .front {
            device_selected = self.camera_front
        } else if position == .rear {
            device_selected = self.camera_rear
        }
        
        guard let device = device_selected else { return }
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(min(max(factor,self.zoom_minValue), self.zoom_maxValue),
                       device.activeFormat.videoMaxZoomFactor)
        }
        
        func update(sacale factor: CGFloat) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = factor
            } catch let err as NSError {
                print(err.localizedDescription)
            }
        }
        
        let newScaleFactor = minMaxZoom(pinch.scale * self.zoom_lastFactor)
        switch pinch.state {
            case .began: break
            case .changed:
                update(sacale: newScaleFactor)
            case .ended:
                self.zoom_lastFactor = minMaxZoom(newScaleFactor)
                update(sacale: self.zoom_lastFactor)
            default: break
        }
    }
}

extension UIView {
    func circle()
    {
        self.layer.cornerRadius = self.frame.size.height / 2
        self.clipsToBounds = true
    }
}

extension UIViewController {
    func mensaje(title: String? = nil, mensaje: String)
    {
        let controller = UIAlertController(title: title, message: mensaje, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        self.present(controller, animated: true, completion: nil)
    }
}





