//
//  MovesRepository.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import Foundation
import Combine
import NetworkAgent

class MovesRepository {
    var provider: NetworkAgentProvider<Api>
    
    init(provider agent: NetworkAgentProvider<Api>) {
        provider = agent
    }
    
    func index<T: Codable>(query: [String: Any]) -> AnyPublisher<T, Error> {
        provider.request(endpoint: .moves(query: query))
            .tryMap { try $0.data.get() }
            .eraseToAnyPublisher()
    }

    func show(id: Int, query: [String: Any]) -> AnyPublisher<Move, Error> {
        provider.request(endpoint: .move(id: id, query: query))
            .tryMap { try $0.data.get() }
            .eraseToAnyPublisher()
    }
}
