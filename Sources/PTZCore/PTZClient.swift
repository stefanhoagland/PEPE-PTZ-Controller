import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Sends commands to one camera and returns its reply text.
public protocol PTZClient: Sendable {
    func send(_ command: PanasonicCommand) async throws -> String
}

/// Talks to a real Panasonic camera over HTTP. Handles basic and digest login.
///
/// Each command uses a fresh connection. Panasonic cameras' built-in web servers
/// can drop kept-alive connections without saying so, which makes the next
/// command on that connection hang until it times out.
public final class PanasonicHTTPClient: PTZClient, @unchecked Sendable {
    private let baseURL: URL
    private let username: String
    private let password: String
    private let timeout: TimeInterval

    public init(baseURL: URL, username: String, password: String, timeout: TimeInterval = 5) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        self.timeout = timeout
    }

    public func send(_ command: PanasonicCommand) async throws -> String {
        guard let url = command.url(baseURL: baseURL) else { throw PTZError.noAddress }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 1
        let session = URLSession(
            configuration: configuration,
            delegate: CameraLoginDelegate(username: username, password: password),
            delegateQueue: nil
        )
        // Cancelling also closes the connection if the camera never finishes its reply.
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: url)
        request.setValue("close", forHTTPHeaderField: "Connection")

        // Wait for the camera to accept the command (its HTTP headers), then read the
        // short reply for a moment. Some Panasonic firmware keeps the reply open
        // without ending it, so waiting for the end would delay the next command,
        // such as the stop when you let go of a button.
        let (bytes, response) = try await session.bytes(for: request)
        try PTZError.check(httpResponse: response)
        let reply = await Self.readReply(bytes, window: replyWindow)
        return try PTZError.check(response: reply)
    }

    /// How long to keep reading a reply after the camera starts answering.
    private let replyWindow: TimeInterval = 0.3

    private static func readReply(_ bytes: URLSession.AsyncBytes, window: TimeInterval, limit: Int = 256) async -> String {
        let box = ReplyBuffer()
        let reader = Task {
            do {
                for try await byte in bytes {
                    box.append(byte)
                    if box.count >= limit { break }
                }
            } catch {
                // Cancelled after the window, or the connection closed. Use what arrived.
            }
        }
        let timer = Task {
            try? await Task.sleep(nanoseconds: UInt64(window * 1_000_000_000))
            reader.cancel()
        }
        await reader.value
        timer.cancel()
        return String(decoding: box.bytes, as: UTF8.self)
    }
}

/// Collects reply bytes from one task while another may read them.
private final class ReplyBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UInt8] = []

    func append(_ byte: UInt8) {
        lock.lock(); storage.append(byte); lock.unlock()
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }; return storage.count
    }

    var bytes: [UInt8] {
        lock.lock(); defer { lock.unlock() }; return storage
    }
}

/// Answers the camera's login challenge once, then gives up so a wrong
/// password fails fast instead of looping.
class CameraLoginDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let username: String
    let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let method = challenge.protectionSpace.authenticationMethod
        let isLogin = method == NSURLAuthenticationMethodHTTPBasic
            || method == NSURLAuthenticationMethodHTTPDigest
            || method == NSURLAuthenticationMethodDefault
        guard isLogin, challenge.previousFailureCount == 0, !username.isEmpty else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(user: username, password: password, persistence: .forSession))
    }
}
