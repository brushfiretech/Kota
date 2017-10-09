//
//  ScreenRecord.swift
//  Pods
//
//  Created by Andrew Garcia on 5/14/17.
//
//

import Foundation
import CoreGraphics
import AVFoundation
import UIKit
import AssetsLibrary
import Dispatch


extension DispatchTime {
    static func getTimeFromNow(padding: Double) -> DispatchTime {
        let tinyDelay = DispatchTime.now() + Double(Int64(padding * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        return tinyDelay
    }
}

typealias VideoCompletionBlock = (_ savePath: String) -> ()
protocol ScreenRecorderDelegate: class {
    func writeBackgroundFrameInContext(_ contextRef: CGContext)
}

class ScreenRecorder: NSObject {
    // share instance
    static let shared = ScreenRecorder()
    var isRecording = false
    var saveToCamera = false
    weak var delegate: ScreenRecorderDelegate?
    // video url
    var videoURL: URL! {
        willSet {
            if isRecording {
                assert(!isRecording, "videoURL can not be changed whilst recording is in progress")
            }
        }
    }
    
    fileprivate var tempFileUrl: URL {
        get {
            let homeDirector = NSHomeDirectory()
            let output = (homeDirector as NSString).appendingPathComponent("tmp/screenCapture.mp4")
            //removeTempFilePath(path: output)
            return URL(fileURLWithPath: output)
        }
    }
    
    // private variable
    fileprivate var videoWriter: AVAssetWriter?
    fileprivate var videoWriterInput: AVAssetWriterInput?
    fileprivate var avAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    fileprivate var displayLink: CADisplayLink?
    fileprivate var outputBufferPoolAuxAttributes: NSDictionary?
    fileprivate var firstTimeStamp: CFTimeInterval = 0
    
    ///Queues
    fileprivate var _render_queue: DispatchQueue?
    fileprivate var _append_pixelBuffer_queue: DispatchQueue?
    fileprivate var _frameRenderingSemaphore = DispatchSemaphore(value: 1)
    fileprivate var _pixelAppendSemaphore = DispatchSemaphore(value: 1)
    fileprivate var _viewSize = CGSize.zero
    fileprivate var _scale: CGFloat = 0
    fileprivate var _rgbColorSpace: CGColorSpace?
    fileprivate var _outputBufferPool: CVPixelBufferPool?
    
    override init() {
        super.init()
        commonInit()
    }
    
    /**
     * Common init
     */
    fileprivate func commonInit() {
        _viewSize = UIScreen.main.bounds.size
        _scale = UIScreen.main.scale
        if UI_USER_INTERFACE_IDIOM() == .pad && _scale > 1 {
            _scale = 1.0
        }
        setupQueues()
    }
    
    /**
     * Setup queues
     */
    fileprivate func setupQueues() {
        _append_pixelBuffer_queue = DispatchQueue(label: "ScreenRecorder.append_queue")
        _render_queue = DispatchQueue(label: "ScreenRecorder.render_queue")
    }
    
    /**
     * Start recording
     */
    func startRecording() -> Bool {
        if isRecording {
            return true
        }
        self.removeTempFilePath(path: self.tempFileUrl.path)
        setUpWriter()
        isRecording = videoWriter?.status == AVAssetWriterStatus.writing ? true : false
        displayLink = CADisplayLink(target: self,
                                    selector: #selector(writeVideoFrame))
        displayLink?.add(to: RunLoop.main, forMode: .commonModes)
        return isRecording
    }
    
    /**
     * Stop recording
     */
    func stopRecording(callback: @escaping VideoCompletionBlock) {
        if isRecording {
            isRecording = false
            displayLink?.remove(from: RunLoop.main, forMode: .commonModes)
            completeRecordingSession(callback: callback)
        }
    }
    
    func completeRecordingSession(callback: @escaping VideoCompletionBlock) {
        guard let videoWriter = self.videoWriter else {
            return
        }
        _render_queue?.async {
            self._append_pixelBuffer_queue?.sync {
                self.videoWriterInput?.markAsFinished()
                videoWriter.finishWriting(completionHandler: {
                    func internalCompletion(savePath: String) {
                        self.cleanUp()
                        DispatchQueue.main.async {
                            callback(savePath)
                        }
                    }
                    if let url = self.videoURL {
                        internalCompletion(savePath: url.path)
                    } else {
                        
                        let writeUrl = self.saveToCamera ? videoWriter.outputURL : self.tempFileUrl
                        if self.saveToCamera {
                            let library = ALAssetsLibrary()
                            library.writeVideoAtPath(toSavedPhotosAlbum: writeUrl, completionBlock: { (url, error) in
                                if let err = error {
                                    print("Error copying video to camera roll: \(err.localizedDescription)")
                                } else {
                                    print("write url \(writeUrl.path)")
                                    //self.removeTempFilePath(path: writeUrl.path)
                                    internalCompletion(savePath: writeUrl.path)
                                }
                            })
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.getTimeFromNow(padding: 1) , execute: {
                                print("write url \(writeUrl.path)")
                                internalCompletion(savePath: writeUrl.path)
                            })
                        }
                    }
                })
            }
        }
    }
    
    func removeTempFilePath(path: String) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            try? fileManager.removeItem(atPath: path)
        }
    }
    
    func cleanUp() {
        avAdaptor = nil
        videoWriterInput = nil
        videoWriter = nil
        firstTimeStamp = 0
        outputBufferPoolAuxAttributes = nil
    }
    
