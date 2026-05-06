import AVFoundation
import CoreMedia
import Foundation

struct Options {
    var file: URL?
    var latestDirectory: URL?
    var expectedFormat: String?
    var expectedCodec: String?
    var expectedSize: CGSize?
    var expectedFPS: Double?
    var expectedAudio: Bool?
    var minDuration: Double = 1.0
}

enum ValidationError: Error, CustomStringConvertible {
    case usage(String)
    case fileNotFound(URL)
    case noFilesInDirectory(URL)
    case noVideoTrack(URL)
    case invalidArgument(String)
    case expectationFailed(String)

    var description: String {
        switch self {
        case .usage(let message),
             .invalidArgument(let message),
             .expectationFailed(let message):
            return message
        case .fileNotFound(let url):
            return "Video file not found: \(url.path)"
        case .noFilesInDirectory(let url):
            return "No video files found in directory: \(url.path)"
        case .noVideoTrack(let url):
            return "No video track found in file: \(url.path)"
        }
    }
}

enum ValidateRecordedVideo {
    static func parseOptions(arguments: [String]) throws -> Options {
        var options = Options()
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--file":
                index += 1
                options.file = URL(fileURLWithPath: try value(after: argument, at: index, in: arguments))
            case "--latest-in":
                index += 1
                options.latestDirectory = URL(fileURLWithPath: try value(after: argument, at: index, in: arguments))
            case "--format":
                index += 1
                options.expectedFormat = try value(after: argument, at: index, in: arguments).uppercased()
            case "--codec":
                index += 1
                options.expectedCodec = normalizeCodec(try value(after: argument, at: index, in: arguments))
            case "--size":
                index += 1
                options.expectedSize = try parseSize(try value(after: argument, at: index, in: arguments))
            case "--fps":
                index += 1
                let fpsString = try value(after: argument, at: index, in: arguments)
                guard let fps = Double(fpsString), fps > 0 else {
                    throw ValidationError.invalidArgument("Invalid fps value: \(fpsString)")
                }
                options.expectedFPS = fps
            case "--audio":
                index += 1
                let audioValue = try value(after: argument, at: index, in: arguments).lowercased()
                switch audioValue {
                case "on", "true", "yes":
                    options.expectedAudio = true
                case "off", "false", "no":
                    options.expectedAudio = false
                default:
                    throw ValidationError.invalidArgument("Invalid audio value: \(audioValue). Use on/off.")
                }
            case "--min-duration":
                index += 1
                let durationString = try value(after: argument, at: index, in: arguments)
                guard let duration = Double(durationString), duration >= 0 else {
                    throw ValidationError.invalidArgument("Invalid min-duration value: \(durationString)")
                }
                options.minDuration = duration
            case "--help", "-h":
                throw ValidationError.usage("")
            default:
                throw ValidationError.invalidArgument("Unknown argument: \(argument)")
            }

