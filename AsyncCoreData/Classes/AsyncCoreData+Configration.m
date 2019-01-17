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
        NSPersistentStoreCoordinator *psc = [sPersistantStoreClassMap objectForKey:classIndependentKey];
        
        if(!psc || psc != persistantStoreCord) {
            @synchronized(sPersistantStoreClassMap) {
                [sPersistantStoreClassMap setObject:persistantStoreCord forKey:classIndependentKey];
            }
        }
        
        main_task(mainThreadBlock);
    };
    
    background_async(busniessBlock);
}

+(nullable NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    NSString *key = NSStringFromClass([self class]);
    return  [sPersistantStoreClassMap objectForKey:key];
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
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [context setPersistentStoreCoordinator:[self  persistentStoreCoordinator]];
    return context;
}



@end

#import "AsyncCoreData+Configration.h"
