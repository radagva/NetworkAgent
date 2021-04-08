//
//  Publisher.swift
//  
//
//  Created by Angel Rada on 4/8/21.
//

import Foundation
import Combine

public extension Publisher {
    
    /// Wrapper for sink original method to handle request output with ease.
    ///
    /// This is made to make a more verbose and specific use of the network stream, its use is totally optional.
    /// - parameter onSuccess: Is fired when there is not any errors found while the execution of the request.
    /// - parameter onError: Is fired when there is an unespected behavior, interruption or server bad error code, this could return  a `NetworkError`.
    /// - parameter onCompleted: Is fired always at the end of the request lifecycle.
    /// - Returns: A cancellable instance; used when you end assignment of the received value. Deallocation of the result will tear down the subscription stream.
    func sink(onSuccess: @escaping ((Self.Output) -> Void) = { _ in }, onError: @escaping ((Error) -> ()) = { _ in }, onCompleted: @escaping (() -> Void) = {}) -> AnyCancellable {
        
        return self.sink(receiveCompletion: { subscriber in
            if case let .failure(error) = subscriber {
                onError(error)
            }
            
            onCompleted()
        }, receiveValue: { output in
            onSuccess(output)
        })
    }
}
