import Vision
import AVFoundation
import UIKit

extension ViewController {
    
    func setupDetector(modelName: String) -> [VNRequest] {
        let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc")

        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL!))

            let completionHandler: VNRequestCompletionHandler = { [weak self] request, error in
//                if modelName == "yolov7" {
//                    self?.detectionDidComplete(request: request, error: error, layer: (self?.yolov7DetectionLayer)!, modelName: modelName)
//                } else if modelName == "doors_4062023" {
//                    self?.detectionDidComplete(request: request, error: error, layer: (self?.doorsModelDetectionLayer)!, modelName: modelName)
//                } else {
//                self?.detectionDidComplete(request: request, error: error, layer: (self?.bestModelDetectionLayer)!, modelName: modelName)
//                }
                self?.detectionDidComplete(request: request, error: error, layer: (self?.yolov7DetectionLayer)!, modelName: modelName)
            }

            let recognitions = VNCoreMLRequest(model: visionModel, completionHandler: completionHandler)
            return [recognitions]
        } catch let error {
            print(error)
            return []
        }
    }
    
    func detectionDidComplete(request: VNRequest, error: Error?, layer: CALayer, modelName: String) {
        DispatchQueue.main.async(execute: {
            if let results = request.results {
                self.extractDetections(results, layer: layer, modelName: modelName)
            }
        })
    }
    
    func rotateImageCCW(image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContext(CGSize(width: image.size.height, height: image.size.width))
        let context = UIGraphicsGetCurrentContext()!
        context.rotate(by: -.pi/2)
        image.draw(at: CGPoint(x: -image.size.width, y: 0))
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage
    }
    
    func rotateImageCW(image: UIImage) -> UIImage? {
        UIGraphicsBeginImageContext(CGSize(width: image.size.height, height: image.size.width))
        let context = UIGraphicsGetCurrentContext()!
        context.rotate(by: .pi/2)
        image.draw(at: CGPoint(x: 0, y: -image.size.height))
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage
    }
    
    func rotateRect(rect: CGRect, within size: CGSize) -> CGRect {
        let origin = CGPoint(x: rect.minY, y: size.width - rect.maxX)
        return CGRect(origin: origin, size: CGSize(width: rect.height, height: rect.width))
    }

    func extractDetections(_ results: [VNObservation], layer: CALayer, modelName: String) {
        layer.sublayers = nil
        var objects: [[String: Any]] = []

        for observation in results where observation is VNRecognizedObjectObservation {
            print("observation")
            guard let objectObservation = observation as? VNRecognizedObjectObservation else { continue }

            // Filter detections below the confidence threshold
            if objectObservation.confidence < Float(previewState.confidenceThreshold) {
                continue
            }

            // Transformations
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(screenRect.size.width), Int(screenRect.size.height))
            print("id:\(objectObservation.labels[0].identifier) confidence:\(objectObservation.confidence) (\(round(objectBounds.minX)), \(round(objectBounds.minY))), (\(round(objectBounds.maxX)), \(round(objectBounds.maxY)))")
            let transformedBounds = CGRect(x: objectBounds.minX, y: screenRect.size.height - objectBounds.maxY, width: objectBounds.maxX - objectBounds.minX, height: objectBounds.maxY - objectBounds.minY)
            
//            let rotatedBounds = rotateRect(rect: transformedBounds, within: screenRect.size)

            let boxLayer = self.drawBoundingBox(transformedBounds)
            
//            let boxLayer = self.drawBoundingBox(rotatedBounds)


            layer.addSublayer(boxLayer)

            // Draw text label with confidence level
            let labelText = "\(objectObservation.labels[0].identifier) \(String(format: "%.2f", objectObservation.confidence))"
            let textLayer = self.drawTextLayer(bounds: transformedBounds, labelText: labelText)
            layer.addSublayer(textLayer)
            
            // Put data into json object to send to webview
            let jsonObject: [String: Any] = [
                "x": transformedBounds.origin.x,
                "y": transformedBounds.origin.y,
//                "x": rotatedBounds.origin.x,
//                "y": rotatedBounds.origin.y,
                "screenWidth": screenRect.size.width,
                "screenHeight": screenRect.size.height,
                "objectHeight": objectBounds.height,
                "objectWidth": objectBounds.width,
                "name": objectObservation.labels[0].identifier,
                "confidence": objectObservation.confidence,
            ]
            objects.append(jsonObject)
        }
