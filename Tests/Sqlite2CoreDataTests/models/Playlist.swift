//
//  Playlist.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//
//

import Foundation
import SwiftData


@available(macOS 15, *)
@Model public class Playlist {
    #Index<Playlist>([\.playlistid])
    var name: String?
    var playlistid: Int64
    @Relationship(deleteRule: .noAction, inverse: \Track.playlist) var track: [Track]?
    public init(playlistid: Int64) {
        self.playlistid = playlistid

    }
    
}
