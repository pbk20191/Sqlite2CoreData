//
//  Employee.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//
//

import Foundation
import SwiftData


@available(macOS 15, *)
@Model public class Employee {
    #Index<Employee>([\.employeeid])
    var address: String?
    var birthdate: Date?
    var city: String?
    var country: String?
    var email: String?
    var employeeid: Int64
    var fax: String?
    var firstname: String
    var hiredate: Date?
    var lastname: String
    var phone: String?
    var postalcode: String?
    var reportsto: Int64?
    var state: String?
    var title: String?
    @Relationship(deleteRule: .noAction) var customer: [Customer]?
    public init(employeeid: Int64, firstname: String, lastname: String) {
        self.employeeid = employeeid
        self.firstname = firstname
        self.lastname = lastname

    }
    
}
