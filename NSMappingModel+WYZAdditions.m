//
//  NSMappingModel+WYZAdditions.m
//  Cichang-iPad
//
//  Created by Yozone Wang on 14-4-1.
//  Copyright (c) 2014年 Yozone Wang. All rights reserved.
//

#import "NSMappingModel+WYZAdditions.h"

static char kHJMMappingContentURLKey;

@implementation NSMappingModel (WYZAdditions)

- (NSURL *)wyz_contentURL {
    NSURL *url = objc_getAssociatedObject(self, &kHJMMappingContentURLKey);
    if (!url) {
        NSArray *mappingURLs = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"cdm" subdirectory:nil];
        NSMappingModel *mappingModel;
        for (NSURL *mappingURL in mappingURLs) {
            mappingModel = [[NSMappingModel alloc] initWithContentsOfURL:mappingURL];
            if ([mappingModel isEqual:self]) {
                [self setWyz_contentURL:mappingURL];
                return mappingURL;
            }
        }
    }

    return url;
}

- (void)setWyz_contentURL:(NSURL *)wyz_contentURL {
    objc_setAssociatedObject(self, &kHJMMappingContentURLKey, wyz_contentURL, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)wyz_mappingName {
    return [[self.wyz_contentURL lastPathComponent] stringByDeletingPathExtension];
}

+ (NSArray *)wyz_mappingModelsFromBundles:(NSArray *)bundles forSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel {
    NSMutableSet *mappings = [NSMutableSet set];
    NSSet *sourceEntityVersionHashes = [NSSet setWithArray:[sourceModel.entityVersionHashesByName allValues]];
    NSSet *destinationEntityVersionHashes = [NSSet setWithArray:[destinationModel.entityVersionHashesByName allValues]];
    if (!bundles) {
        bundles = @[[NSBundle mainBundle]];
    }
    for (NSBundle *bundle in bundles) {
        NSArray *foundMappingModelURLs = [bundle URLsForResourcesWithExtension:@"cdm" subdirectory:nil];
        for (NSURL *mappingModelURL in foundMappingModelURLs) {
            NSMappingModel *mappingModel = [[NSMappingModel alloc] initWithContentsOfURL:mappingModelURL];
            NSSet *mappingModelSourceEntityVersionHashes = [NSSet setWithArray:[[mappingModel.entityMappingsByName allValues] valueForKeyPath:@"sourceEntityVersionHash"]];
            NSSet *mappingModelDestinationEntityVersionHashes = [NSSet setWithArray:[[mappingModel.entityMappingsByName allValues] valueForKeyPath:@"destinationEntityVersionHash"]];
            if ([mappingModelSourceEntityVersionHashes isSubsetOfSet:sourceEntityVersionHashes]
                && [mappingModelDestinationEntityVersionHashes isSubsetOfSet:destinationEntityVersionHashes]) {
                BOOL shouldContinue = NO;
                for (NSMappingModel *mappingModelInSet in mappings) {
                    NSSet *mappingModelInSetSourceEntityVersionHashes = [NSSet setWithArray:[[mappingModelInSet.entityMappingsByName allValues] valueForKeyPath:@"sourceEntityVersionHash"]];
                    NSSet *mappingModelInSetDestinationEntityVersionHashes = [NSSet setWithArray:[[mappingModelInSet.entityMappingsByName allValues] valueForKeyPath:@"destinationEntityVersionHash"]];
                    
                    if ([mappingModelInSetSourceEntityVersionHashes isEqualToSet:mappingModelSourceEntityVersionHashes]
                        && [mappingModelInSetDestinationEntityVersionHashes isEqualToSet:mappingModelDestinationEntityVersionHashes]) {
                        shouldContinue = YES;
                        break;
                    }
                }
                if (shouldContinue) {
                    continue;
                }
                [mappings addObject:mappingModel];
            }
        }
    }
    
    return [mappings allObjects];
}

@end
