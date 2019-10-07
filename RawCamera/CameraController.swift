
import UIKit
import AVFoundation
import Network

@available(iOS 12.0, *)
class CameraController: UIViewController , UITextFieldDelegate {

    
    @IBOutlet weak var textHost: UITextField!
    @IBOutlet weak var textPort: UITextField!
    
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var labelIP: UILabel!
    @IBOutlet weak var labelCalc: UILabel!
    @IBOutlet weak var labelPort: UILabel!
    
    @IBOutlet weak var buttonStreaming: UIButton!
    @IBOutlet weak var buttonFlash: UIButton!
    @IBOutlet weak var buttonExit: UIButton!
    
    var captureSession = AVCaptureSession()
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    
    var connection: NWConnection?
    var hostUDP: NWEndpoint.Host = ""
    var portUDP: NWEndpoint.Port = 0
    var udpStart = false
    
    
    @IBAction func onclick_flash(_ sender: Any)
    {
        let title = (sender as AnyObject).title(for: .normal)
        if(title == "Flash On")
        {
            (sender as AnyObject).setTitle("Flash Off", for: .normal)
        }
        else
        {
            (sender as AnyObject).setTitle("Flash On", for: .normal)
        }
        
        toggleTorch()
    }
    
    @IBAction func onclick_streaming(_ sender: Any)
    {
       let title = (sender as AnyObject).title(for: .normal)
       
       
       hostUDP = NWEndpoint.Host(textHost.text!)
       portUDP = NWEndpoint.Port(integerLiteral: UInt16(textPort.text!)!)
       
       if(title == "Send")
       {
           connectToUDP(hostUDP,portUDP)
           (sender as AnyObject).setTitle("Disconnect", for: .normal)
       }
       else
       {
           udpStart = false;
           self.connection?.cancelCurrentEndpoint()
           (sender as AnyObject).setTitle("Send", for: .normal)
       }
    }
    
    @IBAction func onclick_exit(_ sender: Any)
    {
        exit(0)
    }
    
    //Calls this function when the tap is recognized.
    @objc func dismissKeyboard() {
    //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
    
    private let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                                      AVMetadataObject.ObjectType.code39,
                                      AVMetadataObject.ObjectType.code39Mod43,
                                      AVMetadataObject.ObjectType.code93,
                                      AVMetadataObject.ObjectType.code128,
                                      AVMetadataObject.ObjectType.ean8,
                                      AVMetadataObject.ObjectType.ean13,
                                      AVMetadataObject.ObjectType.aztec,
                                      AVMetadataObject.ObjectType.pdf417,
                                      AVMetadataObject.ObjectType.itf14,
                                      AVMetadataObject.ObjectType.dataMatrix,
                                      AVMetadataObject.ObjectType.interleaved2of5,
                                      AVMetadataObject.ObjectType.qr]
   
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        textHost.text = getIPAddressForCellOrWireless()
        
        labelCalc.numberOfLines = 0;
        textPort.keyboardType = .numberPad
        textHost.delegate = self

