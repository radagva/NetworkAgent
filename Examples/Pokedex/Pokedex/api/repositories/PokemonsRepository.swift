//
//  PokemonsRepository.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import Foundation
import NetworkAgent

class PokemonsRepository {
    let provider: NetworkAgentProvider<Api>

    init(provider agent: NetworkAgentProvider<Api>) {
        provider = agent
    }

    func index<T: Decodable>(query: [String: Any]) async throws -> T {
        let (data, _) = try await provider.request(endpoint: .pokemons(query: query))
        return try Self.decoder.decode(T.self, from: data)
    }

    func show(id: Int, query: [String: Any]) async throws -> Pokemon {
        let (data, _) = try await provider.request(endpoint: .pokemon(id: id, query: query))
        return try Self.decoder.decode(Pokemon.self, from: data)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
