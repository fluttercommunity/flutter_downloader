//
//  FlutterDownloaderDBManager.m
//  Runner
//
//  Author: GABRIEL THEODOROPOULOS.
//

#import "FlutterDownloaderDBManager.h"
#import <sqlite3.h>

@interface FlutterDownloaderDBManager()

@property (nonatomic, strong) NSString *appDirectory;
@property (nonatomic, strong) NSString *databaseFilePath;
@property (nonatomic, strong) NSString *databaseFilename;
@property (nonatomic, strong) NSMutableArray *arrResults;

-(void)copyDatabaseIntoAppDirectory;
-(void)runQuery:(const char *)query withParameters:(NSArray *)parameters isQueryExecutable:(BOOL)queryExecutable;

@end

@implementation FlutterDownloaderDBManager

@synthesize debug;

-(instancetype)initWithDatabaseFilePath:(NSString *)dbFilePath{
    self = [super init];
    if (self) {
        // Get application support directory.
        // Create the directory if it does not already exist.
        NSError *error;
        NSURL *appDirectoryUrl = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                        inDomain:NSUserDomainMask
                                                               appropriateForURL:nil
                                                                          create:YES
                                                                           error:&error];
        self.appDirectory = appDirectoryUrl.path;
        if (debug) {
            if (error) {
                NSLog(@"Get application support directory error: %@", error);
            }
        }

        // Keep the database filepath
        self.databaseFilePath = dbFilePath;

        // Keep the database filename.
        self.databaseFilename = [dbFilePath lastPathComponent];

        // Copy the database file into the app directory if necessary.
        [self copyDatabaseIntoAppDirectory];
    }
    return self;
}

