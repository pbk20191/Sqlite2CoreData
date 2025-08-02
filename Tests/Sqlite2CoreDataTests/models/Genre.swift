//
//  Genre.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//
//

import Foundation
import SwiftData


@available(macOS 15, *)
@Model public class Genre {
    #Index<Genre>([\.genreid])
    var genreid: Int64
    var name: String?
    @Relationship(deleteRule: .noAction, inverse: \Track.genre) var track: [Track]?
    public init(genreid: Int64) {
        self.genreid = genreid

    }
    
}
