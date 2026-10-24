import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Sends commands to one camera and returns its reply text.
public protocol PTZClient: Sendable {
    func send(_ command: PanasonicCommand) async throws -> String
}

/// Talks to a real Panasonic camera over HTTP. Handles basic and digest login.
public final class PanasonicHTTPClient: PTZClient, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, username: String, password: String, timeout: TimeInterval = 3) {
        self.baseURL = baseURL
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let delegate = CameraLoginDelegate(username: username, password: password)
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    public func send(_ command: PanasonicCommand) async throws -> String {
        guard let url = command.url(baseURL: baseURL) else { throw PTZError.noAddress }
        let (data, response) = try await session.data(from: url)
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