// Will be removed in the next major version.
-(void)copyDatabaseIntoAppDirectory{
    // Check if the database file exists in the app directory.
    NSString *destinationPath = [self.appDirectory stringByAppendingPathComponent:self.databaseFilename];
    if (![[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {

        // Attemp database file migration from the documents directory if exists
        NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *migrationSourcePath = [documentsDirectory stringByAppendingPathComponent:self.databaseFilename];
        NSError *error;
        if ([[NSFileManager defaultManager] fileExistsAtPath:migrationSourcePath]) {
            // Migrate the database file from the documents directory to the app directory
            [[NSFileManager defaultManager] moveItemAtPath:migrationSourcePath toPath:destinationPath error:&error];    
        } else {
            // The database file does not exist in the app directory, so copy it from the main bundle now.
            [[NSFileManager defaultManager] copyItemAtPath:self.databaseFilePath toPath:destinationPath error:&error];
        }
        
        // Check if any error occurred during copying and display it.
        if (debug) {
            if (error != nil) {
                NSLog(@"%@", [error localizedDescription]);
            } else {
                NSLog(@"create DB successfully");
            }
        }
    }
}


- (void)runQuery:(const char *)query withParameters:(NSArray *)parameters isQueryExecutable:(BOOL)queryExecutable {

    if (debug) {
        NSLog(@"execute query: %s", query);
    }

    // Create a sqlite object.
    sqlite3 *sqlite3Database;
    
    // Set the database file path.
    NSString *databasePath = [self.appDirectory stringByAppendingPathComponent:self.databaseFilename];
    
    // Initialize the results array.
    if (self.arrResults != nil) {
        [self.arrResults removeAllObjects];
        self.arrResults = nil;
    }
    self.arrResults = [[NSMutableArray alloc] init];
    
    // Initialize the column names array.
    if (self.arrColumnNames != nil) {
        [self.arrColumnNames removeAllObjects];
        self.arrColumnNames = nil;
    }
    self.arrColumnNames = [[NSMutableArray alloc] init];
    
    // Open the database.
    int openDatabaseResult = sqlite3_open([databasePath UTF8String], &sqlite3Database);
    if (openDatabaseResult != SQLITE_OK) {
        if (debug) {
            NSLog(@"error opening the database with error no.: %d", openDatabaseResult);
        }
        return;
    }
    
    if (openDatabaseResult == SQLITE_OK) {
        if (debug) {
            NSLog(@"open DB successfully");
        }

        // Declare a sqlite3_stmt object in which will be stored the query after having been compiled into a SQLite statement.
        sqlite3_stmt *compiledStatement;

        // Prepare the SQL query.
        int prepareStatementResult = sqlite3_prepare_v2(sqlite3Database, query, -1, &compiledStatement, NULL);
        if (prepareStatementResult == SQLITE_OK) {
            // Bind parameters if provided.
            if (parameters != nil && parameters.count > 0) {
                for (int i = 0; i < parameters.count; i++) {
                    id parameter = parameters[i];
                    int bindResult = SQLITE_OK;

                    if ([parameter isKindOfClass:[NSString class]]) {
                        const char *paramStr = [parameter UTF8String];
                        bindResult = sqlite3_bind_text(compiledStatement, i + 1, paramStr, -1, SQLITE_TRANSIENT);
                    } else if ([parameter isKindOfClass:[NSNumber class]]) {
                        if (strcmp([parameter objCType], @encode(int)) == 0) {
                            int intValue = [parameter intValue];
                            bindResult = sqlite3_bind_int(compiledStatement, i + 1, intValue);
                        } else if (strcmp([parameter objCType], @encode(long long)) == 0) {
                            long long longValue = [parameter longLongValue];
                            bindResult = sqlite3_bind_int64(compiledStatement, i + 1, longValue);
                        }
                    }
                    if (bindResult != SQLITE_OK) {
                        NSLog(@"Error binding parameter at index %d: %s", i, sqlite3_errmsg(sqlite3Database));
                    }
                }
            }

            // Execute the query.
            if (queryExecutable) {
                int executeQueryResults = sqlite3_step(compiledStatement);
                if (executeQueryResults == SQLITE_DONE) {
                    // Keep the affected rows.
                    self.affectedRows = sqlite3_changes(sqlite3Database);
                    
                    // Keep the last inserted row ID.
                    self.lastInsertedRowID = sqlite3_last_insert_rowid(sqlite3Database);
                } else {
                    // If could not execute the query, show the error message on the debugger.
                    if (debug) {
                        NSLog(@"DB Error: %s", sqlite3_errmsg(sqlite3Database));
                    }
                }
            } else {
                // This is the case of loading data from the database.

                // Declare an array to keep the data for each fetched row.
                NSMutableArray *arrDataRow;

                // Loop through the results and add them to the results array row by row.
                while (sqlite3_step(compiledStatement) == SQLITE_ROW) {
                    // Initialize the mutable array that will contain the data of a fetched row.
                    arrDataRow = [[NSMutableArray alloc] init];

                    // Get the total number of columns.
                    int totalColumns = sqlite3_column_count(compiledStatement);

                    // Go through all columns and fetch each column data.
                    for (int i = 0; i < totalColumns; i++) {
                        // Convert the column data to text (characters).
                        char *dbDataAsChars = (char *)sqlite3_column_text(compiledStatement, i);

                        // If there are contents in the current column (field), then add them to the current row array.
                        if (dbDataAsChars != NULL) {
                            // Convert the characters to string.
                            [arrDataRow addObject:[NSString stringWithUTF8String:dbDataAsChars]];
                        }

                        // Keep the current column name.
                        if (self.arrColumnNames.count != totalColumns) {
                            dbDataAsChars = (char *)sqlite3_column_name(compiledStatement, i);
                            [self.arrColumnNames addObject:[NSString stringWithUTF8String:dbDataAsChars]];
                        }
                    }

                    // Store each fetched data row in the results array, but first check if there is actually data.
                    if (arrDataRow.count > 0) {
                        [self.arrResults addObject:arrDataRow];
                    }
                }
            }

            // Release the compiled statement from memory.
            sqlite3_finalize(compiledStatement);
        } else {
            // In the database cannot be opened then show the error message on the debugger.
            if (debug) {
                NSLog(@"%s", sqlite3_errmsg(sqlite3Database));
            }
        }

        // Close the database.
        sqlite3_close(sqlite3Database);
    }
}

-(NSArray *)loadDataFromDB:(NSString *)query withParameters:(NSArray *)parameters{
    // Run the query and indicate that is not executable.
    // The query string is converted to a char* object.
    [self runQuery:[query UTF8String] withParameters:parameters isQueryExecutable:NO];
    // Returned the loaded results.
    return (NSArray *)self.arrResults;
}



- (void)executeQuery:(NSString *)query withParameters:(NSArray *)parameters {
    // Run the query with parameters.
    [self runQuery:[query UTF8String] withParameters:parameters isQueryExecutable:YES];
}

@end
