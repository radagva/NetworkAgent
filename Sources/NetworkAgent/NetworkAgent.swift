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
    
    internal func prepareResponse<T: Decodable>(request: URLRequest, response: HTTPURLResponse, data: Data, keyPath: String, decoder: JSONDecoder, plugins: [NetworkAgentPlugin] = []) throws -> Response<T> {
        if 200...299 ~= response.statusCode {
            let serialized = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)

            if let dict = serialized as? [String: Any], !keyPath.isEmpty {
                return try drilldown(dict, keyPath: keyPath, decoder: decoder, response: response)
            }
            
            plugins.forEach { $0.onResponse(response, receiving: data, from: request) }
            
            let decoded = try decoder.decode(T.self, from: data)
            return .init(value: decoded, response: response)
        }
        
        var error: HTTPError?
        
        
        if 300...399 ~= response.statusCode {
            error =  HTTPError.redirect(response, data: data)
        }
        
        if 400...499 ~= response.statusCode {
            error = HTTPError.badRequest(response, data: data)
        }
        
        if 500...599 ~= response.statusCode {
            error = HTTPError.internalServerError(response, data: data)
        }
        
        if let error {
            plugins.forEach { $0.onResponseError(error, having: response, from: request) }
            throw error
        }
        
        fatalError("Could not decode the response error")
    }
    
    internal func drilldown<T: Decodable>(_ dict: [String: Any], keyPath: String, decoder: JSONDecoder, response: HTTPURLResponse) throws -> Response<T> {
        let segments = keyPath.split(separator: ".").map { String($0) }
        var serialized: [String: Any] = [:]
        
        segments.forEach { key in
            serialized[key] = dict[key] ?? [:]
        }
        
        let dataSerialized = try JSONSerialization.data(withJSONObject: serialized, options: .prettyPrinted)
        
        let value = try decoder.decode(T.self, from: dataSerialized)
        return .init(value: value, response: response)
    }
}

