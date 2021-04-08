# NetworkAgent

<p>
<a href="https://github.com/apple/swift-package-manager"><img src="https://camo.githubusercontent.com/685501f58b5a9e01d0dfde93d60b80f46c275435c0bfd09bb9bc9dd0dde9a830/68747470733a2f2f696d672e736869656c64732e696f2f62616467652f53776966742532305061636b6167652532304d616e616765722d636f6d70617469626c652d627269676874677265656e2e737667" alt="Swift Package Manager compatible" data-canonical-src="https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg" style="max-width:100%;"></a>
</p>

This package is meant to make http request of an easy way inspiren in the architecture of Moya package.
This package is 100% free of dependencies and works with Combine api + Codable

## Example

Api.swift
```Swift
import NetworkAgent

enum Api {
    case login(email: String, password: String)
    case books(query: [String: Any])
    case book(id: Int)
}

extension Api: NetworkAgentEndpoint {
    var baseURL: URL {
        return URL(string: "https://some_url.com/api")!
    }
    
    var path: String {
        switch self {
        case .login: return "/login"
        case .books: return "/books"
        case let .book(id): return "/books/\(id)"
        }
    }
    
    var method: HTTPMethod {
        return .get
    }
    
    var task: HTTPTask {
        switch self {
            case let .login(email, password): return .requestAttributes(attributes: ["email:" email, "password": password], encoding: .json)
            case let .books(query): return .requestAttributes(attributes: query, encoding: .url)
            case .book: return .requestPlain
        }
    }
}
```

Repository.swift
```Swift
import NetworkAgent

class Repository {

    typealias Callback<T> = (T) -> ()
    static let shared: Repository = Repository()
    private let provider: NetworkAgentProvider<Api> = .init(plugins: [])
    
    func login(email: String, password: String) -> <Session, Error> {
        return provider.request(.login(email: email, password: password))
    }
    
    func books(query: [String: Any]) -> <[Book], Error> {
        return provider.request(.books(query: query))
    }
    
    func book(id: int) -> <Book, Error> {
        return provider.request(.book(id: id))
    }
}
```

LoginViewModel.swift
```Swift
import Foundation
import Combine

class LoginViewModel: ObservableObject {
    
    @Published var email: String = ""
    @Published var password: String = ""
    private var cancellable: Set<AnyCancellable> = .init()
    private var repository = Repository.shared
    
    func login(completion: @escaping Callback<Session>) {
        self.isLoading = true
        repository.login(email: email, password: password)
            .sink(onSuccess: completion)
            .store(in: &cancellable)
    }
}
```

# Plugins

To make a custom plugin is as easy to implement the protocol `NetworkAgentPlugin`
every function of the protocol is optional. 

```Swift
public protocol NetworkAgentPlugin {
    func onRequest(_ request: URLRequest, with configuration: RequestConfiguration)
    func onResponse(_ response: HTTPURLResponse, with payload: Data)
    func onResponse(_ response: HTTPURLResponse?, with payload: Data?, receiving error: NetworkAgent.NetworkError, from endpoint: NetworkAgentEndpoint)
}
```
