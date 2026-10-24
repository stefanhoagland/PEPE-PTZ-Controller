import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Live video from a Panasonic camera's built-in JPEG output.
///
/// JPEG streaming must be turned on in the camera's web settings
/// (Video over IP). The AW-UE160 offers JPEG streams 1 to 3.
public enum PanasonicVideo {
    /// The Motion JPEG stream, for example `http://192.168.0.10/cgi-bin/mjpeg?stream=1`.
    public static func mjpegURL(baseURL: URL, stream: Int = 1) -> URL? {
        url(baseURL: baseURL, cgi: "mjpeg", query: "stream=\(stream)")
    }

    /// A single JPEG picture, used when the stream isn't available.
    public static func snapshotURL(baseURL: URL, resolution: Int = 640) -> URL? {
        url(baseURL: baseURL, cgi: "camera", query: "resolution=\(resolution)")
    }

    private static func url(baseURL: URL, cgi: String, query: String) -> URL? {
        let endpoint = baseURL.appendingPathComponent("cgi-bin").appendingPathComponent(cgi)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else { return nil }
        components.percentEncodedQuery = query
        return components.url
    }

    /// JPEG frames from the camera's Motion JPEG stream, newest first if decoding falls behind.
    public static func mjpegFrames(url: URL, username: String, password: String) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(2)) { continuation in
            let reader = MJPEGStreamReader(username: username, password: password, continuation: continuation)
            let configuration = URLSessionConfiguration.ephemeral
            // How long to wait with no data before giving up.
            configuration.timeoutIntervalForRequest = 10
            configuration.timeoutIntervalForResource = .infinity
            let session = URLSession(configuration: configuration, delegate: reader, delegateQueue: nil)
            let task = session.dataTask(with: url)
            continuation.onTermination = { _ in
                task.cancel()
                session.invalidateAndCancel()
            }
            task.resume()
        }
    }

    /// JPEG frames made by asking the camera for a new picture over and over.
    public static func snapshotFrames(
        url: URL, username: String, password: String, interval: TimeInterval = 0.5
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 5
                let session = URLSession(
                    configuration: configuration,
                    delegate: CameraLoginDelegate(username: username, password: password),
                    delegateQueue: nil
                )
                defer { session.invalidateAndCancel() }
                do {
                    while !Task.isCancelled {
                        let (data, response) = try await session.data(from: url)
                        try PTZError.check(httpResponse: response)
                        if data.starts(with: [0xFF, 0xD8]) {
                            continuation.yield(data)
                        } else {
                            // Usually an error page instead of a picture.
                            _ = try PTZError.check(response: String(decoding: data.prefix(200), as: UTF8.self))
                        }
                        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Receives the Motion JPEG stream bit by bit and passes out whole frames.
/// URLSession calls it on one serial queue, so the parser needs no locking.
final class MJPEGStreamReader: CameraLoginDelegate, URLSessionDataDelegate {
    private var parser = MJPEGParser()
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation

    init(username: String, password: String, continuation: AsyncThrowingStream<Data, Error>.Continuation) {
        self.continuation = continuation
        super.init(username: username, password: password)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        do {
            try PTZError.check(httpResponse: response)
            completionHandler(.allow)
        } catch {
            continuation.finish(throwing: error)
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        for frame in parser.append(data) {
            continuation.yield(frame)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        continuation.finish(throwing: error ?? PTZError.streamEnded)
    }
}