            index += 1
        }

        guard options.file != nil || options.latestDirectory != nil else {
            throw ValidationError.usage("Provide either --file or --latest-in.")
        }

        return options
    }

    private static func value(after flag: String, at index: Int, in arguments: [String]) throws -> String {
        guard index < arguments.count else {
            throw ValidationError.invalidArgument("Missing value after \(flag)")
        }
        return arguments[index]
    }

    private static func parseSize(_ rawValue: String) throws -> CGSize {
        let components = rawValue.lowercased().split(separator: "x")
        guard components.count == 2,
              let width = Double(components[0]),
              let height = Double(components[1]),
              width > 0,
              height > 0
        else {
            throw ValidationError.invalidArgument("Invalid size value: \(rawValue). Use WIDTHxHEIGHT.")
        }

        return CGSize(width: width, height: height)
    }

    private static func normalizeCodec(_ rawValue: String) -> String {
        switch rawValue.uppercased() {
        case "H264", "H.264":
            return "H264"
        case "H265", "H.265", "HEVC":
            return "HEVC"
        default:
            return rawValue.uppercased()
        }
    }

    static func resolvedFileURL(from options: Options) throws -> URL {
        if let file = options.file {
            guard FileManager.default.fileExists(atPath: file.path) else {
                throw ValidationError.fileNotFound(file)
            }
            return file
        }

        guard let directory = options.latestDirectory else {
            throw ValidationError.usage("Provide either --file or --latest-in.")
        }

        let fileManager = FileManager.default
        let candidates = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return false
            }

            let ext = url.pathExtension.lowercased()
            return ext == "mp4" || ext == "mov"
        }
        .sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        guard let latest = candidates.first else {
            throw ValidationError.noFilesInDirectory(directory)
        }

        return latest
    }

    static func loadMetadata(for fileURL: URL) async throws -> VideoMetadata {
        let asset = AVURLAsset(url: fileURL)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw ValidationError.noVideoTrack(fileURL)
        }

        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let formatDescriptions = try await videoTrack.load(.formatDescriptions)
        let duration = try await asset.load(.duration)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)

        guard let formatDescription = formatDescriptions.first else {
            throw ValidationError.noVideoTrack(fileURL)
        }

        let transformedSize = naturalSize.applying(preferredTransform)
        let size = CGSize(
            width: abs(transformedSize.width).rounded(),
            height: abs(transformedSize.height).rounded()
        )

        return VideoMetadata(
            container: fileURL.pathExtension.uppercased(),
            codec: codecName(for: CMFormatDescriptionGetMediaSubType(formatDescription)),
            size: size,
            nominalFrameRate: Double(nominalFrameRate),
            duration: duration.seconds,
            hasAudioTrack: !audioTracks.isEmpty
        )
    }

    private static func codecName(for codec: CMVideoCodecType) -> String {
        switch codec {
        case kCMVideoCodecType_H264:
            return "H264"
        case kCMVideoCodecType_HEVC:
            return "HEVC"
        default:
            return fourCharacterCode(codec)
        }
    }

    private static func fourCharacterCode(_ value: FourCharCode) -> String {
        let bytes: [CChar] = [
            CChar((value >> 24) & 0xff),
            CChar((value >> 16) & 0xff),
            CChar((value >> 8) & 0xff),
            CChar(value & 0xff),
            0
        ]
        return String(cString: bytes)
    }

    static func validate(metadata: VideoMetadata, against options: Options) throws {
        if let expectedFormat = options.expectedFormat,
           metadata.container != expectedFormat {
            throw ValidationError.expectationFailed(
                "Expected format \(expectedFormat), got \(metadata.container)"
            )
        }

        if let expectedCodec = options.expectedCodec,
           metadata.codec != expectedCodec {
            throw ValidationError.expectationFailed(
                "Expected codec \(expectedCodec), got \(metadata.codec)"
            )
        }

        if let expectedSize = options.expectedSize,
           metadata.size != expectedSize {
            throw ValidationError.expectationFailed(
                "Expected size \(Int(expectedSize.width))x\(Int(expectedSize.height)), got \(Int(metadata.size.width))x\(Int(metadata.size.height))"
            )
        }

        if let expectedFPS = options.expectedFPS,
           abs(metadata.nominalFrameRate - expectedFPS) > 1.0 {
            throw ValidationError.expectationFailed(
                "Expected FPS around \(expectedFPS), got \(metadata.nominalFrameRate)"
            )
        }

        if let expectedAudio = options.expectedAudio,
           metadata.hasAudioTrack != expectedAudio {
            throw ValidationError.expectationFailed(
                "Expected audio track \(expectedAudio ? "on" : "off"), got \(metadata.hasAudioTrack ? "on" : "off")"
            )
        }

        if metadata.duration < options.minDuration {
            throw ValidationError.expectationFailed(
                "Expected duration >= \(options.minDuration)s, got \(metadata.duration)s"
            )
        }
    }

    static func printSummary(metadata: VideoMetadata, fileURL: URL) {
        print("Validation passed for \(fileURL.path)")
        print("Container: \(metadata.container)")
        print("Codec: \(metadata.codec)")
        print("Size: \(Int(metadata.size.width))x\(Int(metadata.size.height))")
        print(String(format: "FPS: %.2f", metadata.nominalFrameRate))
        print(String(format: "Duration: %.2fs", metadata.duration))
        print("Audio track: \(metadata.hasAudioTrack ? "present" : "absent")")
    }

    static func printUsage() {
        let usage = """
        Usage:
          swift scripts/validate_recorded_video.swift --file /path/to/video.mp4 [expectations]
          swift scripts/validate_recorded_video.swift --latest-in /path/to/folder [expectations]

        Expectations:
          --format MP4|MOV
          --codec H264|HEVC
          --size 1280x720
          --fps 30
          --audio on|off
          --min-duration 1.0
        """
        print(usage)
    }
}

struct VideoMetadata {
    let container: String
    let codec: String
    let size: CGSize
    let nominalFrameRate: Double
    let duration: Double
    let hasAudioTrack: Bool
}

let semaphore = DispatchSemaphore(value: 0)
var exitCode = EXIT_SUCCESS

do {
    let options = try ValidateRecordedVideo.parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))

    Task {
        defer { semaphore.signal() }

        do {
            let fileURL = try ValidateRecordedVideo.resolvedFileURL(from: options)
            let metadata = try await ValidateRecordedVideo.loadMetadata(for: fileURL)
            try ValidateRecordedVideo.validate(metadata: metadata, against: options)
            ValidateRecordedVideo.printSummary(metadata: metadata, fileURL: fileURL)
        } catch let error as ValidationError {
            exitCode = EXIT_FAILURE
            fputs("Validation failed: \(error.description)\n", stderr)
            ValidateRecordedVideo.printUsage()
        } catch {
            exitCode = EXIT_FAILURE
            fputs("Validation failed: \(error)\n", stderr)
        }
    }
} catch let error as ValidationError {
    exitCode = EXIT_FAILURE
    fputs("Validation failed: \(error.description)\n", stderr)
    ValidateRecordedVideo.printUsage()
    semaphore.signal()
} catch {
    exitCode = EXIT_FAILURE
    fputs("Validation failed: \(error)\n", stderr)
    semaphore.signal()
}

semaphore.wait()
exit(exitCode)
