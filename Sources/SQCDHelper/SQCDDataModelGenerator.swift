//
//  File.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/2/25.
//

import Foundation
import SqliteExtractor




public class SQCDDataModelGenerator: NSObject {
    
    @objc public let helper:SQCDDatabaseHelper
    
    @objc public init(helper:SQCDDatabaseHelper) {
        self.helper = helper
    }
    
    @objc(generateCoreDataModelFromDBPath:outputDirectoryPath:fileName:)
    public func generateCoreDataModel(fromDBPath dbPath: String, outputDirectoryPath: String, fileName: String?) -> Bool {
        let kXCDataModelDExtention   = "xcdatamodeld"
        let kXCDataModelExtention    = "xcdatamodel"
        let kXCDContents             = "contents"
        let root = XMLElement.init(name: "model")
        root.addAttribute(.attribute(name: "name", stringValue: ""))
        root.addAttribute(.attribute(name: "type", stringValue: "com.apple.IDECoreDataModeler.DataModel"))
        root.addAttribute(.attribute(name: "documentVersion", stringValue: "1.0"))
        root.addAttribute(.attribute(name: "lastSavedToolsVersion", stringValue: "2061"))
        root.addAttribute(.attribute(name: "systemVersion", stringValue: "12E55"))
        root.addAttribute(.attribute(name: "minimumToolsVersion", stringValue: "Automatic"))
        root.addAttribute(.attribute(name: "macOSVersion", stringValue: "Automatic"))
        root.addAttribute(.attribute(name: "iOSVersion", stringValue: "Automatic"))
        
        let doc = XMLDocument.init(rootElement: root)
        doc.version = "1.0"
        doc.characterEncoding = "UTF-8"
        doc.isStandalone = true
        guard let tableInfos = helper.fetchTableInfos(dbPath) else {
            print("No table information could be extracted from database ",dbPath);
            return false
        }
        for (name, info) in tableInfos {
            if (info.isManyToMany()) {
                print("Ignore many-to-many table: \(name)")
            } else {
                print("Generate entity: \(name)")
                root.addChild(info.xmlRepresentation())
            }
            
        }
        let xmlData = doc.xmlData(options: .nodePrettyPrint)

        var path = fileName ?? ""
        if (path.isEmpty) {
            path = ((dbPath as NSString).lastPathComponent as NSString).deletingPathExtension
        }
        let xcdmdPath = (outputDirectoryPath as NSString).appendingPathComponent("\(path).\(kXCDataModelDExtention)") + "/"
        let xcdmPath = (xcdmdPath as NSString).appendingPathComponent("\(path).\(kXCDataModelExtention)") + "/"
        let contentsPath = xcdmPath + kXCDContents
        do {
            try FileManager.default.createDirectory(atPath: xcdmdPath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: xcdmPath, withIntermediateDirectories: true)
            try xmlData.write(to: URL(fileURLWithPath: contentsPath))
            return true
        } catch {
            print("Error creating directory: \(error.localizedDescription)")
            return false
        }
    }
    
    
    
    
}


extension XMLNode {
    
    static func attribute(name:String, stringValue:String) -> XMLNode {
        let node = XMLNode(kind: .attribute)
        node.name = name
        node.stringValue = stringValue
        return node
    }
    
}
