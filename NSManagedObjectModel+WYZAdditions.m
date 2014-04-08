//
//  NSManagedObjectModel+WYZAdditions.m
//  Cichang-iPad
//
//  Created by Yozone Wang on 14-4-1.
//  Copyright (c) 2014年 Yozone Wang. All rights reserved.
//

#import "NSManagedObjectModel+WYZAdditions.h"

static char kHJMModelContentURLKey;

@implementation NSManagedObjectModel (WYZAdditions)

- (NSURL *)wyz_contentURL {
    NSURL *url = objc_getAssociatedObject(self, &kHJMModelContentURLKey);
    if (!url) {
        NSArray *momdArray = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"momd" subdirectory:nil];
        for (NSString *momdPath in momdArray) {
            NSString *momdName = [momdPath lastPathComponent];
            NSArray *momURLs = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"mom" subdirectory:momdName];
            for (NSURL *momURL in momURLs) {
                NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:momURL];
                if ([mom isEqual:self]) {
                    [self setWyz_contentURL:momURL];
                    url = momURL;
                }
            }
        }
    }
    return url;
}

- (void)setWyz_contentURL:(NSURL *)wyz_contentURL {
    objc_setAssociatedObject(self, &kHJMModelContentURLKey, wyz_contentURL, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)wyz_modelName {
    return [[self.wyz_contentURL lastPathComponent] stringByDeletingPathExtension];;
}

- (BOOL)wyz_isVersionHashesMatchMappingModelsSourceEntityVersionHashes:(NSArray *)mappingModels {
    NSSet *versionHashes = [NSSet setWithArray:[self.entityVersionHashesByName allValues]];
    NSMutableSet *mappingModelSourceHashes = [NSMutableSet set];
    for (NSMappingModel *mappingModel in mappingModels) {
        NSSet *sourceHashes = [NSSet setWithArray:[[mappingModel.entityMappingsByName allValues] valueForKeyPath:@"sourceEntityVersionHash"]];
        [mappingModelSourceHashes unionSet:sourceHashes];
    }
    return [versionHashes isEqualToSet:mappingModelSourceHashes];
}

- (BOOL)wyz_isVersionHashesMatchMappingModelsDestinationEntityVersionHashes:(NSArray *)mappingModels {
    NSSet *versionHashes = [NSSet setWithArray:[self.entityVersionHashesByName allValues]];
    NSMutableSet *mappingModelDestinationHashes = [NSMutableSet set];
    for (NSMappingModel *mappingModel in mappingModels) {
        NSSet *destinationHashes = [NSSet setWithArray:[[mappingModel.entityMappingsByName allValues] valueForKeyPath:@"destinationEntityVersionHash"]];
        [mappingModelDestinationHashes unionSet:destinationHashes];
    }
    return [versionHashes isEqualToSet:mappingModelDestinationHashes];
}

@end
