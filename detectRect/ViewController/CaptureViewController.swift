//
//  ViewController.swift
//  ekycProto
//
//  Created by osu on 2018/11/03.
//  Copyright © 2018 osu. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class CaptureViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var imageViewCapture: UIImageView!
    
    private var sessionInstance: FactorySessionInstance? = nil
    private let storeImage = Store<UIImage>(label: "storeDriverLicense")
    private let queueImageProcess = DispatchQueue(label: "imageProcess")
    private var rectLayer: [CAShapeLayer] = []
    private var imageViewCaptureBounds: CGRect!

    override func viewDidLoad() {
        super.viewDidLoad()

        createSessionInstance()
    }

    override func viewDidAppear(_ animated: Bool) {
        sessionInstance?.session.startRunning()
        imageViewCaptureBounds = imageViewCapture.bounds
    }

}

extension CaptureViewController {

    private func createSessionInstance() {
        let result = FactorySession.create()
        guard case Result<FactorySessionInstance, FactorySessionError>.success(let instance) = result else {
            return
        }

        sessionInstance = instance
        instance.output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "xgjwaifeyd"))

        // ouputの向きを縦向きに
        for connection in sessionInstance!.output.connections {
            guard connection.isVideoOrientationSupported == true else {
                continue
            }
            connection.videoOrientation = .portrait
        }
    }

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        // 撮影画面の更新
        guard let image = sampleBuffer.toImage(mirrored: false) else {
            return
        }
        
        DispatchQueue.main.async {
            self.imageViewCapture.image = image
        }

        // 顔検出中の画像の有無を確認
        guard storeImage.get() == nil else {
            return
        }
        storeImage.set(image)
        
        // 矩形検出
        queueImageProcess.async {
            self.detectDriverLicense()
        }
    }

    private func detectDriverLicense() {
        guard
        let image = storeImage.get(),
        let cgImage = image.cgImage else {
            self.storeImage.set(nil)
            return
        }

        // 検出した矩形をマーク
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation.up, options: [:])
        let request = VNDetectRectanglesRequest(completionHandler: {(request, error) in
            let layers: [CAShapeLayer]
            guard let results = request.results else {
                layers = []
                return
            }

            layers = results.map { result -> CAShapeLayer in
                let observation = result as! VNRectangleObservation

                // 座標系の変換、CoreGraphic準拠の座標からUIの座標系に
                let topLeft = CGPoint(x: self.imageViewCaptureBounds.width * observation.topLeft.x, y: self.imageViewCaptureBounds.height - self.imageViewCaptureBounds.height * observation.topLeft.y)
                let topRight = CGPoint(x: self.imageViewCaptureBounds.width * observation.topRight.x, y: self.imageViewCaptureBounds.height - self.imageViewCaptureBounds.height * observation.topRight.y)
                let bottomLeft = CGPoint(x: self.imageViewCaptureBounds.width * observation.bottomLeft.x, y: self.imageViewCaptureBounds.height - self.imageViewCaptureBounds.height * observation.bottomLeft.y)
                let bottomRight = CGPoint(x: self.imageViewCaptureBounds.width * observation.bottomRight.x, y: self.imageViewCaptureBounds.height - self.imageViewCaptureBounds.height * observation.bottomRight.y)

                let path = UIBezierPath()
                path.move(to: topLeft)
                path.addLine(to: topRight)
                path.addLine(to: bottomRight)
                path.addLine(to: bottomLeft)
                path.close()

                let layer = CAShapeLayer()
                layer.path = path.cgPath
                layer.strokeColor = #colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1)
                layer.fillColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0)
                layer.lineWidth = 2
                layer.frame = observation.boundingBox

                return layer
            }

            DispatchQueue.main.async {
                self.rectLayer.forEach { $0.removeFromSuperlayer() }
                self.rectLayer = layers.map { l -> CAShapeLayer in
                    self.imageViewCapture.layer.addSublayer(l)
                    return l
                }
            }

            self.storeImage.set(nil)
        })

        try! handler.perform([request])
    }

}
