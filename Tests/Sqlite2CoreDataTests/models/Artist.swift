//
//  Artist.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//
//

import Foundation
import SwiftData


@available(macOS 15, *)
@Model public class Artist {
    #Index<Artist>([\.artistid])
    var artistid: Int64
    var name: String?
    @Relationship(deleteRule: .noAction) var album: [Album]?
    public init(artistid: Int64) {
        self.artistid = artistid

    }
    
}
