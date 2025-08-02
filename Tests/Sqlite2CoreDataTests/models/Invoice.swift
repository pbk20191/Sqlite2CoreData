//
//  Invoice.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//
//

import Foundation
import SwiftData


@available(macOS 15, *)
@Model public class Invoice {
    #Index<Invoice>([\.invoiceid])
    var billingaddress: String?
    var billingcity: String?
    var billingcountry: String?
    var billingpostalcode: String?
    var billingstate: String?
    var invoicedate: Date
    var invoiceid: Int64
    var total: Double
    @Relationship(minimumModelCount: 1) var customer: Customer
    @Relationship(deleteRule: .noAction, inverse: \Invoiceline.invoice) var invoiceline: [Invoiceline]?
    public init(invoicedate: Date, invoiceid: Int64, total: Double, customer: Customer) {
        self.invoicedate = invoicedate
        self.invoiceid = invoiceid
        self.total = total
        self.customer = customer

    }
    
}
