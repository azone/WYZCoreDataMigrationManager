//
//  WYZCoreDataMigrationManager.m
//  Cichang-iPad
//
//  Created by Yozone Wang on 14-4-1.
//  Copyright (c) 2014年 Yozone Wang. All rights reserved.
//

#import "WYZCoreDataMigrationManager.h"
#import "NSManagedObjectModel+WYZAdditions.h"
#import "NSMappingModel+WYZAdditions.h"

@implementation WYZCoreDataMigrationManager

- (id)init {
    self = [super init];
    if (self) {
        self.type = NSSQLiteStoreType;
    }

    return self;
}


- (BOOL)isMigrationNeededForModel:(NSManagedObjectModel *)finalModel storeURL:(NSURL *)storeURL{
    // 如果文件不存在说明是第一次打开，不需要迁移
    if (![[NSFileManager defaultManager] fileExistsAtPath:storeURL.path]) {
        return NO;
    }
    NSError *error;
    NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:self.type URL:storeURL error:&error];
    BOOL isCompatible = [finalModel isConfiguration:nil compatibleWithStoreMetadata:metadata];
    return !isCompatible;
}

- (BOOL)progressivelyMigrateURL:(NSURL *)sourceStoreURL toModel:(NSManagedObjectModel *)finalModel error:(NSError **)error {
    NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:self.type URL:sourceStoreURL error:error];
    if (!metadata) {
        return NO;
    }
    if ([finalModel isConfiguration:nil compatibleWithStoreMetadata:metadata]) {
        return YES;
    }
    NSManagedObjectModel *sourceModel = [NSManagedObjectModel mergedModelFromBundles:nil forStoreMetadata:metadata];
    NSManagedObjectModel *destinationModel = [self nextVersionModelForSourceModel:sourceModel];

    NSArray *mappingModels = [NSMappingModel wyz_mappingModelsFromBundles:nil forSourceModel:sourceModel destinationModel:destinationModel];

    // 如果没找到mapping model或者mapping model匹配不全说明是轻量级迁移
    BOOL isSourceHashesMatch = [sourceModel wyz_isVersionHashesMatchMappingModelsSourceEntityVersionHashes:mappingModels];
    BOOL isDestinationHashesMatch = [destinationModel wyz_isVersionHashesMatchMappingModelsDestinationEntityVersionHashes:mappingModels];
    if ([mappingModels count] == 0 || (!isSourceHashesMatch || !isDestinationHashesMatch)) {
        if (![self lightweightMigrationURL:sourceStoreURL toModel:destinationModel error:error]) {
            return NO;
        }
        return [self progressivelyMigrateURL:sourceStoreURL toModel:finalModel error:error];
    }

    NSMigrationManager *migrationManager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel destinationModel:destinationModel];
    [migrationManager addObserver:self forKeyPath:@"migrationProgress" options:NSKeyValueObservingOptionNew context:NULL];
    NSURL *destinationURL = [self destinationURLWithSourceStoreURL:sourceStoreURL];
    static NSDictionary *options;
    options = @{NSSQLitePragmasOption: @{@"journal_mode" : @"WAL"}};
    BOOL isMigrated = NO;
    for (NSMappingModel *mapping in mappingModels) {
        if ([self.delegate respondsToSelector:@selector(migrationManager:withProgress:)]) {
            [self.delegate migrationManager:self withProgress:0.0f];
        }
        [NSThread sleepForTimeInterval:0.1];
        isMigrated = [migrationManager migrateStoreFromURL:sourceStoreURL
                                                      type:self.type
                                                   options:options
                                          withMappingModel:mapping
                                          toDestinationURL:destinationURL
                                           destinationType:self.type
                                        destinationOptions:options
                                                     error:error];
    }
    [migrationManager removeObserver:self forKeyPath:@"migrationProgress" context:NULL];

    if (!isMigrated) {
        [[NSFileManager defaultManager] removeItemAtURL:[destinationURL URLByDeletingLastPathComponent] error:nil];
        return NO;
    }

    if (![self backupSourceStoreAtURL:sourceStoreURL movingDestinationStoreAtURL:destinationURL error:error]) {
        return NO;
    }

    return [self progressivelyMigrateURL:sourceStoreURL toModel:finalModel error:error];
}

- (BOOL)lightweightMigrationURL:(NSURL *)sourceStoreURL toModel:(NSManagedObjectModel *)destinationModel error:(NSError **)error {
    NSDictionary *storeOptions = @{
            NSMigratePersistentStoresAutomaticallyOption: @YES,
            NSInferMappingModelAutomaticallyOption: @YES,
            NSSQLitePragmasOption: @{@"journal_mode" : @"WAL"}
    };
    NSPersistentStoreCoordinator *storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:destinationModel];
    [storeCoordinator lock];
    NSPersistentStore *persistentStore = [storeCoordinator addPersistentStoreWithType:self.type configuration:nil URL:sourceStoreURL options:storeOptions error:error];
    [storeCoordinator unlock];
    if (!persistentStore) {
        return NO;
    }
    return YES;
}


