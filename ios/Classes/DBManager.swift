//import Foundation
//import SQLite3
//
//class DBManager : NSObject {
//
//    @objc var arrColumnNames: [String] = []
//    @objc var affectedRows: Int32 = 0
//    @objc var lastInsertedRowID: Int64 = 0
//    @objc var debug: Bool = false
//
//    private var documentsDirectory: String!
//    private var databaseFilePath: String!
//    private var databaseFilename: String!
//    private var arrResults: [[String]] = []
//
//
//    @objc convenience init(databaseFilePath: String!) {
//        self.init()
//
//        documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
//
//        // Keep the database filepath
//        self.databaseFilePath = databaseFilePath
//
//        // Keep the database filename.
//        databaseFilename = databaseFilePath.lastPathComponent()
//
//        // Copy the database file into the documents directory if necessary.
//        copyDatabaseIntoDocumentsDirectory()
//    }
//
//    func copyDatabaseIntoDocumentsDirectory() {
//        // Check if the database file exists in the documents directory.
//        let destinationPath:String! = self.documentsDirectory.appendingPathComponent(self.databaseFilename)
//        if !FileManager.default.fileExists(atPath: destinationPath) {
//            // The database file does not exist in the documents directory, so copy it from the main bundle now.
//            let sourcePath:String! = self.databaseFilePath
//            // Check if any error occurred during copying and display it.
//            do {
//                try FileManager.default.copyItem(atPath: sourcePath, toPath:destinationPath)
//                NSLog("create DB successfully")
//            } catch {
//                print("Error creating DB: \(error).")
//            }
//        }
//    }
//
//    func runQuery(_ query: UnsafePointer<CChar>!, isQueryExecutable queryExecutable: Bool) {
//        if debug {
//            print("execute query: \(String(describing: query))")
//        }
//
//        // Create a sqlite object.
//        var sqlite3Database: OpaquePointer?
//
//        // Set the database file path.
//        let databasePath = self.documentsDirectory.appendingPathComponent(self.databaseFilename)
//
//        // Initialize the results array.
//        arrResults = []
//
//        // Initialize the column names array.
//        arrColumnNames = []
//
//
//        // Open the database.
//        let openDatabaseResult:Int32 = sqlite3_open(databasePath, &sqlite3Database)
//        if openDatabaseResult == SQLITE_OK {
//            if debug {
//                print("open DB successfully")
//            }
//
//            // Declare a sqlite3_stmt object in which will be stored the query after having been compiled into a SQLite statement.
//            var compiledStatement: OpaquePointer?
//
//            // Load all data from database to memory.
//            let prepareStatementResult = sqlite3_prepare_v2(sqlite3Database, query, -1, &compiledStatement, nil)
//            if prepareStatementResult == SQLITE_OK {
//                // Check if the query is non-executable.
//                if !queryExecutable {
//                    // In this case data must be loaded from the database.
//
//                    // Declare an array to keep the data for each fetched row.
//                    var arrDataRow: [String]
//
//                    // Loop through the results and add them to the results array row by row.
//                    while sqlite3_step(compiledStatement) == SQLITE_ROW {
//                        // Initialize the mutable array that will contain the data of a fetched row.
//                        arrDataRow = []
//
//                        // Get the total number of columns.
//                        let totalColumns = sqlite3_column_count(compiledStatement)
//
//                        // Go through all columns and fetch each column data.
//                        for i in 0..<totalColumns {
//                            // Convert the column data to text (characters).
//                            let dbDataAsChars = sqlite3_column_text(compiledStatement, i)
//
//                            // If there are contents in the currenct column (field) then add them to the current row array.
//                            if dbDataAsChars != nil {
//                                // Convert the characters to string.
//                                arrDataRow.append(String(cString: dbDataAsChars!))
//                            }
//
//                            // Keep the current column name.
//                            if self.arrColumnNames.count != totalColumns {
//                                let columnNameData = sqlite3_column_name(compiledStatement, i)
//                                self.arrColumnNames.append(String(cString: columnNameData!))
//                            }
//                         }
//
//                        // Store each fetched data row in the results array, but first check if there is actually data.
//                        if arrDataRow.count > 0 {
//                            arrResults.append(arrDataRow)
//                        }
//                    }
//                }
//                else {
//                    // This is the case of an executable query (insert, update, ...).
//
//                    // Execute the query.
//                    let executeQueryResults = sqlite3_step(compiledStatement)
//                    if executeQueryResults == SQLITE_DONE {
//                        // Keep the affected rows.
//                        self.affectedRows = sqlite3_changes(sqlite3Database)
//
//                        // Keep the last inserted row ID.
//                        self.lastInsertedRowID = sqlite3_last_insert_rowid(sqlite3Database)
//                    }
//                    else {
//                        // If could not execute the query show the error message on the debugger.
//                        if debug {
//                            let errmsg = String(cString: sqlite3_errmsg(sqlite3Database))
//                            print("DB Error: \(errmsg)")
//                        }
//                    }
//                }
//            }
//            else {
//                // In the database cannot be opened then show the error message on the debugger.
//                if debug {
//                    let errmsg = String(cString: sqlite3_errmsg(sqlite3Database))
//                    print(errmsg)
//                }
//            }
//
//            // Release the compiled statement from memory.
//            sqlite3_finalize(compiledStatement)
//        }
//
//        // Close the database.
//        sqlite3_close(sqlite3Database)
//    }
//
//    @objc func loadDataFromDB(_ query: String) -> [[String]] {
//        // Run the query and indicate that is not executable.
//        // The query string is converted to a char* object.
//        runQuery(query, isQueryExecutable:false)
//
//        // Returned the loaded results.
//        return self.arrResults;
//    }
//
//    @objc func executeQuery(_ query: String) {
//        // Run the query and indicate that is executable.
//        runQuery(query, isQueryExecutable:true)
//    }
//}
//
//extension String {
//    func appendingPathComponent(_ path: String) -> String {
//        let nsSt = self as NSString
//        return nsSt.appendingPathComponent(path)
//    }
//
//    func lastPathComponent() -> String {
//        let nsSt = self as NSString
//        return nsSt.lastPathComponent
//    }
//}
