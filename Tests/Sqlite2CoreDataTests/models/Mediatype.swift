//
//  Mediatype.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//
//

import Foundation
import SwiftData


@available(macOS 15, *)
@Model public class Mediatype {
    #Index<Mediatype>([\.mediatypeid])
    var mediatypeid: Int64
    var name: String?
    @Relationship(deleteRule: .noAction, inverse: \Track.mediatype) var track: [Track]?
    public init(mediatypeid: Int64) {
        self.mediatypeid = mediatypeid

    }
    
}
