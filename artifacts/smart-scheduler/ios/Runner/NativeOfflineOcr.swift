import Flutter
import PDFKit
import UIKit
import Vision

final class NativeOfflineOcrPlugin: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.smartscheduler/offline_ocr",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "recognize" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard
            let arguments = call.arguments as? [String: Any],
            let bytes = arguments["bytes"] as? FlutterStandardTypedData
        else {
            result(FlutterError(code: "INVALID_INPUT", message: "OCR input is empty", details: nil))
            return
        }

        let sourceType = arguments["sourceType"] as? String ?? "image"
        DispatchQueue.global(qos: .userInitiated).async {
            if sourceType == "pdf" {
                self.recognizePdf(bytes.data, result: result)
            } else if let image = UIImage(data: bytes.data), let cgImage = image.cgImage {
                self.recognizeImage(cgImage, pageIndex: 0, result: result)
            } else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INVALID_IMAGE", message: "The image could not be decoded", details: nil))
                }
            }
        }
    }

    private func recognizePdf(_ data: Data, result: @escaping FlutterResult) {
        guard let document = PDFDocument(data: data) else {
            finish(result, error: FlutterError(code: "PDF_RENDER", message: "The PDF could not be decoded", details: nil))
            return
        }
        var allBlocks = [[String: Any]]()
        for index in 0..<document.pageCount {
            guard
                let page = document.page(at: index),
                let image = page.thumbnail(
                    of: CGSize(width: 1800, height: 2400),
                    for: .mediaBox
                ).cgImage
            else { continue }
            let semaphore = DispatchSemaphore(value: 0)
            recognizeImage(image, pageIndex: index) { blocks in
                allBlocks.append(contentsOf: blocks)
                semaphore.signal()
            }
            semaphore.wait()
        }
        finish(result, value: response(blocks: allBlocks))
    }

    private func recognizeImage(
        _ image: CGImage,
        pageIndex: Int,
        result: @escaping FlutterResult
    ) {
        recognizeImage(image, pageIndex: pageIndex) { blocks in
            self.finish(result, value: self.response(blocks: blocks))
        }
    }

    private func recognizeImage(
        _ image: CGImage,
        pageIndex: Int,
        completion: @escaping ([[String: Any]]) -> Void
    ) {
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                completion([])
                return
            }
            let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
                .sorted {
                    if abs($0.boundingBox.maxY - $1.boundingBox.maxY) > 0.02 {
                        return $0.boundingBox.maxY > $1.boundingBox.maxY
                    }
                    return $0.boundingBox.minX < $1.boundingBox.minX
                }
            let blocks = observations.enumerated().compactMap { order, observation -> [String: Any]? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let box = observation.boundingBox
                return [
                    "text": candidate.string,
                    "pageIndex": pageIndex,
                    "order": order,
                    "confidence": candidate.confidence,
                    "orientation": 0,
                    "boundingBox": [
                        "left": box.minX,
                        "top": 1 - box.maxY,
                        "width": box.width,
                        "height": box.height,
                    ],
                ]
            }
            completion(blocks)
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.005
        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        } catch {
            completion([])
        }
    }

    private func response(blocks: [[String: Any]]) -> [String: Any] {
        let confidence = blocks.compactMap { $0["confidence"] as? Float }
        return [
            "engine": "Apple Vision",
            "offline": true,
            "orientation": 0,
            "confidence": confidence.isEmpty ? 0.0 : confidence.reduce(0, +) / Float(confidence.count),
            "blocks": blocks,
            "warnings": blocks.isEmpty ? ["No text was recognized"] : [],
        ]
    }

    private func finish(_ result: @escaping FlutterResult, value: Any? = nil, error: FlutterError? = nil) {
        DispatchQueue.main.async {
            if let error {
                result(error)
            } else {
                result(value)
            }
        }
    }
}