import Foundation

/// Splits a Motion JPEG byte stream into individual JPEG frames.
///
/// It looks for the JPEG start (FF D8) and end (FF D9) markers, so it works
/// whatever multipart boundary or headers the camera puts between frames.
public struct MJPEGParser: Sendable {
    private static let startMarker = Data([0xFF, 0xD8])
    private static let endMarker = Data([0xFF, 0xD9])

    private var buffer = Data()
    /// If a frame grows past this without ending, the buffer is dropped.
    public var maxBufferSize: Int

    public init(maxBufferSize: Int = 8 * 1024 * 1024) {
        self.maxBufferSize = maxBufferSize
    }

    /// Adds newly received bytes and returns any frames they completed.
    public mutating func append(_ data: Data) -> [Data] {
        buffer.append(data)
        var frames: [Data] = []

        while true {
            guard let start = buffer.range(of: Self.startMarker) else {
                // Keep a trailing FF in case a start marker is split across chunks.
                buffer = buffer.last == 0xFF ? Data([0xFF]) : Data()
                break
            }
            guard let end = buffer.range(of: Self.endMarker, in: start.upperBound..<buffer.endIndex) else {
                // Frame not finished yet. Drop anything before its start.
                if start.lowerBound != buffer.startIndex {
                    buffer = Data(buffer[start.lowerBound...])
                }
                if buffer.count > maxBufferSize { buffer = Data() }
                break
            }
            frames.append(Data(buffer[start.lowerBound..<end.upperBound]))
            buffer = Data(buffer[end.upperBound...])
        }
        return frames
    }
}
