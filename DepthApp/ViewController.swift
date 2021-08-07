//
//  ViewController.swift
//  DepthApp
//
//  Created by Juha Eskonen on 13/03/2019.
//  Copyright © 2019 Juha Eskonen. All rights reserved.
//

import UIKit
import AVFoundation

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
    
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private let dataOutputQueue = DispatchQueue(label: "dataOutputQueue")
    private let depthCapture = DepthCapture()
    
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
    @IBOutlet var cameraView: UIView!
    @IBOutlet weak var TextView: UITextField!
    
    
    
    override func viewWillAppear(_ animated: Bool) {
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
        }
    }
    
    func startRecording(){
        depthCapture.prepareForRecording()
        
        
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.dateFormat = "yyyy-MM-dd'@'HH-mm-ssZZZZ"
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
            
            if (self.recordingTime == 180)
            {
                timer.invalidate()
                self.recordingTime = 0
                self.TextView.text = "录制时间:00:00"
                let alertController = UIAlertController(title: "达到录制时长上限", message: "录制三分钟，达到录制上线。文件已自动保存！", preferredStyle: .alert)
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
        formatter.dateFormat = "yyyy-MM-dd'@'HH-mm-ssZZZZ"
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
        if(self.isRecording) {
            let ddm = depthData.depthDataMap
            depthCapture.addPixelBuffers(pixelBuffer: ddm)
            timestamps = timestamps + String(Int(Date().timeIntervalSince1970 * 1000)) + "\n"
        }
    }
}
