
import UIKit
import AVFoundation
import Network

@available(iOS 12.0, *)
class CameraController: UIViewController {

    @IBOutlet var messageLabel:UILabel!
    @IBOutlet var topbar: UIView!
    
    @IBOutlet weak var textHost: UITextField!
    @IBOutlet weak var textPort: UITextField!
    
    @IBOutlet weak var labelIP: UILabel!
    @IBOutlet weak var labelPort: UILabel!
    
    @IBOutlet weak var buttonStartStreaming: UIButton!
    
    var captureSession = AVCaptureSession()
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    
    var connection: NWConnection?
    var hostUDP: NWEndpoint.Host = ""
    var portUDP: NWEndpoint.Port = 0
    var udpStart = false
    
    @IBAction func onclick_streaming(_ sender: Any)
    {
        let title = (sender as AnyObject).title(for: .normal)
        
        hostUDP = NWEndpoint.Host(textHost.text!)
        portUDP = NWEndpoint.Port(integerLiteral: UInt16(textPort.text!)!)
        
        if(title == "Connect")
        {
            connectToUDP(hostUDP,portUDP)
            (sender as AnyObject).setTitle("Disconnect", for: .normal)
        }
        else
        {
            udpStart = false;
            self.connection?.cancelCurrentEndpoint()
            (sender as AnyObject).setTitle("Connect", for: .normal)
        }
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
   
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textHost.text = getIPAddressForCellOrWireless()
        
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
        view.bringSubview(toFront: messageLabel)
        view.bringSubview(toFront: topbar)
        view.bringSubview(toFront: textHost)
        view.bringSubview(toFront: textPort)
        view.bringSubview(toFront: labelIP)
        view.bringSubview(toFront: labelPort)
        view.bringSubview(toFront: buttonStartStreaming)
        
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
    
    // MARK: - Helper methods

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

/*

CGRect cropRect = CGRectMake(50, 50, 100, 100); // cropRect
CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
CVReturn lock = CVPixelBufferLockBaseAddress(pixelBuffer, 0);
if (lock == kCVReturnSuccess) {
    int w = 0;
    int h = 0;
    int r = 0;
    int bytesPerPixel = 0;
    unsigned char *buffer;
    w = CVPixelBufferGetWidth(pixelBuffer);
    h = CVPixelBufferGetHeight(pixelBuffer);
    r = CVPixelBufferGetBytesPerRow(pixelBuffer);
    bytesPerPixel = r/w;
    buffer = CVPixelBufferGetBaseAddress(pixelBuffer);
    UIGraphicsBeginImageContext(cropRect.size); // create context for image storage, use cropRect as size
    CGContextRef c = UIGraphicsGetCurrentContext();
    unsigned char* data = CGBitmapContextGetData(c);
    if (data != NULL) {
        // iterate over the pixels in cropRect
        for(int y = cropRect.origin.y, yDest = 0; y<CGRectGetMaxY(cropRect); y++, yDest++) { 
            for(int x = cropRect.origin.x, xDest = 0; x<CGRectGetMaxX(cropRect); x++, xDest++) {
                int offset = bytesPerPixel*((w*y)+x); // offset calculation in cropRect
                int offsetDest = bytesPerPixel*((cropRect.size.width*yDest)+xDest); // offset calculation for destination image
                for (int i = 0; i<bytesPerPixel; i++) {
                    data[offsetDest+i]   = buffer[offset+i];
                }
            }
        }
    } 
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

*/

@available(iOS 12.0, *)
extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                                didOutput sampleBuffer: CMSampleBuffer,
                                from connection: AVCaptureConnection)
    {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        if(udpStart)
        {
            
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            //let height = CVPixelBufferGetHeight(pixelBuffer)
            let src_buff = CVPixelBufferGetBaseAddress(pixelBuffer)
            //let data = NSData(bytes: src_buff, length: bytesPerRow * height) as Data
            let dataRow = NSData(bytes: src_buff, length: bytesPerRow * 1) as Data
            
            self.sendUDP(dataRow)
            
            /*let dataLen = data.count
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
                self.sendUDP(chunk)
             }
          
            //let dataToSend: Data? = "Test Stream".data(using: .utf8)*/
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
        }
       
    }
}

@available(iOS 12.0, *)
extension CameraController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            //messageLabel.text = "No QR code is detected"
            udpStart = false;
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
                messageLabel.text = metadataObj.stringValue
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
