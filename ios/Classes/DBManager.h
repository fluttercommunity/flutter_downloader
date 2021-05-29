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

-(NSArray *)loadDataFromDB:(NSString *)query;

-(void)executeQuery:(NSString *)query;

@end
