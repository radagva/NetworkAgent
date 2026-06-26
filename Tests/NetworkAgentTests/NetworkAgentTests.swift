import XCTest
@testable import NetworkAgent

struct Post: Codable {
    var userId: Int
    var id: Int
    var title: String
    var body: String
}

enum Api {
    case posts
    case post(id: Int)
}

extension Api: NetworkAgentEndpoint {
    var baseURL: URL {
        return URL(string: "https://jsonplaceholder.typicode.com")!
    }
    
    var path: String {
        switch self {
        case .posts:
            return "/posts"
        case .post(let id):
            return "/posts/\(id)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .posts, .post:
            return .get
        }
    }
    
    var task: HTTPTask {
        switch self {
        case .posts, .post:
            return .requestPlain
        }
    }
}

final class NetworkAgentTests: XCTestCase {
    
    var provider: NetworkAgentProvider<Api>!
    
    override func setUpWithError() throws {
        provider = .init()
    }
    
    override func tearDownWithError() throws {
        provider = nil
    }
    
    @available(macOS 12, *) @available(iOS 15, *)
    func test_CanRunAnAsyncHTTPRequest() async throws {
        let response: NetworkAgent.Response<[Post]> = try await provider.request(endpoint: .posts)
        let posts = try response.data.get()
        XCTAssertFalse(posts.isEmpty)
        XCTAssertEqual(response.response.statusCode, 200)
    }

    @available(macOS 12, *) @available(iOS 15, *)
    func test_CanGetSinglePostById() async throws {
        let response = try await fetchPost(with: 1)
        let post = try response.data.get()

        XCTAssertNotNil(post)
        XCTAssertEqual(response.response.statusCode, 200)
    }

    // if jsonplaceholder cant find a post, returns an empty object
    // an empty object would previously throw DecodingError.keyNotFound; now it
    // is surfaced via `response.data` as `.failure` so the HTTPURLResponse is
    // still inspectable alongside the decoding error.
    @available(macOS 12, *) @available(iOS 15, *)
    func test_ExceptionHandlesInvalidResponse() async throws {
        let response = try await fetchPost(with: 0)

        // The transport succeeded so we still get the HTTP response back.
        XCTAssertNotNil(response.response)

        guard case let .failure(error) = response.data else {
            XCTFail("Expected decoding to fail for missing post")
            return
        }

        // the first field it will try to decode should be userId
        // as is the firt field declared in Post model
        if case let .keyNotFound(key, _) = error as? DecodingError {
            XCTAssertEqual(key.stringValue, "userId")
        }
    }

    @discardableResult
    @available(macOS 12, *) @available(iOS 15, *)
    private func fetchPost(with id: Int) async throws -> NetworkAgent.Response<Post> {
        try await provider.request(endpoint: .post(id: id))
    }
}
