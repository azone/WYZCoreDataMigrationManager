//
//  WYZCoreDataMigrationManager.h
//  Cichang-iPad
//
//  Created by Yozone Wang on 14-4-1.
//  Copyright (c) 2014年 Yozone Wang. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol WYZCoreDataMigrationManagerDelegate;

@interface WYZCoreDataMigrationManager : NSObject

@property (weak, nonatomic) id<WYZCoreDataMigrationManagerDelegate> delegate;
@property (copy, nonatomic) NSString *type;

- (BOOL)isMigrationNeededForModel:(NSManagedObjectModel *)finalModel storeURL:(NSURL *)storeURL;
- (BOOL)progressivelyMigrateURL:(NSURL *)sourceStoreURL toModel:(NSManagedObjectModel *)finalModel error:(NSError **)error;

@end


@protocol WYZCoreDataMigrationManagerDelegate <NSObject>

@optional
- (void)migrationManager:(WYZCoreDataMigrationManager *)manager withProgress:(CGFloat)progress;

@end