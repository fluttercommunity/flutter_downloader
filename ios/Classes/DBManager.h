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

<<<<<<< HEAD
- (void)addLazilyColumnForTable:(const char *)table
                         column:(const char *)column
                           type:(const char *)type
                   defaultValue:(const char *)defaultValue;

-(NSArray *)loadDataFromDB:(NSString *)query;
=======
-(NSArray *)loadDataFromDB:(NSString *)query withParameters:(NSArray *)parameters;
>>>>>>> 1d19dbb (Security (#887))

-(void)executeQuery:(NSString *)query withParameters:(NSArray *)parameters;

@end
