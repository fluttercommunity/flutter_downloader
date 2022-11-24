//
//  DBManager.m
//  Runner
//
//  Author: GABRIEL THEODOROPOULOS.
//

#import "DBManager.h"
#import <sqlite3.h>

@interface DBManager ()

@property(nonatomic, strong) NSString *appDirectory;
@property(nonatomic, strong) NSString *databaseFilePath;
@property(nonatomic, strong) NSString *databaseFilename;
@property(nonatomic, strong) NSMutableArray *arrResults;
@property(nonatomic) int version;
@property NSDictionary *migrations;

- (void)copyDatabaseIntoAppDirectory;

- (void)runQuery:(const char *)query isQueryExecutable:(BOOL)queryExecutable;

@end

@implementation DBManager

@synthesize debug;

// Version of the database
const int dbVersion = 2;

- (instancetype)initWithDatabaseFilePath:(NSString *)dbFilePath {
    self = [super init];
    if (self) {
        self.appDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];

        // Keep the database filepath
        self.databaseFilePath = dbFilePath;

        // Keep the database filename.
        self.databaseFilename = [dbFilePath lastPathComponent];

        // Copy the database file into the app directory if necessary.
        [self copyDatabaseIntoAppDirectory];
        // run db migrations if necessary
        self.version = dbVersion;

        // Keep track of migration code for the database
        // To add a new migration, add a new entry to the dictionary, where the new db version is the key
        // and the value will be a block that is executed when this migration is applied.
        // Migrations will be applied in order.
        self.migrations = @{
                @1: ^(DBManager *db) {
                    [db executeQuery:@"CREATE TABLE version(version INTEGER UNIQUE NOT NULL);"];
                    [db executeQuery:@"INSERT INTO version(version) VALUES(1);"];
                },
                @2: ^(DBManager *db) {
                    [db executeQuery:@"ALTER TABLE task ADD COLUMN allow_cellular INTEGER DEFAULT TRUE;"];
                }
        };
        [self migrateDatabase];
    }
    return self;
}

- (void)migrateDatabase {
    int hasVersionTable = [[self getSingleRecord:@"SELECT EXISTS( SELECT 1 from sqlite_schema where tbl_name = 'version')"][0] intValue];

    // DB does not yet have a version table, so we need to create it first. This is the very first migration we apply.
    if (hasVersionTable == 0) {
        ((void (^)(DBManager *)) self.migrations[@1])(self);
    }
    // in case the version table didn't exist yet, and we already have more than one db migration
    // we follow the creation of the table up with further migrations.
    // Otherwise, our work here is done, and we abort early.
    if(self.version == 1) {
        return;
    }
    NSArray *record = [self getSingleRecord:@"SELECT version from version LIMIT 1"];
    int version = [record[0] intValue];
    // nothing to do, move on
    if (version == self.version) {
        return;
    }

    if (debug) {
        NSLog(@"Migrating from %d to %d", version, self.version);
    }
    NSUInteger i;
    for (i = (NSUInteger) version; i <= self.version; i++) {
        void (^migration)(DBManager *) = (void (^)(DBManager *)) self.migrations[@(i + 1)];
        if (migration != nil) {
            migration(self);
        }
    }
    [self executeQuery:[NSString stringWithFormat:@"UPDATE version SET version = %d", self.version]];
}

// Executes a query to load data according to the query and unwraps the result to only be
// a single array with the actual result values.
- (NSArray *)getSingleRecord:(NSString *)forQuery {
    NSArray *records = [[NSArray alloc] initWithArray:[self loadDataFromDB:forQuery]];
    NSArray *record = [records firstObject];

    return record;
}

// Will be removed in the next major version.
- (void)copyDatabaseIntoAppDirectory {
    // Check if the database file exists in the documents directory.
    NSString *destinationPath = [self.appDirectory stringByAppendingPathComponent:self.databaseFilename];
    if (![[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
        // The database file does not exist in the documents directory, so copy it from the main bundle now.
        NSString *sourcePath = self.databaseFilePath;
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:destinationPath error:&error];

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

- (void)runQuery:(const char *)query isQueryExecutable:(BOOL)queryExecutable {
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
    if (debug) {
        NSLog(@"open DB successfully");
    }
    sqlite3_stmt *compiledStatement;
    int prepareStatementResult = sqlite3_prepare_v2(sqlite3Database, query, -1, &compiledStatement, NULL);
    if (prepareStatementResult == SQLITE_OK) {
        // Check if the query is non-executable.
        if (!queryExecutable) {
            // In this case data must be loaded from the database.

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
                    char *dbDataAsChars = (char *) sqlite3_column_text(compiledStatement, i);

                    // If there are contents in the currenct column (field) then add them to the current row array.
                    if (dbDataAsChars != NULL) {
                        // Convert the characters to string.
                        [arrDataRow addObject:[NSString stringWithUTF8String:dbDataAsChars]];
                    }

                    // Keep the current column name.
                    if (self.arrColumnNames.count != totalColumns) {
                        dbDataAsChars = (char *) sqlite3_column_name(compiledStatement, i);
                        [self.arrColumnNames addObject:[NSString stringWithUTF8String:dbDataAsChars]];
                    }
                }

                // Store each fetched data row in the results array, but first check if there is actually data.
                if (arrDataRow.count > 0) {
                    [self.arrResults addObject:arrDataRow];
                }
            }
        } else {
            // This is the case of an executable query (insert, update, ...).

            // Execute the query.
            int executeQueryResults = sqlite3_step(compiledStatement);
            if (executeQueryResults == SQLITE_DONE) {
                // Keep the affected rows.
                self.affectedRows = sqlite3_changes(sqlite3Database);

                // Keep the last inserted row ID.
                self.lastInsertedRowID = sqlite3_last_insert_rowid(sqlite3Database);
            } else {
                // If could not execute the query show the error message on the debugger.
                if (debug) {
                    NSLog(@"DB Error: %s", sqlite3_errmsg(sqlite3Database));
                }
            }
        }
    } else {
        // In the database cannot be opened then show the error message on the debugger.
        if (debug) {
            NSLog(@"%s", sqlite3_errmsg(sqlite3Database));
        }
    }
    sqlite3_finalize(compiledStatement);

    // Close the database.
    sqlite3_close(sqlite3Database);
}

- (NSArray *)loadDataFromDB:(NSString *)query {
    // Run the query and indicate that is not executable.
    // The query string is converted to a char* object.
    [self runQuery:[query UTF8String] isQueryExecutable:NO];

    // Returned the loaded results.
    return (NSArray *) self.arrResults;
}

- (void)executeQuery:(NSString *)query {
    // Run the query and indicate that is executable.
    [self runQuery:[query UTF8String] isQueryExecutable:YES];
}

@end
