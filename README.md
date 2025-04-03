WYZCoreDataMigrationManager
===========================

前一段时间遇到了一些Core Data数据迁移方面的问题，学到了不少东西。于是就总结了一下写了一个Core Data数据迁移的类，也写了一篇博客[如何运用更聪明的办法进行Core Data数据迁移](http://firestudio.dev/blog/2014/04/04/how-to-make-core-data-migration-smarter/)，希望能帮助那些对Core Data数据库迁移有疑问的同志们少走一些弯路吧。

## 使用方法

这个类使用起来很简单，只有很少的接口暴露出来

1. 判断当前的数据库模型是否和最终的数据模型有冲突

```objc
 // 判断数据库版本是否有兼容问题，我这里用的是MagicalRecord
 NSURL *finalStoreURL = [NSPersistentStore MR_urlForStoreName:[MagicalRecord defaultStoreName]];
 NSManagedObjectModel *defaultMOM = [NSManagedObjectModel MR_defaultManagedObjectModel];
 WYZCoreDataMigrationManager *migrationManager = [[WYZCoreDataMigrationManager alloc] init];
 BOOL isNeedMigration = [migrationManager isMigrationNeededForModel:defaultMOM storeURL:finalStoreURL];
```

2. 如果没有冲突直接加载UI，否则进行数据库迁移、合并：

```objc
if (isNeedMigration) {
	// 升级期间禁止自动锁屏
	[UIApplication sharedApplication].idleTimerDisabled = YES;
	// 将升级过程放入后台执行代码，防止用户按了home键之后进程被系统杀死
    __block UIBackgroundTaskIdentifier bgTask;
    bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        // 这里可以提示正在升级
        migrationManager.delegate = self;
        NSError *error = nil;
        NSInteger maxTry = 3;
        NSInteger currentTry = 1;
        BOOL isMigrationSuccess = NO;
        while (!isMigrationSuccess && currentTry <= maxTry) {
            isMigrationSuccess = [migrationManager progressivelyMigrateURL:finalStoreURL toModel:defaultMOM error:&error];
            if (!isMigrationSuccess) {
                currentTry++;
            }
        } 
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
        [NSThread sleepForTimeInterval:0.5];
        [UIApplication sharedApplication].idleTimerDisabled = NO;
    });
}
```

3. 实现delegate方法，更新进度

```objc
- (void)migrationManager:(WYZCoreDataMigrationManager *)manager withProgress:(CGFloat)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"当前完成：%.2f%%", progress * 100);
    });
}
```

## 要注意以下几点：

1. 升级过程不能放在入口函数并用同步线程，如果是数据量较大的重量级迁移，则可能由于入口函数超过一定时间没有返回YES/NO而导致应用进程被系统杀死。我的做法是先返回YES/NO，Core Data在异步线程进行数据迁移，前已完成之后发送通知，应用收到通知后再加载UI。
2. 各个版本数据库模型的versionIdentifiers要填写，其值为版本的序列，比如第一个版本为1，第二个版本为2等……，这样是为了方便WYZCoreDataMigrationManager找到当前数据库模型的下一个版本
3. 尽量将mapping model拆分成多个以节约内存开销，并且确保每个mapping model中的entity是于其他mapping model是没有任何关系的（否则编译时会报错）
