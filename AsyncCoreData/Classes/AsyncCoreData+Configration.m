//
//  AsyncCoreData+Configration.m
//  AsyncCoreData
//
//  Created by 罗亮富 on 2019/1/15.
//

#import "AsyncCoreData+Configration.h"

extern NSMutableDictionary<NSString *, NSCache *> *sDataBaseCacheMap;
extern NSMapTable *sPersistantStoreMap;
extern NSMutableDictionary *sPersistantStoreClassMap;

extern NSMutableDictionary *sSettingDBValuesBlockMap;
extern NSMutableDictionary *sGettingDBValuesBlockMap;

extern NSRunLoop *sBgNSRunloop;

static NSMutableDictionary *iCloudEnabledClassMap;
static NSMutableDictionary *sharedMainContextMap;
static NSMutableDictionary *sharedRunLoopMap;

NSMutableSet *disabledCacheEntities;


@implementation AsyncCoreData (Configration)

+(void)setPersistantStore:(nullable NSURL *)persistantFileUrl withModel:(nonnull NSString *)modelName completion:(void(^)(void))mainThreadBlock {
    [self setPersistantStore:persistantFileUrl withModel:modelName icloudStoreName:nil completion:mainThreadBlock];
}

+(void)setPersistantStore:(nullable NSURL *)persistantFileUrl
                withModel:(nonnull NSString *)modelName
            icloudStoreName:(nullable NSString *)iName
               completion:(void(^)(void))mainThreadBlock {
    //清除之前的共享context
    [sharedMainContextMap removeObjectForKey:NSStringFromClass([self class])];
    
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
                
                if(!iCloudEnabledClassMap)
                    iCloudEnabledClassMap = [NSMutableDictionary dictionaryWithCapacity:3];
                
                
                [iCloudEnabledClassMap setObject:@YES forKey:NSStringFromClass([self class])];
            }
            else {
                options = @{NSMigratePersistentStoresAutomaticallyOption:@YES,
                            NSInferMappingModelAutomaticallyOption:@YES,
                            };
                
                [iCloudEnabledClassMap removeObjectForKey:NSStringFromClass([self class])];
            }

            [persistantStoreCord addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:destUrl options:options error:&error];
             NSAssert(!error, @"persistentStoreCord error %@",error.description);
        }
        
        
        main_task(mainThreadBlock);
    };
    
    background_async(busniessBlock);
    
#if 0
    //首先创建runloop, 保证所有任务都是在同一个线程执行
    if(!sBgNSRunloop) {

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),^{

            sBgNSRunloop = [NSRunLoop currentRunLoop];
            [sBgNSRunloop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
            busniessBlock();
            CFRunLoopRun();
        });
    }
    else {
        //CFRunLoopPerformBlock(sBgRunloop, kCFRunLoopDefaultMode, busniessBlock);
        [sBgNSRunloop performBlock:busniessBlock];
    }
#endif
}

//是否所有操作都只使用mainContext
+(BOOL)useSharedMainContext {
    
    NSNumber * bn = [iCloudEnabledClassMap objectForKey:NSStringFromClass([self class])];
    if(bn)
        return  bn.boolValue;
    else
        return NO;
}

+(nullable NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    NSString *key = NSStringFromClass([self class]);
    return  [sPersistantStoreClassMap objectForKey:key];
}

+(void)invalidatePersistantSotre {
    NSString *key = NSStringFromClass([self class]);
    [sPersistantStoreClassMap removeObjectForKey:key];
    
    //清除之前的共享context
    [sharedMainContextMap removeObjectForKey:NSStringFromClass([self class])];
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

+(NSManagedObjectContext *)sharedMainContext {
    
    NSString *k = NSStringFromClass([self class]);
    NSManagedObjectContext *context = [sharedMainContextMap objectForKey:k];
    if(!context) {
        context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        NSPersistentStoreCoordinator *psc = [self  persistentStoreCoordinator];
        [context setPersistentStoreCoordinator:psc];
        if(!sharedMainContextMap)
            sharedMainContextMap = [NSMutableDictionary dictionaryWithCapacity:3];
        
        [sharedMainContextMap setObject:context forKey:k];
    }
    return context;
}

+(NSManagedObjectContext *)getContext {

    NSManagedObjectContext *ctx = nil;
    if([self useSharedMainContext])
        ctx = [self sharedMainContext];
    else
        ctx = [self newContext];
    return ctx;
}

+(NSManagedObjectContext *)newContext {
    
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [context setPersistentStoreCoordinator:[self  persistentStoreCoordinator]];
    return context;

}

+(void)addDisableModelCacheForEnity:(nonnull NSString *)entityName {
    if(!disabledCacheEntities)
        disabledCacheEntities = [NSMutableSet setWithCapacity:8];
    [disabledCacheEntities addObject:entityName];
    
    NSCache *subMap = [sDataBaseCacheMap objectForKey:entityName];
    [subMap removeAllObjects];
    [sDataBaseCacheMap removeObjectForKey:entityName];
}

+(nullable NSSet *)disabledModelCahceEntities {
    return [disabledCacheEntities copy];
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
#if DEBUG
    NSLog(@"%s:%@",__PRETTY_FUNCTION__,notification);
#endif
}

+(void)storesDidChange:(NSNotification *)notification {
#if DEBUG
    NSLog(@"%s:%@",__PRETTY_FUNCTION__,notification);
#endif
    NSManagedObjectContext *context = [self getContext];
    
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
#if DEBUG
    NSLog(@"%s:%@",__PRETTY_FUNCTION__,changeNotification);
#endif
    NSManagedObjectContext *context = [self getContext];
    
    [context performBlock:^{
        [context mergeChangesFromContextDidSaveNotification:changeNotification];
    }];
}



@end

#import "AsyncCoreData+Configration.h"
