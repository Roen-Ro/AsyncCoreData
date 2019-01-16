//
//  CoreDataBaseManager+Configration.m
//  AsyncCoreData
//
//  Created by 罗亮富 on 2019/1/15.
//

#import "AsyncCoreData+Configration.h"

extern NSMutableDictionary *sDataBaseCacheMap;
extern NSMapTable *sPersistantStoreMap;
//static NSMutableDictionary *sMainContextClassMap;
extern NSMutableDictionary *sBackgroundContextClassMap;

extern NSMutableDictionary *sSettingDBValuesBlockMap;
extern NSMutableDictionary *sGettingDBValuesBlockMap;

extern NSRunLoop *sBgNSRunloop;

@implementation AsyncCoreData (Configration)

+(void)setPersistantStore:(nullable NSURL *)persistantFileUrl withModel:(nonnull NSString *)modelName completion:(void(^)(void))mainThreadBlock {
    
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
        if(!persistantStoreCord) {
            
            NSManagedObjectModel *mobjModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:coreDataModelFileUrl];
            NSError *error = nil;
            persistantStoreCord = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mobjModel];
            
            NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                                     [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
            
            [persistantStoreCord addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:destUrl options:options error:&error];
            
            NSAssert(!error, @"persistentStoreCord error %@",error.description);
            [sPersistantStoreMap setObject:persistantStoreCord forKey:key];
        }
        
        NSString *classIndependentKey = NSStringFromClass([self class]);
        NSManagedObjectContext *bgContext = [sBackgroundContextClassMap objectForKey:classIndependentKey];
        
        if(!bgContext || bgContext.persistentStoreCoordinator != persistantStoreCord) {
            
            bgContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            
            @synchronized(sBackgroundContextClassMap) {
                [sBackgroundContextClassMap setObject:bgContext forKey:classIndependentKey];
            }
            [bgContext setPersistentStoreCoordinator:persistantStoreCord];
        }
        
        if(mainThreadBlock) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                mainThreadBlock();
            });
        }
    };
    
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
}

+(nullable NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    NSString *key = NSStringFromClass([self class]);
    NSManagedObjectContext *ctx = [sBackgroundContextClassMap objectForKey:key];
    return ctx.persistentStoreCoordinator;
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


+(NSManagedObjectContext *)sharedBackgroundContext {
    //    if(!_sharedBackgroundContext)
    //    {
    //        _sharedBackgroundContext = [self inter_classSharedValueFromMap:sBackgroundContextClassMap];
    //    }
    //    return _sharedBackgroundContext;
    //因为在使用类方法切换NSPersistentStoreCoordinator后，所有的对象实例要保持同步更新，所以不用实例变量保存
    return [self inter_classSharedValueFromMap:sBackgroundContextClassMap];
}

+(NSManagedObjectContext *)newContext {
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [context setPersistentStoreCoordinator:[self  persistentStoreCoordinator]];
    return context;
}


@end

#import "AsyncCoreData+Configration.h"