    func setUpWriter() {
        _rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_32BGRA,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String : true,
            kCVPixelBufferWidthKey as String : _viewSize.width * _scale,
            kCVPixelBufferHeightKey as String : _viewSize.height * _scale,
            kCVPixelBufferBytesPerRowAlignmentKey as String : _viewSize.width * _scale * 4
        ]
        
        _outputBufferPool = nil
        CVPixelBufferPoolCreate(nil,
                                nil,
                                bufferAttributes as CFDictionary,
                                &_outputBufferPool)
        var outputUrl: URL
        if let url = videoURL {
            outputUrl = url
        } else {
            outputUrl = tempFileUrl
        }
        videoWriter = try? AVAssetWriter(outputURL: outputUrl, fileType: AVFileType.mov)
        assert((videoWriter != nil))
        let pixelNumber = _viewSize.width * _viewSize.height * _scale
        let videoCompression = [AVVideoAverageBitRateKey: pixelNumber * 11.4]
        let videoSettings: [String : Any] = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: _viewSize.width * _scale,
            AVVideoHeightKey: _viewSize.height * _scale,
            AVVideoCompressionPropertiesKey: videoCompression
        ]
        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video,
                                              outputSettings: videoSettings)
        assert((videoWriterInput != nil))
        videoWriterInput?.expectsMediaDataInRealTime = true
        videoWriterInput?.transform = videoTransformForDeviceOrientation()
        
        avAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput!,
                                                         sourcePixelBufferAttributes: nil)
        videoWriter?.add(videoWriterInput!)
        videoWriter?.startWriting()
        videoWriter?.startSession(atSourceTime: CMTime(value: 0, timescale: 1000))
    }
    
    func videoTransformForDeviceOrientation() -> CGAffineTransform {
        var videoTransform = CGAffineTransform.identity
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .landscapeLeft:
            videoTransform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi/2))
        case .landscapeRight:
            videoTransform = CGAffineTransform(rotationAngle: CGFloat(Double.pi/2))
        case .portraitUpsideDown:
            videoTransform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
        default:
            break
        }
        
        return videoTransform
    }
    
    @objc func writeVideoFrame() {
        let result = _frameRenderingSemaphore.wait(timeout: DispatchTime.now())
        if result.hashValue > 0 {
            return
        }
        weak var weakself = self
        _render_queue?.async {
            guard let videoWriterInput = self.videoWriterInput else {
                return
            }
            if !videoWriterInput.isReadyForMoreMediaData {
                return
            }
            guard let strongself = weakself else {
                return
            }
            let timeStamp = strongself.displayLink?.timestamp ?? 0
            if strongself.firstTimeStamp == 0 {
                strongself.firstTimeStamp = timeStamp
            }
            let elapsed = timeStamp - strongself.firstTimeStamp
            let time = CMTime(seconds: elapsed, preferredTimescale: 1000)
            var pixelBuffer: CVPixelBuffer?
            let bitmapContext = strongself.createPixelBufferAndBitmapContext(pixelBuffer: &pixelBuffer)
            guard let context = bitmapContext else {
                return
            }
            guard let buffer = pixelBuffer else {
                return
            }
            self.delegate?.writeBackgroundFrameInContext(context)
            DispatchQueue.main.async {
                UIGraphicsPushContext(context)
                let rect = CGRect(x: 0,
                                  y: 0,
                                  width: strongself._viewSize.width,
                                  height: strongself._viewSize.height
                )
                let windows = UIApplication.shared.windows
                for window in windows {
                    window.drawHierarchy(in: rect, afterScreenUpdates: false)
                }
                UIGraphicsPopContext()
            }
            
            let result = strongself._pixelAppendSemaphore.wait(timeout: DispatchTime.now())
            if result.hashValue > 0 {
                CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
                return
            }
            strongself._append_pixelBuffer_queue?.async {
                let success = strongself.avAdaptor?.append(buffer, withPresentationTime: time) ?? false
                if !success {
                    print("Warning: Unable to write buffer to video")
                }
                CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
                _ = strongself._pixelAppendSemaphore.signal()
            }
            _ = strongself._frameRenderingSemaphore.signal()
        }
    }
    
    func createPixelBufferAndBitmapContext( pixelBuffer: inout CVPixelBuffer?) -> CGContext? {
        guard let bufferPool = self._outputBufferPool else {
            return nil
        }
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault,
                                           bufferPool, &pixelBuffer)
        if let pixelBuffer = pixelBuffer {
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        }
        guard let buffer = pixelBuffer else {
            return nil
        }
        guard let colorSpec = _rgbColorSpace else {
            return nil
        }
        let bimapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
            .union(CGBitmapInfo.byteOrder32Little)
        var bitmapContext: CGContext?
        bitmapContext = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                  width: CVPixelBufferGetWidth(buffer),
                                  height: CVPixelBufferGetHeight(buffer),
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: colorSpec,
                                  bitmapInfo: bimapInfo.rawValue)
        bitmapContext?.scaleBy(x: _scale, y: _scale)
        let flipVertical = CGAffineTransform(a: 1,
                                             b: 0,
                                             c: 0,
                                             d: -1,
                                             tx: 0,
                                             ty: _viewSize.height)
        bitmapContext?.concatenate(flipVertical)
        return bitmapContext
    }
}
