//
//  File.swift
//  
//
//  Created by Angel Rada on 10/1/24.
//

import Foundation
import Combine

extension NetworkAgent {
    func run<T: Decodable>(
        _ request: URLRequest,
        _ decoder: JSONDecoder = JSONDecoder(),
        from keyPath: String,
        dateFormat format: String,
        timeZone abbreviation: String,
        from endpoint: NetworkAgentEndpoint,
        plugins: [NetworkAgentPlugin] = []
    ) -> AnyPublisher<Response<T>, Error> {

        return URLSession.shared
            .dataTaskPublisher(for: request)
            .tryMap { data, result -> Response<T> in
                let response = result as! HTTPURLResponse
                
                return try prepareResponse(request: request, response: response, data: data, keyPath: keyPath, decoder: decoder, plugins: plugins)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
