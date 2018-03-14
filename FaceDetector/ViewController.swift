//
//  ViewController.swift
//  FaceDetector
//
//  Created by ZY on 2018/2/3.
//  Copyright © 2018年 ZY. All rights reserved.
//

import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, UIAlertViewDelegate{
    // 摄像头相关
    var cameraAuthStatus: AVAuthorizationStatus!
    @objc var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer!
    @objc var session: AVCaptureSession!
    @objc var captureInput:AVCaptureDeviceInput!
    @objc var captureOutput:AVCaptureVideoDataOutput!
    
    @IBOutlet weak var faceImage: UIImageView!
    @IBOutlet weak var faceInfo: UITextView!
    
    var isFinished = true
    var flag = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.session.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.session.stopRunning()
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //摄像头设置相关
    @objc func setupCamera() {
        self.session = AVCaptureSession()
        let device = AVCaptureDevice.default(for: AVMediaType.video)!
        self.captureOutput = AVCaptureVideoDataOutput()
        do{
            try self.captureInput = AVCaptureDeviceInput(device: device)
        }catch let error as NSError{
            print(error)
        }
        self.checkVideoAuth()

        self.session.beginConfiguration()
        //画面质量设置
        self.session.sessionPreset = AVCaptureSession.Preset.photo
        self.captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String:NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]
        
        if(self.session.canAddInput(self.captureInput)){
            self.session.addInput(self.captureInput)
        }
        if(self.session.canAddOutput(self.captureOutput)){
            self.session.addOutput(self.captureOutput)
        }
        
        let subQueue:DispatchQueue = DispatchQueue(label: "subQueue", attributes: [])
        captureOutput.setSampleBufferDelegate(self, queue: subQueue)
        
        self.session.commitConfiguration()
    }
    
    //检查摄像头授权情况
    @objc func checkVideoAuth() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video){
        case AVAuthorizationStatus.authorized://已经授权
            self.cameraAuthStatus = AVAuthorizationStatus.authorized
            print("authorization complete!")
            break
        case AVAuthorizationStatus.notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted: Bool) -> Void in
                if(granted){
                    //受限制
                    let alertController = UIAlertController(title: "提示", message: "摄像头权限受限制", preferredStyle: UIAlertControllerStyle.alert)
                    let alertView1 = UIAlertAction(title: "确定", style: UIAlertActionStyle.default) { (UIAlertAction) -> Void in}
                    alertController.addAction(alertView1)
                    self.present(alertController, animated: true, completion: nil)
                }
            })
            break
        case AVAuthorizationStatus.denied:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted: Bool) -> Void in
                if(!granted){
                    //否认
                    self.cameraAuthStatus = AVAuthorizationStatus.denied
                    let alertController = UIAlertController(title: "提示", message: "摄像头权限未开启", preferredStyle: UIAlertControllerStyle.alert)
                    let alertView1 = UIAlertAction(title: "确定", style: UIAlertActionStyle.default) { (UIAlertAction) -> Void in}
                    alertController.addAction(alertView1)
                    self.present(alertController, animated: true, completion: nil)
                }
            })
            break
        default:
            break
        }
    }
    
    //AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        if(isFinished){
            self.isFinished = false
            //GCD 主线程队列中刷新UI
            DispatchQueue.main.async() { () -> Void in
                let imageBuffer:CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
                CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
                
                let bytesPerRow:size_t = CVPixelBufferGetBytesPerRow(imageBuffer)
                let width:size_t  = CVPixelBufferGetWidth(imageBuffer)
                let height:size_t = CVPixelBufferGetHeight(imageBuffer)
                let safepoint:UnsafeMutableRawPointer = CVPixelBufferGetBaseAddress(imageBuffer)!
                
                let bitMapInfo:UInt32 = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
                
                //RGB
                let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
                let context:CGContext = CGContext(data: safepoint, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitMapInfo)!
                
                let quartImage: CGImage = context.makeImage()!
                CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
                
                let tempImage = UIImage(cgImage: quartImage, scale: 1, orientation: UIImageOrientation.right).fixOrientation()
                
                self.faceImage.image = self.highlightFaces(source: tempImage)
                self.isFinished = true
            }
        }
    }
    
    //利用Vision框架检测图片中的人脸
    func highlightFaces(source: UIImage) -> UIImage  {
        self.faceInfo.text = ""
        var resultImage = source
        let detectFaceRequest = VNDetectFaceLandmarksRequest { (request, error) in
            if error == nil {
                if let results = request.results as? [VNFaceObservation] {
                    self.faceInfo.text = self.faceInfo.text + "Found \(results.count) faces"
                    print("Found \(results.count) faces")
                    
                    for faceObservation in results {
                        guard let landmarks = faceObservation.landmarks else {
                            continue
                        }
                        let boundingRect = faceObservation.boundingBox
                        var landmarkRegions: [VNFaceLandmarkRegion2D] = []
                        if let faceContour = landmarks.faceContour {
                            landmarkRegions.append(faceContour)
                        }
                        if let leftEye = landmarks.leftEye {
                            landmarkRegions.append(leftEye)
                        }
                        if let rightEye = landmarks.rightEye {
                            landmarkRegions.append(rightEye)
                        }
                        if let nose = landmarks.nose {
                            landmarkRegions.append(nose)
                        }
                        if let outerLips = landmarks.outerLips {
                            landmarkRegions.append(outerLips)
                        }
                        if let leftEyebrow = landmarks.leftEyebrow {
                            landmarkRegions.append(leftEyebrow)
                        }
                        if let rightEyebrow = landmarks.rightEyebrow {
                            landmarkRegions.append(rightEyebrow)
                        }
                        if let innerLips = landmarks.innerLips {
                            landmarkRegions.append(innerLips)
                        }
                        resultImage = self.drawOnImage(source: resultImage,boundingRect: boundingRect,faceLandmarkRegions: landmarkRegions)
                        self.faceInfo.text = self.faceInfo.text + self.showDetail(faceLandmarkRegions: landmarkRegions)
                    }
                }
            } else {
                print(error!.localizedDescription)
            }
        }

        let vnImage = VNImageRequestHandler(cgImage: source.cgImage!, options: [:])
        try? vnImage.perform([detectFaceRequest])

        return resultImage
    }
    
    //在UITextView中显示关键点信息
    func showDetail(faceLandmarkRegions: [VNFaceLandmarkRegion2D]) -> String {
        let regionsType = ["人脸轮廓","左眼","右眼","鼻子","外嘴唇","左眉","右眉","内嘴唇"]
        var faceDetail = "\n人脸关键点信息\n"
        var pointCount = 0
        for a in 0..<faceLandmarkRegions.count{
            faceDetail = faceDetail + "\(regionsType[a])（共\(faceLandmarkRegions[a].pointCount)个关键点)\n"
                pointCount = pointCount + faceLandmarkRegions[a].pointCount
                
                for i in 0..<faceLandmarkRegions[a].pointCount {
                    let point = faceLandmarkRegions[a].normalizedPoints[i]
                    let p = CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
                    faceDetail = faceDetail + "(\(p.x),\(p.y))\n"
                }
        }

        faceDetail = faceDetail + "共检测出\(pointCount)个关键点\n"
        return faceDetail
    }
    
    //把关键点绘制在UIImageView中，并连线形成轮廓
    func drawOnImage(source: UIImage,boundingRect: CGRect,faceLandmarkRegions: [VNFaceLandmarkRegion2D]) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(source.size, false, 1)
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: 0, y: source.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.setBlendMode(CGBlendMode.colorBurn)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        let rectWidth = source.size.width * boundingRect.size.width
        let rectHeight = source.size.height * boundingRect.size.height
        
        //draw image
        let rect = CGRect(x: 0, y:0, width: source.size.width, height: source.size.height)
        context.draw(source.cgImage!, in: rect)
        
        //draw bound rect
        var fillColor = UIColor.black
        fillColor.setFill()
        context.setLineWidth(2.0)
        context.addRect(CGRect(x: boundingRect.origin.x * source.size.width, y:boundingRect.origin.y * source.size.height, width: rectWidth, height: rectHeight))
        context.drawPath(using: CGPathDrawingMode.stroke)
        
        //draw overlay
        fillColor = UIColor.red
        fillColor.setStroke()
        context.setLineWidth(1.0)
        for faceLandmarkRegion in faceLandmarkRegions {
            var points: [CGPoint] = []
            
            for i in 0..<faceLandmarkRegion.pointCount {
                let point = faceLandmarkRegion.normalizedPoints[i]
                let p = CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
                points.append(p)
            }
            let mappedPoints = points.map { CGPoint(x: boundingRect.origin.x * source.size.width + $0.x * rectWidth, y: boundingRect.origin.y * source.size.height + $0.y * rectHeight) }
            context.addLines(between: mappedPoints)
            context.drawPath(using: CGPathDrawingMode.stroke)
        }
        
        let coloredImg:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return coloredImg
    }
}

extension UIImage {
    // 修复图片旋转
    func fixOrientation() -> UIImage {
        let ctx = CGContext(data: nil, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: self.cgImage!.bitsPerComponent, bytesPerRow: 0, space: self.cgImage!.colorSpace!, bitmapInfo: self.cgImage!.bitmapInfo.rawValue)
        ctx?.draw(self.cgImage!, in: CGRect(x: CGFloat(0), y: CGFloat(0), width: CGFloat(size.height), height: CGFloat(size.width)))
        let cgimg: CGImage = (ctx?.makeImage())!
        let img = UIImage(cgImage: cgimg)
        
        return img
    }
}