//        if !objects.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    if let base64ImageString = self?.previewState.base64ImageString {
                        let jsonObject: [String: Any] = [
                            "detectedObjects": objects,
                            "base64ImageString": base64ImageString,
                            "model": modelName,
                        ]
                        self?.previewState.detectedObjects = jsonObject
                        // Send JSON object to webView
                    }
                }
//            }
    }

    func setupLayers() {
        yolov7DetectionLayer = CALayer()
        yolov7DetectionLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)

//        bestModelDetectionLayer = CALayer()
//        bestModelDetectionLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
//
//        doorsModelDetectionLayer = CALayer()
//        doorsModelDetectionLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)

        DispatchQueue.main.async { [weak self] in
            self!.view.layer.addSublayer(self!.yolov7DetectionLayer)
//            self!.view.layer.addSublayer(self!.bestModelDetectionLayer)
//            self!.view.layer.addSublayer(self!.doorsModelDetectionLayer)
        }
    }

    func updateLayers() {
        yolov7DetectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
//        bestModelDetectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
//        doorsModelDetectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)

    }

    func drawBoundingBox(_ bounds: CGRect) -> CALayer {
        let boxLayer = CALayer()
        boxLayer.frame = bounds
        boxLayer.borderWidth = 3.0
        boxLayer.borderColor = CGColor.init(red: 255.0, green: 255.0, blue: 255.0, alpha: 1.0)
        boxLayer.cornerRadius = 4
        return boxLayer
    }

    func drawTextLayer(bounds: CGRect, labelText: String) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.string = labelText
        textLayer.fontSize = 11
        textLayer.foregroundColor = UIColor.black.withAlphaComponent(0.6).cgColor
        textLayer.backgroundColor = UIColor.white.cgColor
        textLayer.cornerRadius = 4
        textLayer.frame = CGRect(x: bounds.origin.x, y: bounds.origin.y - 20, width: bounds.size.width, height: 20)
        return textLayer
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Convert pixel buffer to UIImage
        guard let image = pixelBufferToUIImage(pixelBuffer: pixelBuffer) else { return }

        // Rotate the image before sending to the model
        guard let rotatedImageForModel = rotateImageCCW(image: image) else { return }
        
        // Prepare the image for the model
        guard let rotatedPixelBuffer = pixelBufferFrom(uiImage: rotatedImageForModel) else { return }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: rotatedPixelBuffer, orientation: .up, options: [:])

        // Convert the rotated image back to the original orientation and then to base64 encoded string
        if let originalOrientationImage = rotateImageCW(image: rotatedImageForModel),
           let base64ImageString = imageToBase64(image: originalOrientationImage) {
            DispatchQueue.main.async { [weak self] in
                self?.previewState.base64ImageString = base64ImageString
            }
        }

        for (modelName, isEnabled) in previewState.models {
            if isEnabled {
                do {
                    try imageRequestHandler.perform(self.requests[modelName]!)
                } catch {
                    print(error)
                }
            } else {
                let layer = yolov7DetectionLayer
                DispatchQueue.main.async {
                    layer?.sublayers = nil
                }
            }
        }
    }

    func pixelBufferFrom(uiImage: UIImage) -> CVPixelBuffer? {
        let ciImage = CIImage(image: uiImage)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage!, from: ciImage!.extent) else { return nil }

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]

        var pxbuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, cgImage.width, cgImage.height, kCVPixelFormatType_32ARGB, pixelBufferAttributes as CFDictionary, &pxbuffer)
        guard status == kCVReturnSuccess else { return nil }

        CVPixelBufferLockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pxdata = CVPixelBufferGetBaseAddress(pxbuffer!)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pxdata, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pxbuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        CVPixelBufferUnlockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pxbuffer
    }


    
    func pixelBufferToUIImage(pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let image = UIImage(cgImage: cgImage)
            return image
        }
        return nil
    }

    
    func imageToBase64(image: UIImage) -> String? {
        let imageData = image.jpegData(compressionQuality: 0.5)
        return imageData?.base64EncodedString()
    }

    
    
}
