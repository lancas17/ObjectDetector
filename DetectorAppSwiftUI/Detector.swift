import Vision
import AVFoundation
import UIKit

extension ViewController {
    
    func setupDetector(modelName: String) -> [VNRequest] {
        let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc")

        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL!))

            let completionHandler: VNRequestCompletionHandler = { [weak self] request, error in
                if modelName == "yolov7" {
                self?.detectionDidComplete(request: request, error: error, layer: (self?.yolov7DetectionLayer)!)
                } else if modelName == "doors_4062023" {
                    self?.detectionDidComplete(request: request, error: error, layer: (self?.doorsModelDetectionLayer)!)
                } else {
                self?.detectionDidComplete(request: request, error: error, layer: (self?.bestModelDetectionLayer)!)
                }
            }

            let recognitions = VNCoreMLRequest(model: visionModel, completionHandler: completionHandler)
            return [recognitions]
        } catch let error {
            print(error)
            return []
        }
    }
    
    func detectionDidComplete(request: VNRequest, error: Error?, layer: CALayer) {
        DispatchQueue.main.async(execute: {
            if let results = request.results {
                self.extractDetections(results, layer: layer)
            }
        })
    }

    func extractDetections(_ results: [VNObservation], layer: CALayer) {
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

            let boxLayer = self.drawBoundingBox(transformedBounds)

            layer.addSublayer(boxLayer)

            // Draw text label with confidence level
            let labelText = "\(objectObservation.labels[0].identifier) \(String(format: "%.2f", objectObservation.confidence))"
            let textLayer = self.drawTextLayer(bounds: transformedBounds, labelText: labelText)
            layer.addSublayer(textLayer)
            
            // Put data into json object to send to webview
            let jsonObject: [String: Any] = [
                "x": transformedBounds.origin.x,
                "y": transformedBounds.origin.y,
                "width": transformedBounds.size.width,
                "height": transformedBounds.size.height,
                "name": objectObservation.labels[0].identifier,
                "confidence": objectObservation.confidence
            ]
            objects.append(jsonObject)
        }
        DispatchQueue.main.async { [weak self] in
            self?.previewState.detectedObjects = objects
        }
    }

    func setupLayers() {
        yolov7DetectionLayer = CALayer()
        yolov7DetectionLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)

        bestModelDetectionLayer = CALayer()
        bestModelDetectionLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)

        doorsModelDetectionLayer = CALayer()
        doorsModelDetectionLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)

        DispatchQueue.main.async { [weak self] in
            self!.view.layer.addSublayer(self!.yolov7DetectionLayer)
            self!.view.layer.addSublayer(self!.bestModelDetectionLayer)
            self!.view.layer.addSublayer(self!.doorsModelDetectionLayer)
        }
    }

    func updateLayers() {
        yolov7DetectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        bestModelDetectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        doorsModelDetectionLayer?.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)

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
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        for (modelName, isEnabled) in previewState.models {
            if isEnabled {
                do {
                    try imageRequestHandler.perform(self.requests[modelName]!)
                } catch {
                    print(error)
                }
            } else {
                // Remove bounding boxes when the model is disabled
                let layer: CALayer?
                if modelName == "yolov7" {
                    layer = yolov7DetectionLayer
                } else if modelName == "doors_4062023" {
                    layer = doorsModelDetectionLayer
                } else {
                    layer = bestModelDetectionLayer
                }
                DispatchQueue.main.async {
                    layer?.sublayers = nil
                }
            }
        }
    }
}
