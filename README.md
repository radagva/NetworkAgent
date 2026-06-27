# NetworkAgent

<p>
<a href="https://github.com/apple/swift-package-manager"><img src="https://camo.githubusercontent.com/685501f58b5a9e01d0dfde93d60b80f46c275435c0bfd09bb9bc9dd0dde9a830/68747470733a2f2f696d672e736869656c64732e696f2f62616467652f53776966742532305061636b6167652532304d616e616765722d636f6d70617469626c652d627269676874677265656e2e737667" alt="Swift Package Manager compatible" data-canonical-src="https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg" style="max-width:100%;"></a>
</p>

**NetworkAgent** is a small, dependency-free networking layer for Swift. It models your API as a single endpoint enum, performs HTTP requests with `async`/`await`, and returns the raw `(Data, URLResponse)` tuple — so you stay in full control of decoding. A `Sendable` plugin protocol lets you hook into the request/response lifecycle as async interceptors that can mutate the request before it's sent, mutate the response before it reaches the caller, or fire side-requests (e.g., for token refresh) from inside `onResponse`.

- Swift 6 / strict concurrency
- iOS 16+, macOS 12+
- No decoding in the library — you get `Data` and decode at the call site
- Plugins as async interceptors (`onRequest`, `onResponse`)
- A `NetworkAgent` reference inside `onResponse` so plugins can fire follow-up calls

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
  - [`NetworkAgentEndpoint`](#networkagentendpoint)
  - [`HTTPMethod`](#httpmethod)
  - [`HTTPTask`](#httptask)
  - [`HTTPURLEncoding`](#httpurlencoding)
  - [`HTTPMultipartTask`](#httpmultiparttask)
  - [`NetworkAgentProvider`](#networkagentprovider)
  - [`NetworkAgent`](#networkagent)
  - [`NetworkAgentPlugin`](#networkagentplugin)
- [Usage](#usage)
  - [1. Define an endpoint](#1-define-an-endpoint)
  - [2. Build a repository](#2-build-a-repository)
  - [3. Consume from a ViewModel](#3-consume-from-a-viewmodel)
- [Plugins as Interceptors](#plugins-as-interceptors)
  - [Logging plugin](#logging-plugin)
  - [Auth header injector](#auth-header-injector)
  - [Token refresh via side-request from `onResponse`](#token-refresh-via-side-request-from-onresponse)
  - [Chain ordering](#chain-ordering)
- [Multipart Uploads](#multipart-uploads)
- [Testing](#testing)
- [Notes & Gotchas](#notes--gotchas)
- [License](#license)

---

## Installation

Add NetworkAgent through Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/radagva/NetworkAgent.git", from: "x.y.z")
]
```

Then add `"NetworkAgent"` to your target's dependencies.

---

## Quick Start

```swift
import NetworkAgent

enum Api: NetworkAgentEndpoint {
    case posts
    case post(id: Int)

    var baseURL: URL { URL(string: "https://jsonplaceholder.typicode.com")! }
    var path: String {
        switch self {
        case .posts: return "/posts"
        case .post(let id): return "/posts/\(id)"
        }
    }
    var method: HTTPMethod { .get }
    var task: HTTPTask { .requestPlain }
}

struct Post: Decodable {
    let id: Int
    let title: String
    let body: String
}

let provider = NetworkAgentProvider<Api>()

let (data, response) = try await provider.request(endpoint: .posts)
let posts = try JSONDecoder().decode([Post].self, from: data)

if let http = response as? HTTPURLResponse {
    print("status:", http.statusCode)
}
```

That's the whole API surface for a basic request: build the endpoint, hand it to the provider, get back a `(Data, URLResponse)` tuple, decode at the call site.

---

## Core Concepts

### `NetworkAgentEndpoint`

Every API call is described by a value that conforms to `NetworkAgentEndpoint`. The conforming type is `Sendable` so it can cross actor boundaries and be stored by plugins.

```swift
public protocol NetworkAgentEndpoint: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get } // default: JSON Content-Type/Accept
    var task: HTTPTask { get }
}
```

The protocol ships with a default `headers`:

```swift
[
    "Content-Type": "application/json",
    "Accept": "application/json"
]
```

Override it when you need custom values (auth tokens, alternate content types, etc.).

### `HTTPMethod`

```swift
public enum HTTPMethod: String, Sendable {
    case get, post, put, patch, delete
}
```

The raw value is uppercased and assigned to `URLRequest.httpMethod`.

### `HTTPTask`

Describes the body / query of a request:

```swift
public enum HTTPTask: Sendable {
    case requestPlain                                                                  // no body, no query
    case requestAttributes(attributes: [String: any Sendable], encoding: HTTPURLEncoding)
    case requestWithoutAttributes(content: any Sendable)                               // currently not serialized — see notes
    case upload(parts: [HTTPMultipartTask])                                            // multipart/form-data
}
```

`attributes` is `[String: any Sendable]` so values can safely cross actor boundaries. Use primitives (`String`, `Int`, `Bool`, `Double`, arrays/dictionaries of primitives) — anything that survives `JSONSerialization` or `URLQueryItem` stringification.

### `HTTPURLEncoding`

Selects how `requestAttributes` are encoded:

```swift
public enum HTTPURLEncoding: Sendable {
    case json   // attributes are serialized into the HTTP body as JSON
    case url    // attributes are appended to the URL as URLQueryItems (use for GET queries)
}
```

### `HTTPMultipartTask`

A single multipart part. Pass several of them inside `.upload(parts:)`:

```swift
public struct HTTPMultipartTask: Sendable {
    public init(
        data: Data,
        name: String,
        filename: String,
        mymetype: String? = nil
    )
}
```

- If `mymetype` is `nil`, the part is sent as a plain form field (its `data` is UTF-8 text).
- If `mymetype` is set (e.g. `"image/png"`), the part is sent as a file upload with the supplied `filename` and `Content-Type`.

A `Boundary-<UUID>` is generated per request and automatically appended to the `Content-Type` header when the task is `.upload`. You only need to declare `"Content-Type": "multipart/form-data"` in your endpoint's headers — the provider appends `; boundary=…`.

### `NetworkAgentProvider`

The provider is the type you call to perform requests. It's generic over your endpoint enum and is `Sendable`.

```swift
public struct NetworkAgentProvider<E: NetworkAgentEndpoint>: Sendable {
    public init(plugins: [NetworkAgentPlugin] = [])

    public func request(endpoint: E) async throws -> (data: Data, response: URLResponse)
}
```

- `plugins` — the interceptor chain (see [Plugins](#plugins-as-interceptors)).
- `request(endpoint:)` — runs the request through the plugin chain and returns the raw tuple. Decoding is up to the caller.

### `NetworkAgent`

`NetworkAgent` is the lower-level type the provider delegates to. It also has a **public** entry point used from inside `onResponse` interceptors to fire side-requests by endpoint:

```swift
public struct NetworkAgent: Sendable {
    public init()

    /// Fires a one-off request for the given endpoint.
    ///
    /// Intended for use from inside `onResponse` interceptors (e.g. token
    /// refresh, retries). Requests fired through this method do NOT re-run
    /// the plugin chain, which is what keeps interceptors from recursing into
    /// themselves.
    public func request(_ endpoint: any NetworkAgentEndpoint) async throws -> (data: Data, response: URLResponse)
}
```

You usually go through a `NetworkAgentProvider` for normal calls; you only touch `NetworkAgent` directly from inside a plugin (where one is handed to you).

### `NetworkAgentPlugin`

Plugins are async interceptors. Both methods have pass-through defaults, so implement only the side you care about.

```swift
public protocol NetworkAgentPlugin: Sendable {
    /// Inspect or mutate the outgoing URLRequest before it is sent.
    func onRequest(
        _ request: URLRequest,
        endpoint: any NetworkAgentEndpoint
    ) async throws -> URLRequest

    /// Inspect or mutate the response after the network call completes.
    ///
    /// - parameter request:  the final request that was actually sent
    ///                       (after every prior onRequest ran).
    /// - parameter endpoint: the endpoint that produced this request.
    /// - parameter agent:    a NetworkAgent for firing side-requests.
    func onResponse(
        _ response: URLResponse,
        data: Data,
        request: URLRequest,
        endpoint: any NetworkAgentEndpoint,
        agent: NetworkAgent
    ) async throws -> (data: Data, response: URLResponse)
}
```

Behavior summary:

- `onRequest` interceptors run **in registration order**. Each receives the result of the previous one, so you can stack header injectors, signers, etc.
- `URLSession.shared.data(for:)` is invoked with the final mutated request.
- `onResponse` interceptors then run **in registration order** on the resulting `(data, response)`. Each can rewrite the body or response, short-circuit (by throwing), or fire side-requests through the `agent` parameter.
- If any interceptor `throws`, the whole call throws — the URLSession call is skipped (when thrown from `onRequest`) or short-circuited (when thrown from `onResponse`).

---

## Usage

### 1. Define an endpoint

```swift
import NetworkAgent

enum Api {
    case login(email: String, password: String)
    case books(query: [String: any Sendable])
    case book(id: Int)
}

extension Api: NetworkAgentEndpoint {
    var baseURL: URL { URL(string: "https://example.com/api")! }

    var path: String {
        switch self {
        case .login:           return "/login"
        case .books:           return "/books"
        case let .book(id):    return "/books/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login:           return .post
        case .books, .book:    return .get
        }
    }

    var task: HTTPTask {
        switch self {
        case let .login(email, password):
            return .requestAttributes(
                attributes: ["email": email, "password": password],
                encoding: .json
            )
        case let .books(query):
            return .requestAttributes(attributes: query, encoding: .url)
        case .book:
            return .requestPlain
        }
    }
}
```

### 2. Build a repository

Repositories typically own the provider and do the decoding. Keep the model types `Decodable` and let the repository surface domain types to the rest of the app.

```swift
import Foundation
import NetworkAgent

final class BooksRepository: Sendable {
    private let provider: NetworkAgentProvider<Api>

    init(provider: NetworkAgentProvider<Api>) {
        self.provider = provider
    }

    func login(email: String, password: String) async throws -> Session {
        let (data, _) = try await provider.request(
            endpoint: .login(email: email, password: password)
        )
        return try Self.decoder.decode(Session.self, from: data)
    }

    func books(query: [String: any Sendable]) async throws -> [Book] {
        let (data, response) = try await provider.request(endpoint: .books(query: query))

        // You can branch on status code before decoding.
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try Self.decoder.decode([Book].self, from: data)
    }

    func book(id: Int) async throws -> Book {
        let (data, _) = try await provider.request(endpoint: .book(id: id))
        return try Self.decoder.decode(Book.self, from: data)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
```

### 3. Consume from a ViewModel

```swift
import Foundation

@MainActor
final class BooksViewModel: ObservableObject {
    @Published private(set) var books: [Book] = []
    @Published private(set) var errorMessage: String?

    private let repository: BooksRepository

    init(repository: BooksRepository) {
        self.repository = repository
    }

    func load() {
        Task {
            do {
                books = try await repository.books(query: ["limit": 20, "offset": 0])
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

For a complete working example see `Examples/Pokedex/`.

---

## Plugins as Interceptors

Plugins are the extension point for cross-cutting concerns (logging, auth, metrics, caching, retries). They're `Sendable`, async, and they can mutate the request or response.

### Logging plugin

The simplest plugin just observes and forwards the request/response unchanged. The pass-through defaults from the protocol mean you only need to implement the side you care about.

```swift
import Foundation
import NetworkAgent

struct AgentLogger: NetworkAgentPlugin {
    func onRequest(
        _ request: URLRequest,
        endpoint: any NetworkAgentEndpoint
    ) async throws -> URLRequest {
        print("→", request.httpMethod ?? "?", request.url?.absoluteString ?? "")
        return request
    }

    func onResponse(
        _ response: URLResponse,
        data: Data,
        request: URLRequest,
        endpoint: any NetworkAgentEndpoint,
        agent: NetworkAgent
    ) async throws -> (data: Data, response: URLResponse) {
        if let http = response as? HTTPURLResponse {
            print("←", http.statusCode, request.url?.absoluteString ?? "")
        }
        return (data: data, response: response)
    }
}

let provider = NetworkAgentProvider<Api>(plugins: [AgentLogger()])
```

### Auth header injector

`onRequest` returns the (possibly mutated) `URLRequest`. Anything you put on it is what URLSession actually sends.

```swift
struct AuthHeaderInjector: NetworkAgentPlugin {
    let token: @Sendable () async -> String?

    func onRequest(
        _ request: URLRequest,
        endpoint: any NetworkAgentEndpoint
    ) async throws -> URLRequest {
        guard let token = await token() else { return request }
        var mutated = request
        mutated.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return mutated
    }
}
```

### Token refresh via side-request from `onResponse`

This is the pattern the `agent` parameter on `onResponse` was designed for: when the response says the access token is stale, refresh it through a separate endpoint, then retry the original request. The retry uses `agent.request(_:)`, which **does not** re-run the plugin chain — that's the recursion guard, so this plugin can safely retry without infinitely re-entering itself.

```swift
actor TokenStore {
    private(set) var accessToken: String?
    func update(_ token: String) { accessToken = token }
}

struct TokenRefresher: NetworkAgentPlugin {
    let store: TokenStore

    func onResponse(
        _ response: URLResponse,
        data: Data,
        request: URLRequest,
        endpoint: any NetworkAgentEndpoint,
        agent: NetworkAgent
    ) async throws -> (data: Data, response: URLResponse) {
        guard
            let http = response as? HTTPURLResponse,
            http.statusCode == 401
        else {
            return (data: data, response: response)
        }

        // Side-request #1: refresh the token. No plugin chain re-entry.
        let (refreshData, _) = try await agent.request(Api.refresh)
        let refreshed = try JSONDecoder().decode(TokenResponse.self, from: refreshData)
        await store.update(refreshed.accessToken)

        // Side-request #2: retry the original endpoint with the new token in store.
        // Again, no plugin chain re-entry — so make sure the side request can
        // include whatever it needs (e.g. by reading the token from the store
        // inside the endpoint's headers).
        return try await agent.request(endpoint)
    }
}
```

Notes:

- The `endpoint` parameter is the one the original call was made with — you can hand it straight back to `agent.request(_:)` for a retry.
- The `request` parameter is the **final** `URLRequest` after every prior `onRequest` ran, which is useful if you want to inspect the exact request that was sent before refreshing.

### Chain ordering

Plugins are applied in the order you pass them. For each request:

1. `onRequest` runs through every plugin in order; each one's output is the next one's input.
2. URLSession fires the resulting `URLRequest`.
3. `onResponse` runs through every plugin in the same order; each one's output is the next one's input.

```swift
let provider = NetworkAgentProvider<Api>(plugins: [
    AuthHeaderInjector(token: { ... }),   // 1: adds Authorization header
    AgentLogger(),                         // 2: logs the request that will actually be sent
    TokenRefresher(store: tokenStore)      // 3: handles 401 by refreshing + retrying
])
```

---

## Multipart Uploads

For `multipart/form-data` uploads, use `.upload(parts:)`:

```swift
extension Api: NetworkAgentEndpoint {
    var task: HTTPTask {
        switch self {
        case let .uploadAvatar(image):
            return .upload(parts: [
                HTTPMultipartTask(
                    data: image,
                    name: "avatar",
                    filename: "avatar.png",
                    mymetype: "image/png"
                ),
                HTTPMultipartTask(
                    data: Data("public".utf8),
                    name: "visibility"
                )
            ])
        // ...
        }
    }

    var headers: [String: String] {
        ["Content-Type": "multipart/form-data"]
    }
}
```

The provider takes care of generating a boundary and appending it to the `Content-Type` header.

---

## Notes & Gotchas

### No decoding in the library

`request(endpoint:)` returns `(Data, URLResponse)`. The library does **not** decode the body, run a `JSONDecoder`, unwrap envelopes, or apply key/date strategies. You decode at the call site (typically inside a repository). This keeps the library small and gives you complete control over decoding strategy per call.

### Status code is not checked

The library does not inspect the HTTP status code. A `404` with a `{}` body will return `(Data, URLResponse)` just like a `200`. Inspect `response as? HTTPURLResponse` yourself if you want to branch on status — or write a plugin that throws for non-2xx responses.

### `request as? HTTPURLResponse`

The returned `URLResponse` is whatever URLSession produces. For HTTP/HTTPS calls it will always be an `HTTPURLResponse`, but the library doesn't force-cast it for you — read `response as? HTTPURLResponse` so non-HTTP URL schemes don't crash.

### Side-requests don't re-enter the plugin chain

Calling `agent.request(_:)` from inside `onResponse` bypasses every plugin (including the one calling it). This is intentional — it's the recursion guard that lets you implement "refresh-and-retry" without setting your own plugin on fire. If your retried request needs auth headers, either:

- read them in the endpoint's `headers` (e.g. from a token store actor), so they're applied when the agent builds the `URLRequest`, or
- skip going through `agent.request(_:)` and call `provider.request(endpoint:)` from a different actor that knows to suppress the plugin during the retry.

### `requestWithoutAttributes` is a no-op

`HTTPTask.requestWithoutAttributes(content:)` is declared but the request builder does not serialise its `content`. Today this case behaves the same as `.requestPlain`. Use `.requestAttributes(...)` or `.upload(...)` for any payload you actually want to send.

### URL encoding caveats

For `.requestAttributes(attributes:, encoding: .url)`:

- Values are stringified via `String(describing:)`. Pass primitives (`String`, `Int`, `Bool`, `Double`) for predictable query strings.
- The provider replaces `+` with `%2B` in the percent-encoded query so servers do not interpret `+` as a space.
- Dictionary iteration order is **not** stable. If your server is sensitive to query parameter ordering (most aren't), don't rely on a particular order.

### Concurrency model

The async API runs on whatever executor was active at the call site. If you need main-actor delivery for UI binding, call from a `@MainActor`-isolated context (e.g. a `@MainActor` ViewModel) — or hop with `await MainActor.run { ... }` before touching UI state.

---

## License

MIT — see [LICENSE](./LICENSE).
