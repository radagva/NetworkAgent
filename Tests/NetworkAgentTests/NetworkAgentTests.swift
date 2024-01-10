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
    case badPosts
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
        case .badPosts:
            return "/postsy"
        case .post(let id):
            return "/posts/\(id)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .posts, .post, .badPosts:
            return .get
        }
    }
    
    var task: HTTPTask {
        switch self {
        case .posts, .post, .badPosts:
            return .requestPlain
        }
    }
}

final class NetworkAgentTests: XCTestCase {
    
    var provider: NetworkAgentProvider<Api>!
    
    override func setUpWithError() throws {
        provider = .init(plugins: [NetworkLogger()])
    }
    
    override func tearDownWithError() throws {
        provider = nil
    }
    
    @available(macOS 12, *) @available(iOS 15, *)
    func test_CanRunAnAsyncHTTPRequest() async throws {
        
        var posts: [Post]?
        
        do {
            posts = try await provider.request(endpoint: .posts)
        } catch {
            print(error)
        }

        XCTAssertNotNil(posts)
    }
    
    @available(macOS 12, *) @available(iOS 15, *)
    func test_CanCatchErrorCodesExceptions() async throws {
        
        var posts: [Post]?
        
        do {
            posts = try await provider.request(endpoint: .badPosts)
        } catch let error as HTTPError {
            if case let .badRequest(response, _) = error{
                XCTAssertTrue(response.statusCode == 404)
            }
        }
        
        XCTAssertNil(posts)
    }
    
    @available(macOS 12, *) @available(iOS 15, *)
    func test_CanCatchConectivityError() async throws {
        do {
            let posts: [Post] = try await provider.request(endpoint: .posts)
            XCTAssertNotNil(posts)
        } catch let error as URLError {
            if case .notConnectedToInternet = error.code {
                XCTAssertTrue(error.code == .notConnectedToInternet)
            }
        }
    }
    
    @available(macOS 12, *) @available(iOS 15, *)
    func test_CanGetSinglePostById() async throws {
        let post = try await fetchPost(with: 1)
        
        XCTAssertNotNil(post)
    }
    
    // if jsonplaceholder cant find a post, returns an empty object
    // an empty object just throw DecodingError.keyNotFound
    @available(macOS 12, *) @available(iOS 15, *)
    func test_ExceptionHandlesInvalidResponse() async throws {
        
        var post: Post? = nil
        
        do {
            post = try await fetchPost(with: 0)
        } catch {
            // the first field it will try to decode should be userId
            // as is the firt field declared in Post model
            if case let .keyNotFound(key, _) = error as? DecodingError {
                XCTAssertEqual(key.stringValue, "userId")
            }
            XCTAssertNotNil(error)
        }
        
        XCTAssertNil(post)
    }
    
    @discardableResult
    @available(macOS 12, *) @available(iOS 15, *)
    private func fetchPost(with id: Int) async throws -> Post {
        do {
             return try await provider.request(endpoint: .post(id: id)) as Post
        } catch {
            throw error
        }
    }
}
