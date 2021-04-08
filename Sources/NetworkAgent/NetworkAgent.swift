//
//  NetworkAgent.swift
//
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation
import Combine

public struct NetworkAgent {

    public struct Response<T> {
        let value: T
        let response: HTTPURLResponse
    }
    
    public enum NetworkError: Error {
        case unableToMap
        case internalServerError(code: Int, description: String) // 500...599
        case notFound(code: Int) // 404
        case unprocesableEntity(code: Int, description: String)
        case redirect(code: Int) // 300...399
        case unknown(error: Error)
        case urlError(error: URLError)
        case errorDecoding(key: String)
        case decodingError(error: DecodingError)
        case timeOut(code: Int)
        case none
    }
    
    func run<T: Decodable>(_ request: URLRequest, _ decoder: JSONDecoder = JSONDecoder(), from keyPath: String, dateFormat format: String, timeZone abbreviation: String, plugins: [NetworkAgentPlugin], from endpoint: NetworkAgentEndpoint) -> AnyPublisher<Response<T>, Error> {
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { error -> URLError in
                plugins.forEach { $0.onResponse(nil, with: nil, receiving: .urlError(error: error), from: endpoint) }
                return error
            }
            .tryMap { data, result -> Response<T> in
                
                let result = result as! HTTPURLResponse
                
                if 200...500 ~= result.statusCode {
                    
                    if 200...299 ~= result.statusCode {
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let formatter = DateFormatter()
                        formatter.timeZone = TimeZone(abbreviation: abbreviation)
                        formatter.dateFormat = format
                        decoder.dateDecodingStrategy = .formatted(formatter)
                        
                        do {
                            var _data = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                            if let new = _data as? [String: Any], !keyPath.isEmpty {
                                _data = new[keyPath] ?? [:]
                                
                                _data = try JSONSerialization.data(withJSONObject: _data, options: .prettyPrinted)
                                
                                if let payload = _data as? Data {
                                    let value = try decoder.decode(T.self, from: payload)
                                    plugins.forEach { $0.onResponse(result, with: payload) }
                                    return Response(value: value, response: result)
                                }
                            }
                            
                            let value = try decoder.decode(T.self, from: data)
                            plugins.forEach { $0.onResponse(result, with: data) }
                            return Response(value: value, response: result)
                        } catch let error {
                            if error is DecodingError {
                                plugins.forEach { $0.onResponse(result, with: data, receiving: .decodingError(error: error as! DecodingError), from: endpoint) }
                            } else {
                                plugins.forEach { $0.onResponse(result, with: data, receiving: .unknown(error: error), from: endpoint) }
                            }
                        }
                    }
                    
                    if 300...399 ~= result.statusCode {
                        plugins.forEach { $0.onResponse(result, with: data, receiving: .redirect(code: result.statusCode), from: endpoint) }
                        throw NetworkError.redirect(code: result.statusCode)
                    }
                    
                    if 400...499 ~= result.statusCode && result.statusCode != 422 {
                        plugins.forEach { $0.onResponse(result, with: data, receiving: .notFound(code: result.statusCode), from: endpoint) }
                        throw NetworkError.notFound(code: result.statusCode)
                    }
                    
                    if result.statusCode == 422 {
                        let string = String(data: data, encoding: .utf8)
                        plugins.forEach { $0.onResponse(result, with: data, receiving: .unprocesableEntity(code: result.statusCode, description: string ?? ""), from: endpoint) }
                        throw NetworkError.unprocesableEntity(code: result.statusCode, description: string ?? "")
                    }
                    
                    if 500...599 ~= result.statusCode {
                        plugins.forEach { $0.onResponse(result, with: data, receiving: .internalServerError(code: result.statusCode, description: ""), from: endpoint) }
                        throw NetworkError.internalServerError(code: result.statusCode, description: "")
                    }
                    
                    if result.statusCode == -1001 {
                        plugins.forEach { $0.onResponse(result, with: data, receiving: .timeOut(code: result.statusCode), from: endpoint) }
                        throw NetworkError.timeOut(code: result.statusCode)
                    }
                }
                
                throw NetworkError.unknown(error: NetworkError.none)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

