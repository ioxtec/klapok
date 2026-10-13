import Foundation
@preconcurrency import AVFoundation

enum VideoAudioWaveform {
    static func samples(from url: URL) async -> [Float] {
        await Task.detached(priority: .utility) {
            do {
                let asset = AVURLAsset(url: url)
                guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return [] }
                let reader = try AVAssetReader(asset: asset)
                let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMIsFloatKey: true,
                    AVLinearPCMBitDepthKey: 32, AVLinearPCMIsNonInterleaved: false,
                    AVSampleRateKey: 8000, AVNumberOfChannelsKey: 1
                ])
                guard reader.canAdd(output) else { return [] }
                reader.add(output)
                guard reader.startReading() else { return [] }
                var result: [Float] = []
                var peak: Float = 0
                var sampleCount = 0
                while let buffer = output.copyNextSampleBuffer() {
                    guard !Task.isCancelled else { reader.cancelReading(); return [] }
                    guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
                    let length = CMBlockBufferGetDataLength(block)
                    var values = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
                    let status = values.withUnsafeMutableBytes {
                        CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!)
                    }
                    guard status == kCMBlockBufferNoErr else { continue }
                    for value in values {
                        peak = max(peak, min(1, abs(value)))
                        sampleCount += 1
                        if sampleCount == 800 { result.append(peak); peak = 0; sampleCount = 0 }
                    }
                }
                if sampleCount > 0 { result.append(peak) }
                return result
            } catch { return [] }
        }.value
    }
}
