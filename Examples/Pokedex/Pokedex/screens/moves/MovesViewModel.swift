//
//  MovesViewModel.swift
//  Pokedex
//
//  Created by Angel Rada on 4/9/21.
//

import Foundation
import Combine

class MovesViewModel: ObservableObject {
    @Published var moves: [Move] = []
    
    init() {
        Repository.moves.index(query: ["offset": 20, "limit": 20])
            .map({ (pagination: Pagination<Move>) in
                return self.moves + pagination.results
            })
            .catch { _ in Just(self.moves) }
            .assign(to: &$moves)
    }
}
