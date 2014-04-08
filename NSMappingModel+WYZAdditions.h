//
//  NSMappingModel+WYZAdditions.h
//  Cichang-iPad
//
//  Created by Yozone Wang on 14-4-1.
//  Copyright (c) 2014年 Yozone Wang. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSMappingModel (WYZAdditions)

@property (copy, nonatomic) NSURL *hjm_contentURL;

- (NSString *)wyz_mappingName;

+ (NSArray *)wyz_mappingModelsFromBundles:(NSArray *)bundles forSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel;

@end
