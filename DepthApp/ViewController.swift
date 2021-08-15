//
//  ViewController.swift
//  DepthApp
//
//  Created by Juha Eskonen on 13/03/2019.
//  Copyright © 2019 Juha Eskonen. All rights reserved.
//

import UIKit
import AVFoundation
import Accelerate
class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, AVCaptureDepthDataOutputDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    }
    
    let captureSession = AVCaptureSession()
    let sessionOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    var previewLayer = AVCaptureVideoPreviewLayer()
    var timestamps: String = ""
    var isRecording = false
    var recordingTime = 0
    var refreshcount = 0
    var depth = ""
    var depthnum = 0.0
    var warningString = ""
    
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private let dataOutputQueue = DispatchQueue(label: "dataOutputQueue")
    private var depthCapture = DepthCapture()
    
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
    @IBOutlet var cameraView: UIView!
    @IBOutlet weak var TextView: UITextField!
    
    @IBOutlet weak var DistanceText: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var WarningText: UITextField!
    @IBOutlet weak var Instruct1: UITextView!
    @IBOutlet weak var Instruct2: UITextView!
    
    override func viewDidAppear(_ animated: Bool) {
        let alertController = UIAlertController(title: "使用须知", message: "在录制开始前，将脸部放入蓝色圆内。保持脸部距离手机35cm左右。录制时，尽量保持静止。", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Confirm", style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        TextView.isEnabled = false
        WarningText.isEnabled = false
        DistanceText.isEnabled = false
        Instruct1.isEditable = false
        Instruct2.isEditable = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 280, height: 250))

            let img = renderer.image { ctx in
                let rect = CGRect(x: 45, y: 0, width: 190, height: 245)

                // 6
                if #available(iOS 13.0, *) {
                    ctx.cgContext.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
                } else {
                    // Fallback on earlier versions
                }
                ctx.cgContext.setStrokeColor(UIColor.systemBlue.cgColor)
                ctx.cgContext.setLineWidth(3)

                ctx.cgContext.addEllipse(in: rect)
                ctx.cgContext.drawPath(using: .fillStroke)
            }

            imageView.image = img
        if let device = AVCaptureDevice.default(.builtInTrueDepthCamera,
                                                for: .video, position: .front) {
            
            do {
                
                let input = try AVCaptureDeviceInput(device: device )
                
                if captureSession.canAddInput(input){
                    captureSession.sessionPreset = AVCaptureSession.Preset.photo
                    captureSession.addInput(input)
                    
                    if captureSession.canAddOutput(sessionOutput){
                        
                        captureSession.addOutput(sessionOutput)
                        
                        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                        previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
                        cameraView.layer.addSublayer(previewLayer)
                        
                        previewLayer.position = CGPoint(x: self.cameraView.frame.width / 2, y: self.cameraView.frame.height / 2)
                        previewLayer.bounds = cameraView.frame
                    }
                    
                    // Add depth output
                    guard captureSession.canAddOutput(depthDataOutput) else { fatalError() }
                    captureSession.addOutput(depthDataOutput)
                    let depthFormats = device.activeFormat.supportedDepthDataFormats
                    let filtered = depthFormats.filter({
                        CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
                    })
                    
                    let selectedFormat = filtered.max(by: {
                        first, second in CMVideoFormatDescriptionGetDimensions(first.formatDescription).width < CMVideoFormatDescriptionGetDimensions(second.formatDescription).width
                    })
                    
                    
                    do {
                        try device.lockForConfiguration()
                        device.activeDepthDataFormat = selectedFormat
                        device.unlockForConfiguration()
                    } catch {
                        print("Could not lock device for configuration: \(error)")
                        
                    }
                    if let connection = depthDataOutput.connection(with: .depthData) {
                        connection.isEnabled = true
                        depthDataOutput.isFilteringEnabled = false
                        depthDataOutput.setDelegate(self, callbackQueue: dataOutputQueue)
                    } else {
                        print("No AVCaptureConnection")
                    }
                    
                    //                    depthCapture.prepareForRecording()
                    
                    // TODO: Do we need to synchronize the video and depth outputs?
                    //outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [sessionOutput, depthDataOutput])
                    
                    captureSession.addOutput(movieOutput)
                    
                    captureSession.startRunning()
                }
                
            } catch {
                print("Error")
            }
            changeText()
        }
    }
    func changeText(){
        
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
            self.DistanceText.text = "距离屏幕" + self.depth + "cm"
            if (self.depthnum < 31){
                self.WarningText.text = "离屏幕过近！"
            }
            else if (self.depthnum > 39){
                self.WarningText.text = "离屏幕过远！"
            }
            else{
                self.WarningText.text = ""
            }
        }
        
        
    }
    func startRecording(){
        depthCapture.prepareForRecording()
        
        
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.dateFormat = "yyyy_MM_dd'_'HH_mm_ss"
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let date = Date(timeIntervalSince1970: Date().timeIntervalSince1970)
        var filePath  = "\(documentsPath)/\(formatter.string(from: date))_Video.mov"
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let fileUrl = paths[0].appendingPathComponent("output.mov")
        movieOutput.startRecording(to: URL(fileURLWithPath: filePath), recordingDelegate: self)
        print(fileUrl.absoluteString)
        print("Recording started")
        self.isRecording = true
        
        
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            print("timer fired!")
            
            self.recordingTime += 1
            var remainder = "\(self.recordingTime % 60)"
            if (self.recordingTime % 60 < 10)
            {
                remainder = "0\(self.recordingTime % 60)"
            }
            self.TextView.text = String("录制时间:0\(Int(self.recordingTime/60)):\(remainder)")
            //            print(timeLeft)
            
            if (!self.isRecording){
                timer.invalidate()
                self.recordingTime = 0
                self.TextView.text = "录制时间:00:00"
                let alertController = UIAlertController(title: "完成录制", message: "录制完成。文件已保存！", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Confirm", style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
            
            if (self.recordingTime == 300)
            {
                timer.invalidate()
                self.recordingTime = 0
                self.TextView.text = "录制时间:00:00"
                let alertController = UIAlertController(title: "达到录制时长上限", message: "录制五分钟，达到录制上线。文件已自动保存！", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Confirm", style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
                
                self.isRecording = false
                self.stopRecording()
            }
        }
    }
    
    func stopRecording(){
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.dateFormat = "yyyy_MM_dd'_'HH_mm_ss"
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let date = Date(timeIntervalSince1970: Date().timeIntervalSince1970)
        var txtPath  = "\(documentsPath)/\(formatter.string(from: date))_DepthTimeStamp.txt"
        do {
            try timestamps.write(to: URL(fileURLWithPath: txtPath), atomically: true, encoding: String.Encoding.utf8)
        } catch {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
        }
        movieOutput.stopRecording()
        print("Stopped recording!")
        self.isRecording = false
        do {
            try depthCapture.finishRecording(success: { (url: URL) -> Void in
                print(url.absoluteString)
            })
        } catch {
            print("Error while finishing depth capture.")
        }

//        depthCapture = DepthCapture()
    }
    
    @IBAction func startPressed(_ sender: Any) {
        if (!self.isRecording)
        {
            startRecording()
        }
    }
    
    @IBAction func stopPressed(_ sender: Any) {
        if (self.isRecording)
        {
            stopRecording()
        }
    }
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // Write depth data to a file
        let ddm = depthData.depthDataMap
        if(self.isRecording) {
            
            depthCapture.addPixelBuffers(pixelBuffer: ddm)
            timestamps = timestamps + String(Int(Date().timeIntervalSince1970 * 1000)) + "\n"
        }
        CVPixelBufferLockBaseAddress(ddm, .readOnly)
        let rowData = CVPixelBufferGetBaseAddress(ddm)! + Int(320) * CVPixelBufferGetBytesPerRow(ddm)
        
        var f16Pixel = rowData.assumingMemoryBound(to: UInt16.self)[Int(240)]
        var f32Pixel = Float(0.0)
        
        CVPixelBufferUnlockBaseAddress(ddm, .readOnly)
        
        withUnsafeMutablePointer(to: &f16Pixel){
            f16RawPointer in
            withUnsafeMutablePointer(to: &f32Pixel){
                f32RawPointer in
                var src = vImage_Buffer(data: f16RawPointer, height: 1, width: 1, rowBytes: 2)
                var dist = vImage_Buffer(data: f32RawPointer, height: 1, width: 1, rowBytes: 4)
                vImageConvert_Planar16FtoPlanarF(&src, &dist, 0)
            }
        }
        let depthString = String(format: "%.2f", f32Pixel * 100)
        //        print(depthString)
        if depthString != "nan"
        {
        depth = depthString
        depthnum = Double(f32Pixel * 100)
        }
    }
}

