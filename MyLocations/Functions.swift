//
//  Functions.swift
//  MyLocations
//

import Foundation

// Общая точка для логирования неожиданных ошибок Core Data — используется
// там, где по месту падать с fatalError() неуместно (например, при
// обычном выполнении fetch-запроса), но ошибку всё равно нужно заметить.
func fatalCoreDataError(_ error: Error) {
    print("*** Fatal error: \(error)")
}
