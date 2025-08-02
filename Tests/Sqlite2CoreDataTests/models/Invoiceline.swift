//
//  Invoiceline.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//
//

import Foundation
import SwiftData


@available(macOS 15, *)
@Model public class Invoiceline {
    #Index<Invoiceline>([\.invoicelineid])
    var invoicelineid: Int64
    var quantity: Int64
    var unitprice: Double
    @Relationship(minimumModelCount: 1) var invoice: Invoice
    @Relationship(minimumModelCount: 1) var track: Track
    public init(invoicelineid: Int64, quantity: Int64, unitprice: Double, invoice: Invoice, track: Track) {
        self.invoicelineid = invoicelineid
        self.quantity = quantity
        self.unitprice = unitprice
        self.invoice = invoice
        self.track = track

    }
    
}
