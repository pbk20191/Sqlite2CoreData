//
//  File.swift
//  Sqlite2CoreData
//
//  Created by 박병관 on 8/4/25.
//

import Foundation
import ArgumentParser
import SQCDHelper
import SqliteExtractor
@preconcurrency import Dispatch

@main struct Sqlite2CoreData: AsyncParsableCommand {
    
    static let configuration = CommandConfiguration(
        abstract: "Migrate SQLite DB to Core Data model."
    )

    @Argument(help: "Path to the SQLite database.")
    var dbPath: String

    @Argument(help: "Output directory for generated files.")
    var outputPath: OutputPathString?

    @Argument(help: "Output filename (optional).")
    var fileName: String?
    
    mutating func run() async throws {
        
        if outputPath == nil {
            outputPath = .init(rawValue: ((dbPath as NSString).deletingLastPathComponent as NSString).appendingPathComponent("output"))
        }
        if fileName == nil || fileName?.isEmpty == true {
            fileName = ((dbPath as NSString).lastPathComponent as NSString).deletingPathExtension
        }
        let helper = SQCDDatabaseHelper()
        if !SQCDDataModelGenerator(helper: helper)
            .generateCoreDataModel(fromDBPath: dbPath, outputDirectoryPath: outputPath!.rawValue, fileName: fileName) {
            throw ValidationError("Failed to generate Core Data model from database at \(dbPath)")
        }
        NSLog("Compiling xcdatamodel...");
        let process = Process()
        process.launchPath = "/Applications/Xcode.app/Contents/Developer/usr/bin/momc"
        let xcModelpath = (outputPath!.rawValue as NSString).appendingPathComponent("\(fileName!).xcdatamodeld")
        let momdPath = (outputPath!.rawValue as NSString).appendingPathComponent("\(fileName!).momd")
        process.arguments = [xcModelpath, momdPath]
        let block = DispatchWorkItem {
            
        }
        process.terminationHandler = { _ in
            DispatchQueue.main.async(execute: block)
        }
        
        try process.run()
        await withTaskCancellationHandler {
            await withUnsafeContinuation { continuation in
                block.notify(queue: .main) {
                    continuation.resume()
                }
            }
        } onCancel: {
            process.interrupt()
        }
        if process.terminationReason != .exit {
            NSLog("xcdatamodel compilation failed with status \(process.terminationStatus)")
            throw ExitCode(process.terminationStatus)
        }
        let success = await Task.detached { [dbPath, outputPath] in
            SQCDMigrationManager.startDataMigrationWithDBPath(dbPath, momdPath: momdPath, outputPath: outputPath!.rawValue, helper: helper)
        }.value
        if !success {
            throw ValidationError("Data migration failed for database at \(dbPath)")
        }
    }
    
    
    
    struct OutputPathString: ExpressibleByArgument, RawRepresentable {
        
        var rawValue:String
        
        init?(argument: String) {
            rawValue = (argument as NSString).expandingTildeInPath
        }
        
        init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        
    }
    
}
