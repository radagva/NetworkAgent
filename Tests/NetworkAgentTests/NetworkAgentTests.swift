import Foundation
import Testing
@testable import NetworkAgent

private struct Post: Codable {
    var userId: Int
    var id: Int
    var title: String
    var body: String
}

private enum Api: NetworkAgentEndpoint {
    case posts
    case post(id: Int)

    var baseURL: URL {
        URL(string: "https://jsonplaceholder.typicode.com")!
    }

    var path: String {
        switch self {
        case .posts: return "/posts"
        case .post(let id): return "/posts/\(id)"
        }
    }

    var method: HTTPMethod { .get }
    var task: HTTPTask { .requestPlain }
}

private actor RequestRecorder {
    private(set) var requests: [URLRequest] = []

    func record(_ request: URLRequest) {
        requests.append(request)
    }
}

private actor EventLog {
    private(set) var events: [String] = []

    func append(_ event: String) {
        events.append(event)
    }
}

@Suite("NetworkAgentProvider request")
struct NetworkAgentProviderTests {

    fileprivate let provider = NetworkAgentProvider<Api>()

    @Test("returns a (Data, URLResponse) tuple for a successful GET")
    func returnsDataAndResponseTuple() async throws {
        let (data, response) = try await provider.request(endpoint: .posts)

        let posts = try JSONDecoder().decode([Post].self, from: data)
        #expect(!posts.isEmpty)

        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
    }

    @Test("fetches a single resource by id")
    func fetchesSinglePost() async throws {
        let (data, response) = try await provider.request(endpoint: .post(id: 1))

        let post = try JSONDecoder().decode(Post.self, from: data)
        #expect(post.id == 1)

        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 200)
    }

    // jsonplaceholder returns an empty object for an unknown id; the
    // transport still succeeds and decoding is left to the caller, so we
    // can verify that a malformed payload surfaces as a DecodingError.
    @Test("returns raw data even when the payload can't be decoded by the caller")
    func returnsRawDataForUnmatchedPayload() async throws {
        let (data, response) = try await provider.request(endpoint: .post(id: 0))

        #expect(response is HTTPURLResponse)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Post.self, from: data)
        }
    }
}

@Suite("NetworkAgentPlugin interceptors")
struct PluginInterceptorTests {

    // MARK: - onRequest

    private struct HeaderInjector: NetworkAgentPlugin {
        let name: String
        let value: String
        let recorder: RequestRecorder

        func onRequest(_ request: URLRequest) async throws -> URLRequest {
            var mutated = request
            mutated.addValue(value, forHTTPHeaderField: name)
            await recorder.record(mutated)
            return mutated
        }
    }

    @Test("onRequest interceptor mutates the outgoing request")
    func onRequestMutatesOutgoingRequest() async throws {
        let recorder = RequestRecorder()
        let provider = NetworkAgentProvider<Api>(
            plugins: [HeaderInjector(name: "X-Network-Agent-Test", value: "intercepted", recorder: recorder)]
        )

        _ = try await provider.request(endpoint: .post(id: 1))

        let captured = try #require(await recorder.requests.first)
        #expect(captured.value(forHTTPHeaderField: "X-Network-Agent-Test") == "intercepted")
    }

    // MARK: - onResponse

    private struct DataRewriter: NetworkAgentPlugin {
        let payload: Data

        func onResponse(
            _ response: URLResponse,
            data: Data,
            request: URLRequest
        ) async throws -> (data: Data, response: URLResponse) {
            (data: payload, response: response)
        }
    }

    @Test("onResponse interceptor mutates the data returned to the caller")
    func onResponseMutatesData() async throws {
        let stub = Data("intercepted-payload".utf8)
        let provider = NetworkAgentProvider<Api>(plugins: [DataRewriter(payload: stub)])

        let (data, _) = try await provider.request(endpoint: .post(id: 1))

        #expect(data == stub)
    }

    private struct RequestEcho: NetworkAgentPlugin {
        let recorder: RequestRecorder

        func onResponse(
            _ response: URLResponse,
            data: Data,
            request: URLRequest
        ) async throws -> (data: Data, response: URLResponse) {
            await recorder.record(request)
            return (data: data, response: response)
        }
    }

    @Test("onResponse interceptor receives the final outgoing request")
    func onResponseReceivesFinalRequest() async throws {
        let recorder = RequestRecorder()
        let provider = NetworkAgentProvider<Api>(
            plugins: [
                HeaderInjector(name: "X-Trace", value: "abc", recorder: RequestRecorder()),
                RequestEcho(recorder: recorder)
            ]
        )

        _ = try await provider.request(endpoint: .post(id: 1))

        let captured = try #require(await recorder.requests.first)
        #expect(captured.url?.path == "/posts/1")
        #expect(captured.value(forHTTPHeaderField: "X-Trace") == "abc")
    }

    // MARK: - chain ordering

    private struct OrderingPlugin: NetworkAgentPlugin {
        let id: String
        let log: EventLog

        func onRequest(_ request: URLRequest) async throws -> URLRequest {
            await log.append("req:\(id)")
            return request
        }

        func onResponse(
            _ response: URLResponse,
            data: Data,
            request: URLRequest
        ) async throws -> (data: Data, response: URLResponse) {
            await log.append("res:\(id)")
            return (data: data, response: response)
        }
    }

    @Test("plugin chain runs onRequest then onResponse in registration order")
    func pluginChainOrdering() async throws {
        let log = EventLog()
        let provider = NetworkAgentProvider<Api>(
            plugins: [
                OrderingPlugin(id: "A", log: log),
                OrderingPlugin(id: "B", log: log)
            ]
        )

        _ = try await provider.request(endpoint: .post(id: 1))

        let events = await log.events
        #expect(events == ["req:A", "req:B", "res:A", "res:B"])
    }

    // MARK: - error propagation

    private struct FailingInterceptor: NetworkAgentPlugin {
        struct Boom: Error {}
        func onRequest(_ request: URLRequest) async throws -> URLRequest {
            throw Boom()
        }
    }

    @Test("an interceptor that throws aborts the request")
    func failingInterceptorAbortsRequest() async throws {
        let provider = NetworkAgentProvider<Api>(plugins: [FailingInterceptor()])

        await #expect(throws: FailingInterceptor.Boom.self) {
            _ = try await provider.request(endpoint: .post(id: 1))
        }
    }
}