        //Looks for single or multiple taps.
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)

        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            fatalError("Failed to get the camera device")
        }
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Set the input device on the capture session.
            captureSession.addInput(input)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)
            
            if (captureSession.canSetSessionPreset(AVCaptureSession.Preset.low))
            {
                captureSession.sessionPreset = AVCaptureSession.Preset.low;
            }
            
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
            //captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
        
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self as AVCaptureVideoDataOutputSampleBufferDelegate, queue: DispatchQueue(label: "sample buffer delegate", attributes: []))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Start video capture.
        captureSession.startRunning()
        
        // Move the message label and top bar to the front
        view.bringSubview(toFront: textHost)
        view.bringSubview(toFront: textPort)
        view.bringSubview(toFront: labelInfo)
        view.bringSubview(toFront: labelIP)
        view.bringSubview(toFront: labelPort)
        view.bringSubview(toFront: labelCalc)
        view.bringSubview(toFront: buttonStreaming)
        view.bringSubview(toFront: buttonFlash)
        view.bringSubview(toFront: buttonExit)
        
        // Initialize QR Code Frame to highlight the QR code
        qrCodeFrameView = UIView()
        
        if let qrCodeFrameView = qrCodeFrameView {
            qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
            qrCodeFrameView.layer.borderWidth = 2
            view.addSubview(qrCodeFrameView)
            view.bringSubview(toFront: qrCodeFrameView)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
    {
        //For ip numer validation
        if textField == textHost {
            let allowedCharacters = CharacterSet(charactersIn:".0123456789")
            let characterSet = CharacterSet(charactersIn: string)
            return allowedCharacters.isSuperset(of: characterSet)
        }
        return true
    }
    
    func launchApp(decodedURL: String) {
        
        if presentedViewController != nil {
            return
        }
        
        let alertPrompt = UIAlertController(title: "Open App", message: "You're going to open \(decodedURL)", preferredStyle: .actionSheet)
        let confirmAction = UIAlertAction(title: "Confirm", style: UIAlertActionStyle.default, handler: { (action) -> Void in
            
            if let url = URL(string: decodedURL) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil)
        
        alertPrompt.addAction(confirmAction)
        alertPrompt.addAction(cancelAction)
        
        present(alertPrompt, animated: true, completion: nil)
    }
}

extension UIImage {
    /// Get the pixel color at a point in the image
    func pixelColor(atLocation point: CGPoint) -> UIColor? {
        guard let cgImage = cgImage, let pixelData = cgImage.dataProvider?.data else { return nil }
        
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        
        let pixelInfo: Int = ((cgImage.bytesPerRow * Int(point.y)) + (Int(point.x) * bytesPerPixel))
        
        let b = CGFloat(data[pixelInfo]) / CGFloat(255.0)
        let g = CGFloat(data[pixelInfo+1]) / CGFloat(255.0)
        let r = CGFloat(data[pixelInfo+2]) / CGFloat(255.0)
        let a = CGFloat(data[pixelInfo+3]) / CGFloat(255.0)
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
    let context = CIContext()
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}

func toggleTorch() {
    guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
    guard device.hasTorch else { print("Torch isn't available"); return }

    do {
        try device.lockForConfiguration()
        if (device.torchMode == .on) {
            device.torchMode = .off
        } else {
            device.torchMode = .on
            try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
        }
        device.unlockForConfiguration()
    } catch
    {
        print("Torch can't be used")
    }
}

@available(iOS 12.0, *)
extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                                didOutput sampleBuffer: CMSampleBuffer,
                                from connection: AVCaptureConnection)
    {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        guard let uiImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else {
            return
        }
                
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
        // get the average red green and blue values from the image
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        
        var avrHue:CGFloat = 0
        var avrR:CGFloat = 0
        var avrG:CGFloat = 0
        var avrB:CGFloat = 0
        
        var h: CGFloat = 0
        var s: CGFloat = 0
        var br: CGFloat = 0
        
        let pixelsWide = Int(uiImage.size.width)
        let pixelsHigh = Int(uiImage.size.height)
        
        for x in 0..<pixelsWide
        {
            for y in 0..<pixelsHigh
            {
                let point = CGPoint(x: x, y: y)
                let color = uiImage.pixelColor(atLocation: point)!
                
                if color.getRed(&r, green: &g, blue: &b, alpha: &a)
                {
                    avrR += r
                    avrG += g
                    avrB += b
                    
                    if color.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                    {
                        avrHue += h
                    }
                }
            }
        }
            
        avrHue/=(CGFloat) (pixelsWide*pixelsHigh);
        avrR/=(CGFloat) (pixelsWide*pixelsHigh);
        avrG/=(CGFloat) (pixelsWide*pixelsHigh);
        avrB/=(CGFloat) (pixelsWide*pixelsHigh);
        
        if(udpStart)
        {
           self.sendUDP(String(format:"%0.6f %0.6f %0.6f %0.6f", avrHue, avrR, avrG, avrB))
        }
        
        DispatchQueue.global(qos: .background).async
        {
            DispatchQueue.main.async
            {
                let text:String = String(format:"H: %0.4f", avrHue)
                self.labelCalc.text = text
            }
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        /*let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let src_buff = CVPixelBufferGetBaseAddress(pixelBuffer)
        let data = NSData(bytes: src_buff, length: bytesPerRow * height) as Data
        //let dataRow = NSData(bytes: src_buff, length: bytesPerRow * 1) as Data
       
        let dataLen = data.count
        let chunkSize = 1024
        let fullChunks = Int(dataLen / chunkSize)
        let totalChunks = fullChunks + (dataLen % 1024 != 0 ? 1 : 0)
        
        //var chunks:[Data] = [Data]()
        for chunkCounter in 0..<totalChunks {
            var chunk:Data
            let chunkBase = chunkCounter * chunkSize
            var diff = chunkSize
            if(chunkCounter == totalChunks - 1) {
                diff = dataLen - chunkBase
            }
            
            let range:Range<Data.Index> = Range<Data.Index>(chunkBase..<(chunkBase + diff))
            chunk = data.subdata(in: range)
            
            if(udpStart)
            self.sendUDP(chunk)
        }
        
        //let dataToSend: Data? = "Test Stream".data(using: .utf8)
        //self.sendUDP(dataToSend!)*/
    }
}

@available(iOS 12.0, *)
extension CameraController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            //messageLabel.text = "No QR code is detected"
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if supportedCodeTypes.contains(metadataObj.type) {
            // If the found metadata is equal to the QR code metadata (or barcode) then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                launchApp(decodedURL: metadataObj.stringValue!)
                labelInfo.text = metadataObj.stringValue
            }
        }
    }
    
    func connectToUDP(_ hostUDP: NWEndpoint.Host, _ portUDP: NWEndpoint.Port) {
   
        self.connection = NWConnection(host: hostUDP, port: portUDP, using: .udp)
        
        self.connection?.stateUpdateHandler = { (newState) in
            print("This is stateUpdateHandler:")
            switch (newState) {
            case .ready:
                print("State: Ready\n")
                self.udpStart = true
            case .setup:
                print("State: Setup\n")
            case .cancelled:
                print("State: Cancelled\n")
            case .preparing:
                print("State: Preparing\n")
            default:
                print("ERROR! State not defined!\n")
            }
        }
        
        self.connection?.start(queue: .global())
    }
    
    func sendUDP(_ content: Data) {
        self.connection?.send(content: content, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            if (NWError == nil) {
                //print("Data was sent to UDP size: \(content.count)")
            } else {
                print("ERROR! Error when data (Type: Data) sending. NWError: \n \(NWError!)")
            }
        })))
    }
    
    func sendUDP(_ content: String) {
        let contentToSendUDP = content.data(using: String.Encoding.utf8)
        self.connection?.send(content: contentToSendUDP, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            if (NWError == nil) {
                //print("String Data was sent to UDP")
            } else {
                print("ERROR! Error when data (Type: Data) sending. NWError: \n \(NWError!)")
            }
        })))
    }
    
    func receiveUDP() {
        self.connection?.receiveMessage { (data, context, isComplete, error) in
            if (isComplete) {
                print("Receive is complete")
                if (data != nil) {
                    let backToString = String(decoding: data!, as: UTF8.self)
                    print("Received message: \(backToString)")
                } else {
                    print("Data == nil")
                }
            }
        }
    }
    
    func getIPAddressForCellOrWireless()-> String? {
        
        let WIFI_IF : [String] = ["en0"]
        let KNOWN_WIRED_IFS : [String] = ["en2", "en3", "en4"]
        let KNOWN_CELL_IFS : [String] = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]
        
        var addresses : [String : String] = ["wireless":"",
                                             "wired":"",
                                             "cell":""]
        
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next } // memory has been renamed to pointee in swift 3 so changed memory to pointee
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    
                    if let name: String = String(cString: (interface?.ifa_name)!), (WIFI_IF.contains(name) || KNOWN_WIRED_IFS.contains(name) || KNOWN_CELL_IFS.contains(name)) {
                        
                        // String.fromCString() is deprecated in Swift 3. So use the following code inorder to get the exact IP Address.
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        if WIFI_IF.contains(name){
                            addresses["wireless"] =  address
                        }else if KNOWN_WIRED_IFS.contains(name){
                            addresses["wired"] =  address
                        }else if KNOWN_CELL_IFS.contains(name){
                            addresses["cell"] =  address
                        }
                    }
                    
                }
            }
        }
        freeifaddrs(ifaddr)
        
        var ipAddressString : String?
        let wirelessString = addresses["wireless"]
        let wiredString = addresses["wired"]
        let cellString = addresses["cell"]
        if let wirelessString = wirelessString, wirelessString.count > 0{
            ipAddressString = wirelessString
        }else if let wiredString = wiredString, wiredString.count > 0{
            ipAddressString = wiredString
        }else if let cellString = cellString, cellString.count > 0{
            ipAddressString = cellString
        }
        return ipAddressString
    }
    
}
