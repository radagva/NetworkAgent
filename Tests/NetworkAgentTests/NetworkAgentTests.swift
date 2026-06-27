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
        let (data, response) = try await provider.request(endpoint: .posts)
        let posts = try JSONDecoder().decode([Post].self, from: data)
        XCTAssertFalse(posts.isEmpty)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    @available(macOS 12, *) @available(iOS 15, *)
    func test_CanGetSinglePostById() async throws {
        let (data, response) = try await fetchPost(with: 1)
        let post = try JSONDecoder().decode(Post.self, from: data)

        XCTAssertNotNil(post)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    // jsonplaceholder returns an empty object for an unknown id; decoding
    // into `Post` must throw because `userId` is missing.
    @available(macOS 12, *) @available(iOS 15, *)
    func test_ExceptionHandlesInvalidResponse() async throws {
        let (data, response) = try await fetchPost(with: 0)

        XCTAssertNotNil(response)

        XCTAssertThrowsError(try JSONDecoder().decode(Post.self, from: data)) { error in
            if case let .keyNotFound(key, _) = error as? DecodingError {
                XCTAssertEqual(key.stringValue, "userId")
            }
        }
    }

    @discardableResult
    @available(macOS 12, *) @available(iOS 15, *)
    private func fetchPost(with id: Int) async throws -> (data: Data, response: URLResponse) {
        try await provider.request(endpoint: .post(id: id))
    }
}
