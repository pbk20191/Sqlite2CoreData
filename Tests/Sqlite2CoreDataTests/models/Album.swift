//
//  Album.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//
//

import Foundation
import SwiftData


@available(macOS 15, *)
@Model public class Album {
    #Index<Album>([\.albumid])
    var albumid: Int64
    var title: String
    @Relationship(minimumModelCount: 1) var artist: Artist
    @Relationship(deleteRule: .noAction, inverse: \Track.album) var track: [Track]?
    public init(albumid: Int64, title: String, artist: Artist) {
        self.albumid = albumid
        self.title = title
        self.artist = artist

    }
    
}
