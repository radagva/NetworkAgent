//
//  PokemonsRepository.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import Foundation
import Combine
import NetworkAgent

class PokemonsRepository {
    var provider: NetworkAgentProvider<Api>

    init(provider agent: NetworkAgentProvider<Api>) {
        provider = agent
    }

    func index<T: Decodable>(query: [String: Any]) -> AnyPublisher<T, Error> {
        provider.request(endpoint: .pokemons(query: query))
            .tryMap { try Self.decoder.decode(T.self, from: $0.data) }
            .eraseToAnyPublisher()
    }

    func show(id: Int, query: [String: Any]) -> AnyPublisher<Pokemon, Error> {
        provider.request(endpoint: .pokemon(id: id, query: query))
            .tryMap { try Self.decoder.decode(Pokemon.self, from: $0.data) }
            .eraseToAnyPublisher()
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
