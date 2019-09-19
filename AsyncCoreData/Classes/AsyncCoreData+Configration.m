//
//  AsyncCoreData+Configration.m
//  AsyncCoreData
//
//  Created by 罗亮富 on 2019/1/15.
//

#import "AsyncCoreData+Configration.h"

extern NSMutableDictionary *sDataBaseCacheMap;
extern NSMapTable *sPersistantStoreMap;
extern NSMutableDictionary *sPersistantStoreClassMap;

extern NSMutableDictionary *sSettingDBValuesBlockMap;
extern NSMutableDictionary *sGettingDBValuesBlockMap;

extern NSRunLoop *sBgNSRunloop;

@implementation AsyncCoreData (Configration)

+(void)setPersistantStore:(nullable NSURL *)persistantFileUrl withModel:(nonnull NSString *)modelName completion:(void(^)(void))mainThreadBlock {
    [self setPersistantStore:persistantFileUrl withModel:modelName icloudStoreName:nil completion:mainThreadBlock];
}

+(void)setPersistantStore:(nullable NSURL *)persistantFileUrl
                withModel:(nonnull NSString *)modelName
            icloudStoreName:(nullable NSString *)iName
               completion:(void(^)(void))mainThreadBlock {
    
    NSURL *destUrl = persistantFileUrl;
    if(!destUrl)
    {
        NSURL *dir = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
        destUrl = [dir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",modelName]];
    }
    
    NSURL *coreDataModelFileUrl = [[NSBundle mainBundle] URLForResource:modelName withExtension:@"momd"];
    NSString *key = destUrl.absoluteString;
    
    //定义具体执行业务的block 后续代码会保证这个block永远只会在同一个线程执行
    void (^busniessBlock)(void) =  ^{
        
        NSPersistentStoreCoordinator *persistantStoreCord = [sPersistantStoreMap objectForKey:key];
        BOOL needAddPst = NO;
        if(!persistantStoreCord) {
            needAddPst = YES;
            NSManagedObjectModel *mobjModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:coreDataModelFileUrl];
            
            persistantStoreCord = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mobjModel];
            
            //因为NSPersistentStoreCoordinatorStoresWillChangeNotification会在addPersistentStoreWithType时候触发，所以这里保存persistantStoreCord要在addPersistentStoreWithType 之前
            [sPersistantStoreMap setObject:persistantStoreCord forKey:key];
            
           
           // [sPersistantStoreMap setObject:persistantStoreCord forKey:key];
        }
        
        NSString *classIndependentKey = NSStringFromClass([self class]);
        NSPersistentStoreCoordinator *psc = [sPersistantStoreClassMap objectForKey:classIndependentKey];
        
        if(!psc || psc != persistantStoreCord) {
            @synchronized(sPersistantStoreClassMap) {
                [sPersistantStoreClassMap setObject:persistantStoreCord forKey:classIndependentKey];
            }
        }
        
        if(needAddPst) {
            
            NSError *error = nil;
            NSDictionary *options;
            if(iName){
                options = @{NSMigratePersistentStoresAutomaticallyOption:@YES,
                            NSInferMappingModelAutomaticallyOption:@YES,
                            NSPersistentStoreUbiquitousContentNameKey:iName,
                            };
                [self registerForiCloudNotificationsForPersistentCoordinator:persistantStoreCord];
                
            }
            else {
                options = @{NSMigratePersistentStoresAutomaticallyOption:@YES,
                            NSInferMappingModelAutomaticallyOption:@YES,
                            };
            }

            [persistantStoreCord addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:destUrl options:options error:&error];
             NSAssert(!error, @"persistentStoreCord error %@",error.description);
        }
        
        
        main_task(mainThreadBlock);
    };
    
    background_async(busniessBlock);
}

+(nullable NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    NSString *key = NSStringFromClass([self class]);
    return  [sPersistantStoreClassMap objectForKey:key];
}

+(void)invalidatePersistantSotre {
    NSString *key = NSStringFromClass([self class]);
    [sPersistantStoreClassMap removeObjectForKey:key];
}


+(void)setModelToDataBaseMapper:(nonnull T_ModelToManagedObjectBlock)mapper forEntity:(nonnull NSString *)entityName {
    [sSettingDBValuesBlockMap setObject:mapper forKey:entityName];
}

+(void)setModelFromDataBaseMapper:(nonnull T_ModelFromManagedObjectBlock)mapper forEntity:(nonnull NSString *)entityName {
    [sGettingDBValuesBlockMap setObject:mapper forKey:entityName];
}

+(nullable id)inter_classSharedValueFromMap:(NSDictionary *)map {
    
    Class cls = [self class];
    NSString *key;
    id retValue;
    while (cls) {
        key = NSStringFromClass(cls);
        retValue = [map objectForKey:key];
        if(retValue)
            break;
        cls = [cls superclass];
    }
    return retValue;
}


+(NSManagedObjectContext *)newContext {
#warning test
#if 1
    static NSManagedObjectContext *context = nil;
    if(!context) {
        context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        NSPersistentStoreCoordinator *psc = [self  persistentStoreCoordinator];
        [context setPersistentStoreCoordinator:psc];
    }
    return context;
#else
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [context setPersistentStoreCoordinator:[self  persistentStoreCoordinator]];
    return context;
#endif

}

#pragma mark- icloud
+ (void)registerForiCloudNotificationsForPersistentCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    [notificationCenter addObserver:self
                           selector:@selector(storesWillChange:)
                               name:NSPersistentStoreCoordinatorStoresWillChangeNotification
                             object:persistentStoreCoordinator];
    
    [notificationCenter addObserver:self
                           selector:@selector(storesDidChange:)
                               name:NSPersistentStoreCoordinatorStoresDidChangeNotification
                             object:persistentStoreCoordinator];
    
    [notificationCenter addObserver:self
                           selector:@selector(persistentStoreDidImportUbiquitousContentChanges:)
                               name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                             object:persistentStoreCoordinator];
}

+(void)storesWillChange:(NSNotification *)notification {
    NSLog(@"%s:%@",__PRETTY_FUNCTION__,notification);
}

+(void)storesDidChange:(NSNotification *)notification {
    NSLog(@"%s:%@",__PRETTY_FUNCTION__,notification);
#warning 新创建context可能没有卵用哦
    NSManagedObjectContext *context = [self newContext];
    
    [context performBlockAndWait:^{
        NSError *error;
        
        if ([context hasChanges]) {
            BOOL success = [context save:&error];
            
            if (!success && error) {
                // 执行错误处理
                NSLog(@"%@",[error localizedDescription]);
            }
        }
        
        [context reset];
    }];
}

+(void)persistentStoreDidImportUbiquitousContentChanges:(NSNotification *)changeNotification {
#warning 新创建context可能没有卵用哦
    NSLog(@"%s:%@",__PRETTY_FUNCTION__,changeNotification);
    NSManagedObjectContext *context = [self newContext];
    
    [context performBlock:^{
        [context mergeChangesFromContextDidSaveNotification:changeNotification];
    }];
}

@end

#import "AsyncCoreData+Configration.h"
