//
//  Track.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//
//

import Foundation
import SwiftData


@available(macOS 15, *)
@Model public class Track {
    #Index<Track>([\.trackid])
    var bytes: Int64?
    var composer: String?
    var milliseconds: Int64
    var name: String
    var trackid: Int64
    var unitprice: Double
    var album: Album?
    var genre: Genre?
    @Relationship(deleteRule: .noAction) var invoiceline: [Invoiceline]?
    @Relationship(minimumModelCount: 1) var mediatype: Mediatype
    @Relationship(deleteRule: .noAction) var playlist: [Playlist]?
    public init(milliseconds: Int64, name: String, trackid: Int64, unitprice: Double, mediatype: Mediatype) {
        self.milliseconds = milliseconds
        self.name = name
        self.trackid = trackid
        self.unitprice = unitprice
        self.mediatype = mediatype

    }
    
}
