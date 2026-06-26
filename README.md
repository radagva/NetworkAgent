# NetworkAgent

<p>
<a href="https://github.com/apple/swift-package-manager"><img src="https://camo.githubusercontent.com/685501f58b5a9e01d0dfde93d60b80f46c275435c0bfd09bb9bc9dd0dde9a830/68747470733a2f2f696d672e736869656c64732e696f2f62616467652f53776966742532305061636b6167652532304d616e616765722d636f6d70617469626c652d627269676874677265656e2e737667" alt="Swift Package Manager compatible" data-canonical-src="https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg" style="max-width:100%;"></a>
</p>

NetworkAgent is a lightweight, dependency-free networking layer inspired by Moya. It supports both the **Combine** API and **Swift Concurrency** (`async`/`await`), is fully `Codable`-based, and exposes a plugin system for cross-cutting concerns (logging, auth, metrics, etc.).

---

## Table of Contents

- [Installation](#installation)
- [Core Concepts](#core-concepts)
  - [`NetworkAgentEndpoint`](#networkagentendpoint)
  - [`HTTPTask`](#httptask)
  - [`HTTPMethod`](#httpmethod)
  - [`NetworkAgentProvider`](#networkagentprovider)
  - [`NetworkAgent.Response<T>`](#networkagentresponset)
  - [`RequestConfiguration`](#requestconfiguration)
- [Usage](#usage)
  - [Define an Endpoint](#1-define-an-endpoint)
  - [Build a Repository](#2-build-a-repository)
  - [Consume from a ViewModel](#3-consume-from-a-viewmodel)
- [Plugins](#plugins)
- [Multipart Uploads](#multipart-uploads)
- [Caveats & Edge Cases](#caveats--edge-cases)

---

## Installation

Add NetworkAgent through Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/<your-org>/NetworkAgent.git", from: "x.y.z")
]
```

---

## Core Concepts

### `NetworkAgentEndpoint`

Every API call is described by a value that conforms to `NetworkAgentEndpoint`. Typically you model your API as an `enum` where each case represents one endpoint.

```swift
public protocol NetworkAgentEndpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get } // default: JSON Content-Type/Accept
    var task: HTTPTask { get }
}
```

The protocol ships with a default `headers` implementation:

```swift
[
    "Content-Type": "application/json",
    "Accept": "application/json"
]
```

Override it if your API needs different headers (auth tokens, custom content types, etc.).

### `HTTPTask`

Describes the body / parameters of a request:

```swift
public enum HTTPTask {
    case requestPlain                                                    // no body, no query
    case requestAttributes(attributes: [String: Any], encoding: HTTPURLEncoding)
    case requestWithoutAttributes(content: Any)                          // currently not serialized — see caveats
    case upload(parts: [HTTPMultipartTask])                              // multipart/form-data
}
```

`HTTPURLEncoding` selects how `requestAttributes` is encoded:

- `.json` – attributes are serialized into the HTTP body as JSON.
- `.url`  – attributes are appended to the URL as `URLQueryItem`s (use for `GET` queries).

### `HTTPMethod`

```swift
public enum HTTPMethod: String {
    case get, post, put, patch, delete
}
```

The raw value is uppercased and assigned to `URLRequest.httpMethod`.

### `NetworkAgentProvider`

`NetworkAgentProvider<E: NetworkAgentEndpoint>` is the type you call to perform requests. It is generic over your endpoint enum.

```swift
public struct NetworkAgentProvider<E: NetworkAgentEndpoint> {
    public init(
        plugins: [NetworkAgentPlugin] = [],
        configuration: RequestConfiguration = .init()
    )

    // Combine
    public func request<T: Decodable>(
        endpoint: E,
        config: RequestConfiguration? = nil
    ) -> AnyPublisher<NetworkAgent.Response<T>, Error>

    // Swift Concurrency
    @available(macOS 12, *) @available(iOS 15, *)
    public func request<T: Decodable>(
        endpoint: E,
        config: RequestConfiguration? = nil
    ) async throws -> NetworkAgent.Response<T>
}
```

Both overloads return `NetworkAgent.Response<T>` rather than the decoded model directly. This is an intentional change so callers can inspect the underlying `HTTPURLResponse` (status code, headers, etc.) along with the decoded payload.

### `NetworkAgent.Response<T>`

```swift
public struct Response<T> {
    public let data: T                  // your decoded model
    public let response: HTTPURLResponse // the raw HTTP response
}
```

- `data` is the decoded model (`T`), already parsed from JSON.
- `response` exposes the `HTTPURLResponse` so callers can read the status code, headers, or other metadata without having to thread it through plugins.

#### Migrating to `Response<T>`

If you were previously calling:

```swift
let posts: [Post] = try await provider.request(endpoint: .posts)
```

You now need to unwrap `.data`:

```swift
let response: NetworkAgent.Response<[Post]> = try await provider.request(endpoint: .posts)
let posts = response.data
```

For Combine pipelines, map through `\.data`:

```swift
provider.request(endpoint: .posts)
    .map(\.data)
    .eraseToAnyPublisher()
```

### `RequestConfiguration`

Per-request (or per-provider) configuration for decoding:

```swift
public struct RequestConfiguration {
    var decoder: JSONDecoder        // your own decoder if needed
    var from: String                // optional top-level keyPath to "unwrap" before decoding
    var dateFormat: String          // default: "yyyy-MM-dd HH:mm:ss"
    var timeZone: String            // default: "UTC"
}
```

- `decoder` – override to customize decoding (e.g., a custom `keyDecodingStrategy`).
- `from`   – when non-empty, the agent looks for that key in the top-level JSON object and decodes its value instead of the whole document. Useful for envelopes like `{ "data": { ... } }`.
- `dateFormat` / `timeZone` – wired into a `DateFormatter` that becomes the decoder's `dateDecodingStrategy`.

A configuration set on the provider is used as a default. Passing a `config:` argument to `request(...)` overrides it for that call.

---

## Usage

### 1. Define an Endpoint

`Api.swift`

```swift
import NetworkAgent

enum Api {
    case login(email: String, password: String)
    case books(query: [String: Any])
    case book(id: Int)
}

extension Api: NetworkAgentEndpoint {
    var baseURL: URL { URL(string: "https://some_url.com/api")! }

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

### 2. Build a Repository

`Repository.swift` (Combine)

```swift
import Combine
import NetworkAgent

final class Repository {
    static let shared = Repository()
    private let provider = NetworkAgentProvider<Api>(plugins: [])

    func login(email: String, password: String) -> AnyPublisher<Session, Error> {
        provider.request(endpoint: .login(email: email, password: password))
            .map(\.data)               // unwrap Response<Session> -> Session
            .eraseToAnyPublisher()
    }

    func books(query: [String: Any]) -> AnyPublisher<[Book], Error> {
        provider.request(endpoint: .books(query: query))
            .map(\.data)
            .eraseToAnyPublisher()
    }

    func book(id: Int) -> AnyPublisher<Book, Error> {
        provider.request(endpoint: .book(id: id))
            .map(\.data)
            .eraseToAnyPublisher()
    }
}
```

`Repository.swift` (async/await)

```swift
import NetworkAgent

final class Repository {
    static let shared = Repository()
    private let provider = NetworkAgentProvider<Api>(plugins: [])

    @available(macOS 12, *) @available(iOS 15, *)
    func login(email: String, password: String) async throws -> Session {
        let response: NetworkAgent.Response<Session> =
            try await provider.request(endpoint: .login(email: email, password: password))
        return response.data
    }

    @available(macOS 12, *) @available(iOS 15, *)
    func books(query: [String: Any]) async throws -> [Book] {
        let response: NetworkAgent.Response<[Book]> =
            try await provider.request(endpoint: .books(query: query))
        return response.data
    }
}
```

> **Tip:** when you need both the decoded model **and** the raw HTTP response (e.g., to read pagination headers), return the whole `Response<T>` instead of `.data`.

### 3. Consume from a ViewModel

```swift
import Combine

final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""

    private var cancellables = Set<AnyCancellable>()
    private let repository = Repository.shared

    func login(onSuccess: @escaping (Session) -> Void) {
        repository.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: onSuccess
            )
            .store(in: &cancellables)
    }
}
```

---

## Plugins

Plugins implement `NetworkAgentPlugin` to hook into the request/response lifecycle. Every method has a default empty implementation, so you only implement the ones you need.

```swift
public protocol NetworkAgentPlugin {
    func onRequest(_ request: URLRequest, with configuration: RequestConfiguration)
    func onResponse(_ response: HTTPURLResponse, with payload: Data, from endpoint: NetworkAgentEndpoint)
    func onResponse(_ response: HTTPURLResponse?, with payload: Data?, receiving error: Error, from endpoint: NetworkAgentEndpoint)
}
```

- `onRequest` – called right before the URLSession task is started.
- `onResponse(_:with:from:)` – called on a successful decode.
- `onResponse(_:with:receiving:from:)` – called when the transport fails (no response) or decoding fails. `response` and `payload` are both optional because some failures (e.g., `URLError.notConnectedToInternet`) happen before any response is received.

Plugins are registered when constructing the provider:

```swift
let provider = NetworkAgentProvider<Api>(plugins: [AgentLogger(options: [.verbose])])
```

See `Examples/Plugins/AgentLogger.swift` for a worked example that logs requests, responses, and errors.

---

## Multipart Uploads

For `multipart/form-data` uploads, use `.upload(parts:)` with `HTTPMultipartTask` values:

```swift
public struct HTTPMultipartTask {
    public init(
        data: Data,
        name: String,
        filename: String,
        mymetype: String? = nil
    )
}
```

- If `mymetype` is `nil`, the part is treated as a plain form field (its `data` is interpreted as UTF-8 text).
- If `mymetype` is set (e.g., `"image/png"`), the part is treated as a file upload with the supplied `filename` and `Content-Type`.

A `Boundary-<UUID>` is generated per request and appended to the `Content-Type` header when the task is `.upload`. You do **not** need to set the boundary yourself in `headers`; just declare `"Content-Type": "multipart/form-data"` and the provider will append `; boundary=…`.

```swift
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
```

---

## Caveats & Edge Cases

These are behaviors worth knowing about. Some of them are intentional; others are simply how the library is implemented today.

### `Response<T>` is the return type, not `T`

The most common gotcha after upgrading is forgetting to unwrap `.data`. If you write:

```swift
let posts = try await provider.request(endpoint: .posts) as [Post]
```

you will see:

```
Cannot convert value of type 'NetworkAgent.Response<T>' to type '[Post]' in coercion
Generic parameter 'T' could not be inferred
```

Either annotate the result explicitly or read `.data`:

```swift
let response: NetworkAgent.Response<[Post]> = try await provider.request(endpoint: .posts)
// or
let posts: [Post] = try await provider.request(endpoint: .posts).data
```

### Force-unwrapped HTTP response

The agent assumes the `URLResponse` returned by `URLSession` can be cast to `HTTPURLResponse` (`response as! HTTPURLResponse`). For standard HTTP/HTTPS requests this is safe, but custom URL protocols or non-HTTP schemes will crash. Only use `NetworkAgent` for HTTP/HTTPS endpoints.

### Decoding strategy differences between Combine and async/await

There is currently a subtle asymmetry between the two transport implementations:

- The **Combine** pipeline sets `decoder.keyDecodingStrategy = .convertFromSnakeCase` and a `DateFormatter`-based `dateDecodingStrategy` on every call.
- The **async/await** pipeline uses the decoder you pass in (via `RequestConfiguration.decoder`) **without** mutating its strategies.

If your async API returns snake_case JSON and you rely on auto-conversion, configure a decoder explicitly:

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

let config = RequestConfiguration(decoder: decoder)
let provider = NetworkAgentProvider<Api>(configuration: config)
```

### `RequestConfiguration.from` (envelope unwrapping) is Combine-only

When `from` is set, the **Combine** pipeline calls `extractPayload(...)` to dig into the top-level JSON object and decode the nested value. The **async/await** pipeline does **not** apply this transformation today and decodes the full response body directly. If you need envelope unwrapping with `async`/`await`, either:

- Model the envelope in your `Decodable` type (e.g., `struct Envelope<T: Decodable>: Decodable { let data: T }`), or
- Pre-process the data before decoding.

### `requestWithoutAttributes` is currently a no-op

`HTTPTask.requestWithoutAttributes(content:)` is declared in the enum but not handled in the request builder. Choosing this case results in a request with no body. Use `.requestAttributes(...)` or `.upload(parts:)` for any payload you actually need to send.

### URL encoding edge cases

For `.requestAttributes(attributes:, encoding: .url)`:

- Values are converted to strings via Swift's default `String(describing:)`. Custom types may produce surprising query strings — pass primitives (`String`, `Int`, `Bool`, etc.) when possible.
- The provider replaces `+` with `%2B` in the percent-encoded query to avoid the historical "+ means space" ambiguity on the server side.
- Dictionary iteration order is **not** stable. If your server is sensitive to query parameter ordering (most aren't), do not rely on a particular order.

### `Combine` requests deliver on the main thread

The Combine `request(...)` pipeline ends with `.receive(on: DispatchQueue.main)`. This is convenient for direct UI binding but means downstream `map` / `tryMap` operators run on main. If you do heavy work, hop off main with `.receive(on:)` before that work and then back to main before assigning to `@Published` state.

### Async/await runs wherever the caller's executor sends it

Unlike Combine, `async`/`await` calls return on whatever actor / executor was active at the suspension point. If you need main-actor delivery, await the call from a `@MainActor`-isolated context or hop with `await MainActor.run { ... }` before touching UI state.

### Empty / malformed responses surface as `DecodingError`

The library doesn't inspect the HTTP status code before attempting to decode. A `404` that returns an empty object (`{}`) will be reported as `DecodingError.keyNotFound` for the first required field of your model. If you need to branch on status codes, inspect `response.response.statusCode` from the returned `Response<T>` — or, for non-2xx errors, implement a plugin and short-circuit there.

### Plugin error reporting

When decoding fails, plugins receive `onResponse(_:with:receiving:from:)` with the `HTTPURLResponse` **and** the raw `Data`. When the transport itself fails (no response), both arguments are `nil`. Plugins should handle the optional case (see `AgentLogger`).

### Availability gates

`async`/`await` overloads are gated by `@available(macOS 12, *) @available(iOS 15, *)`. Earlier OS targets must use the Combine API.

---

## License

See `LICENSE`.