- (BOOL)backupSourceStoreAtURL:(NSURL *)sourceStoreURL
   movingDestinationStoreAtURL:(NSURL *)destinationStoreURL
                         error:(NSError **)error
{
    NSString *guid = [[NSProcessInfo processInfo] globallyUniqueString];
    NSString *backupPath = [NSTemporaryDirectory() stringByAppendingPathComponent:guid];

    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL isDir = YES;
    if (![fileManager fileExistsAtPath:backupPath isDirectory:&isDir] && isDir) {
        [fileManager createDirectoryAtPath:backupPath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSString *sourceStoreURLDirectory = [sourceStoreURL.path stringByDeletingLastPathComponent];
    NSDirectoryEnumerator *directoryEnumerator = [fileManager enumeratorAtPath:sourceStoreURLDirectory];
    NSString *fileName;
    while ((fileName = [directoryEnumerator nextObject])) {
        NSString *fullPath = [sourceStoreURLDirectory stringByAppendingPathComponent:fileName];
        NSString *tmpPath = [backupPath stringByAppendingPathComponent:fileName];
        if ([fileManager fileExistsAtPath:tmpPath]) {
            [fileManager removeItemAtPath:tmpPath error:nil];
        }
        if (![fileManager moveItemAtPath:fullPath
                                  toPath:tmpPath
                                   error:error]) {
            //Failed to copy the file
            return NO;
        }
    }
    NSString *destinationStoreURLDirectory = [destinationStoreURL.path stringByDeletingLastPathComponent];
    directoryEnumerator = [fileManager enumeratorAtPath:destinationStoreURLDirectory];
    while ((fileName = [directoryEnumerator nextObject])) {
        NSString *fullPath = [destinationStoreURLDirectory stringByAppendingPathComponent:fileName];
        NSString *sourceFullPath = [sourceStoreURLDirectory stringByAppendingPathComponent:fileName];
        if ([fileManager fileExistsAtPath:sourceFullPath]) {
            [fileManager removeItemAtPath:sourceFullPath error:nil];
        }
        if (![fileManager moveItemAtPath:fullPath
                                  toPath:sourceFullPath
                                   error:error]) {
            NSDirectoryEnumerator *backupPathEnumerator = [fileManager enumeratorAtPath:backupPath];
            NSString *backupFileName;
            while ((backupFileName = [backupPathEnumerator nextObject])) {
                //Try to back out the source move first, no point in checking it for errors
                sourceFullPath = [sourceStoreURLDirectory stringByAppendingPathComponent:fileName];
                if ([fileManager fileExistsAtPath:sourceFullPath]) {
                    [fileManager removeItemAtPath:sourceFullPath error:nil];
                }
                [fileManager moveItemAtPath:[backupPath stringByAppendingPathComponent:backupFileName]
                                     toPath:sourceFullPath
                                      error:nil];
            }
            //Failed to copy the file
            [fileManager removeItemAtPath:backupPath error:nil];
            return NO;
        }
    }

    [fileManager removeItemAtPath:backupPath error:nil];
    [fileManager removeItemAtPath:destinationStoreURLDirectory error:nil];

    return YES;
}

- (NSURL *)destinationURLWithSourceStoreURL:(NSURL *)sourceStoreURL {
    // We have a mapping model, time to migrate
    NSString *destinationPath = [sourceStoreURL.path stringByDeletingLastPathComponent];
    destinationPath = [destinationPath stringByAppendingString:@".bak"];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = YES;
    if (![fm fileExistsAtPath:destinationPath isDirectory:&isDir] && isDir) {
        [fm createDirectoryAtPath:destinationPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *storeName = [sourceStoreURL.path lastPathComponent];
    
    return [NSURL fileURLWithPath:[destinationPath stringByAppendingPathComponent:storeName]];
}

- (NSManagedObjectModel *)nextVersionModelForSourceModel:(NSManagedObjectModel *)sourceModel {
    NSArray *modelURLs = [self modelURLs];
    NSManagedObjectModel *nextVersionModel;
    NSString *sourceModelVersionIdentifier = [sourceModel.versionIdentifiers anyObject];
    NSInteger sourceVersionNumber = [sourceModelVersionIdentifier integerValue];
    NSSet *nextVersionIdentifiers = [NSSet setWithObject:[NSString stringWithFormat:@"%d", sourceVersionNumber + 1]];
    for (NSURL *modelURL in modelURLs) {
        if ([modelURL isEqual:[sourceModel wyz_contentURL]]) {
            continue;
        }
        nextVersionModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        if ([nextVersionModel.versionIdentifiers isEqualToSet:nextVersionIdentifiers]) {
            break;
        }
    }
    
    return nextVersionModel;
}

- (NSArray *)modelURLs {
    NSMutableArray *modelURLs = [@[] mutableCopy];
    NSArray *momdPaths = [[NSBundle mainBundle] pathsForResourcesOfType:@"momd" inDirectory:nil];
    for (NSString *momdPath in momdPaths) {
        NSString *momdName = [momdPath lastPathComponent];
        [modelURLs addObjectsFromArray:[[NSBundle mainBundle] URLsForResourcesWithExtension:@"mom" subdirectory:momdName]];
    }
    return [modelURLs copy];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"migrationProgress"]) {
        if ([self.delegate respondsToSelector:@selector(migrationManager:withProgress:)]) {
            [self.delegate migrationManager:self withProgress:[[object valueForKeyPath:keyPath] floatValue]];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
