//
//  PokemonsViewModel.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import Foundation

@MainActor
class PokemonsViewModel: ObservableObject {
    @Published var pokemons: [Pokemon] = []

    init() {
        Task {
            do {
                let pagination: Pagination<Pokemon> = try await Repository.pokemons.index(query: ["offset": 20, "limit": 20])
                self.pokemons += pagination.results
            } catch {
                // keep the current list on failure
            }
        }
    }
}
