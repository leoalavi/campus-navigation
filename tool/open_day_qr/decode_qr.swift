import AppKit
import Foundation
import Vision

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: decode_qr.swift IMAGE\n".utf8))
    exit(64)
}

let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let image = NSImage(contentsOf: imageURL),
      let imageData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: imageData),
      let cgImage = bitmap.cgImage else {
    FileHandle.standardError.write(Data("unable to decode image\n".utf8))
    exit(65)
}

let request = VNDetectBarcodesRequest()
request.symbologies = [.qr]
let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

do {
    try handler.perform([request])
} catch {
    FileHandle.standardError.write(Data("barcode detection failed\n".utf8))
    exit(66)
}

let payloads = (request.results ?? [])
    .compactMap(\.payloadStringValue)
    .sorted()
for payload in payloads {
    print(payload)
}
if payloads.isEmpty {
    exit(1)
}
