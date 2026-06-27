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

    func index<T: Decodable>(query: [String: Any]) -> AnyPublisher<T, Error> {
        provider.request(endpoint: .moves(query: query))
            .tryMap { try Self.decoder.decode(T.self, from: $0.data) }
            .eraseToAnyPublisher()
    }

    func show(id: Int, query: [String: Any]) -> AnyPublisher<Move, Error> {
        provider.request(endpoint: .move(id: id, query: query))
            .tryMap { try Self.decoder.decode(Move.self, from: $0.data) }
            .eraseToAnyPublisher()
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
