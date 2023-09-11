//
//  DBManager.h
//  Runner
//
//  Author: GABRIEL THEODOROPOULOS.
//

#import <Foundation/Foundation.h>

@interface DBManager : NSObject

@property (nonatomic, strong) NSMutableArray *arrColumnNames;

@property (nonatomic) int affectedRows;

@property (nonatomic) long long lastInsertedRowID;

@property (nonatomic) BOOL debug;

-(instancetype)initWithDatabaseFilePath:(NSString *)dbFilePath;

-(NSArray *)loadDataFromDB:(NSString *)query withParameters:(NSArray *)parameters;

- (void)addLazilyColumnForTable:(const char *)table
                         column:(const char *)column
                           type:(const char *)type
                   defaultValue:(const char *)defaultValue;

-(void)executeQuery:(NSString *)query withParameters:(NSArray *)parameters;

@end
