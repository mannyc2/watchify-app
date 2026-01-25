//
//  ImageServiceTests.swift
//  watchifyTests
//

import AppKit
import Testing
import Vision
@testable import watchify

@Suite("ImageService")
struct ImageServiceTests {

    @Suite("SalientCropProcessor")
    struct SalientCropProcessorTests {

        @Test("Identifier is deterministic for same size")
        func identifierIsDeterministic() {
            let size = CGSize(width: 360, height: 360)
            let processor = SalientCropProcessor(targetSize: size)

            #expect(processor.identifier == "com.watchify.salient/360x360")
        }

        @Test("Store preview uses salient crop processor")
        func storePreviewUsesSalientCrop() {
            let processors = ImageService.processors(for: .storePreview)

            #expect(processors.count == 1)
            #expect(processors.first is SalientCropProcessor)
        }

        @Test("Product card uses standard resize")
        func productCardUsesResize() {
            let processors = ImageService.processors(for: .productCard)

            #expect(processors.count == 1)
            #expect(!(processors.first is SalientCropProcessor))
        }
    }

    @Suite("Saliency Debug")
    struct SaliencyDebugTests {

        /// Computes saliency rect for a CGImage - mirrors the processor's logic
        private func computeSalientRect(for cgImage: CGImage) -> CGRect {
            let request = VNGenerateAttentionBasedSaliencyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
                if let observation = request.results?.first,
                   let salientRect = observation.salientObjects?.first?.boundingBox {
                    // Vision returns normalized coordinates (0-1) with origin at bottom-left
                    // Convert to top-left origin for CoreGraphics
                    return CGRect(
                        x: salientRect.origin.x,
                        y: 1 - salientRect.origin.y - salientRect.height,
                        width: salientRect.width,
                        height: salientRect.height
                    )
                }
            } catch {
                print("Saliency error: \(error)")
            }

            return CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        }

        @Test("Debug: Saliency on solid color returns center")
        func solidColorReturnsCenterCrop() {
            // Create a solid color image - no salient region expected
            let size = CGSize(width: 400, height: 400)
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.gray.setFill()
            NSRect(origin: .zero, size: size).fill()
            image.unlockFocus()

            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                Issue.record("Failed to create CGImage")
                return
            }

            let rect = computeSalientRect(for: cgImage)
            print("Solid color saliency rect: \(rect)")

            // Should fall back to center crop or return a very large rect
            // (Vision may return the whole image as salient for uniform images)
        }

        @Test("Debug: Saliency on image with bright spot")
        func brightSpotIsSalient() {
            // Create image with a bright spot in top-right
            let size = CGSize(width: 400, height: 400)
            let image = NSImage(size: size)
            image.lockFocus()

            // Dark background
            NSColor.darkGray.setFill()
            NSRect(origin: .zero, size: size).fill()

            // Bright spot in top-right quadrant
            NSColor.white.setFill()
            let spotRect = NSRect(x: 280, y: 280, width: 80, height: 80)
            NSBezierPath(ovalIn: spotRect).fill()

            image.unlockFocus()

            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                Issue.record("Failed to create CGImage")
                return
            }

            let rect = computeSalientRect(for: cgImage)
            print("Bright spot saliency rect: \(rect)")
            print("  - Center X: \(rect.midX), Center Y: \(rect.midY)")

            // The salient region should be biased toward top-right where the bright spot is
            // Note: rect.midY uses top-left origin, so top-right = high X, low Y
            #expect(rect.midX > 0.5, "Expected salient center X > 0.5 (right side)")
        }

        @Test("Debug: Log saliency for test image URL")
        func logSaliencyForURL() async throws {
            // Test with a known product image URL - use a reliable CDN image
            let testURL = URL(string: "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800")!

            let (data, _) = try await URLSession.shared.data(from: testURL)
            guard let nsImage = NSImage(data: data),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                Issue.record("Failed to load image from URL")
                return
            }

            let rect = computeSalientRect(for: cgImage)

            // Calculate pixel coordinates
            let pixelX = Int(rect.origin.x * CGFloat(cgImage.width))
            let pixelY = Int(rect.origin.y * CGFloat(cgImage.height))
            let pixelW = Int(rect.width * CGFloat(cgImage.width))
            let pixelH = Int(rect.height * CGFloat(cgImage.height))

            // Use withKnownIssue to log values without failing
            let ox = String(format: "%.3f", rect.origin.x)
            let oy = String(format: "%.3f", rect.origin.y)
            let rw = String(format: "%.3f", rect.width)
            let rh = String(format: "%.3f", rect.height)
            let cx = String(format: "%.3f", rect.midX)
            let cy = String(format: "%.3f", rect.midY)

            withKnownIssue("Logging saliency values for debugging") {
                Issue.record("""
                    Image: \(cgImage.width)x\(cgImage.height)
                    Saliency rect (normalized): origin=(\(ox), \(oy)) size=\(rw)x\(rh)
                    Saliency rect (pixels): (\(pixelX), \(pixelY), \(pixelW), \(pixelH))
                    Center: (\(cx), \(cy))
                    """)
            }
        }

        @Test("Process actual image through SalientCropProcessor")
        func processActualImage() async throws {
            let testURL = URL(string: "https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800")!

            let (data, _) = try await URLSession.shared.data(from: testURL)
            guard let nsImage = NSImage(data: data) else {
                Issue.record("Failed to load image")
                return
            }

            let targetSize = CGSize(width: 360, height: 360)
            let processor = SalientCropProcessor(targetSize: targetSize)
            let result = processor.process(nsImage)

            #expect(result != nil, "Processor should return an image")

            if let resultImage = result {
                // Log output size
                withKnownIssue("Logging processed image size") {
                    Issue.record("Output size: \(resultImage.size.width)x\(resultImage.size.height)")
                }
                #expect(resultImage.size.width == targetSize.width)
                #expect(resultImage.size.height == targetSize.height)
            }
        }
    }
}
