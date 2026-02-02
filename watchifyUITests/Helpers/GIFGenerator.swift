//
//  GIFGenerator.swift
//  watchifyUITests
//
//  Assembles PNG images into an animated GIF using ImageIO.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

enum GIFGenerator {

    /// Creates an animated GIF from a list of PNG image file URLs.
    /// - Parameters:
    ///   - imagePaths: Ordered URLs of PNG frame images
    ///   - outputPath: Destination URL for the animated GIF
    ///   - frameDelay: Seconds each frame is displayed (default 1.5s)
    /// - Throws: If images can't be read or GIF can't be written
    static func createGIF(
        from imagePaths: [URL],
        outputPath: URL,
        frameDelay: Double = 1.5
    ) throws {
        guard !imagePaths.isEmpty else {
            throw GIFError.noFrames
        }

        guard let destination = CGImageDestinationCreateWithURL(
            outputPath as CFURL,
            UTType.gif.identifier as CFString,
            imagePaths.count,
            nil
        ) else {
            throw GIFError.cannotCreateDestination
        }

        // GIF-level properties: loop forever
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        // Frame-level properties
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay
            ]
        ]

        for imageURL in imagePaths {
            guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                throw GIFError.cannotReadFrame(imageURL.lastPathComponent)
            }
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw GIFError.finalizeFailed
        }
    }
}

enum GIFError: LocalizedError {
    case noFrames
    case cannotCreateDestination
    case cannotReadFrame(String)
    case finalizeFailed

    var errorDescription: String? {
        switch self {
        case .noFrames:
            "No frame images provided"
        case .cannotCreateDestination:
            "Could not create GIF destination"
        case .cannotReadFrame(let name):
            "Could not read frame image: \(name)"
        case .finalizeFailed:
            "Failed to finalize GIF file"
        }
    }
}
