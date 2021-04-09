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
    
    func index<T: Codable>(query: [String: Any]) -> AnyPublisher<T, Error> {
        provider.request(endpoint: .pokemons(query: query))
    }
    
    func show(id: Int, query: [String: Any]) -> AnyPublisher<Pokemon, Error> {
        provider.request(endpoint: .pokemon(id: id, query: query))
    }
}
