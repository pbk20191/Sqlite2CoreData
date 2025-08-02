//
//  Customer.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//
//

import Foundation
import SwiftData


@available(macOS 15, *)
@Model public class Customer {
    #Index<Customer>([\.customerid])
    var address: String?
    var city: String?
    var company: String?
    var country: String?
    var customerid: Int64
    var email: String
    var fax: String?
    var firstname: String
    var lastname: String
    var phone: String?
    var postalcode: String?
    var state: String?
    var employee: Employee?
    @Relationship(deleteRule: .noAction, inverse: \Invoice.customer) var invoice: [Invoice]?
    public init(customerid: Int64, email: String, firstname: String, lastname: String) {
        self.customerid = customerid
        self.email = email
        self.firstname = firstname
        self.lastname = lastname

    }
    
}
