//
//  MovesViewModel.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import Foundation

@MainActor
class MovesViewModel: ObservableObject {
    @Published var moves: [Move] = []

    init() {
        Task {
            do {
                let pagination: Pagination<Move> = try await Repository.moves.index(query: ["offset": 20, "limit": 20])
                self.moves += pagination.results
            } catch {
                // keep the current list on failure
            }
        }
    }
}
