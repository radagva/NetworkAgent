//
//  MovesRepository.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import Foundation
import NetworkAgent

class MovesRepository {
    let provider: NetworkAgentProvider<Api>

    init(provider agent: NetworkAgentProvider<Api>) {
        provider = agent
    }

    func index<T: Decodable>(query: [String: any Sendable]) async throws -> T {
        let (data, _) = try await provider.request(endpoint: .moves(query: query))
        return try Self.decoder.decode(T.self, from: data)
    }

    func show(id: Int, query: [String: any Sendable]) async throws -> Move {
        let (data, _) = try await provider.request(endpoint: .move(id: id, query: query))
        return try Self.decoder.decode(Move.self, from: data)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
