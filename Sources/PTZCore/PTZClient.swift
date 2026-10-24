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
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.setValue("close", forHTTPHeaderField: "Connection")

        let (data, response) = try await session.data(for: request)
        try PTZError.check(httpResponse: response)
        return try PTZError.check(response: String(decoding: data, as: UTF8.self))
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
