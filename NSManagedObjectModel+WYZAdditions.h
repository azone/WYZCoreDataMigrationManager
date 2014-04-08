//
//  NSManagedObjectModel+WYZAdditions.h
//  Cichang-iPad
//
//  Created by Yozone Wang on 14-4-1.
//  Copyright (c) 2014年 Yozone Wang. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObjectModel (WYZAdditions)

@property (copy, nonatomic) NSURL *hjm_contentURL;

- (NSString *)wyz_modelName;

- (BOOL)wyz_isVersionHashesMatchMappingModelsSourceEntityVersionHashes:(NSArray *)mappingModels;
- (BOOL)wyz_isVersionHashesMatchMappingModelsDestinationEntityVersionHashes:(NSArray *)mappingModels;

@end
