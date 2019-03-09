//
//  AsyncCoreData.m
//  ZhuShouCustomize
//
//  Created by 罗亮富 on 2019/1/9.
//  Copyright © 2019年 罗亮富. All rights reserved.
//

#import "AsyncCoreData.h"
#import <objc/runtime.h>



@implementation NSObject (AsyncCoreData)

-(void)setStoreID:(NSManagedObjectID *)storeID {
    objc_setAssociatedObject(self, @selector(storeID), storeID, OBJC_ASSOCIATION_RETAIN);
}

-(NSManagedObjectID *)storeID {
    return objc_getAssociatedObject(self, @selector(storeID));
}

-(nullable NSURL *)StoreUrl {
    return self.storeID.URIRepresentation;
}

@end

 NSMutableDictionary *sDataBaseCacheMap;
 NSMapTable *sPersistantStoreMap;
 NSMutableDictionary *sPersistantStoreClassMap;


 NSMutableDictionary *sSettingDBValuesBlockMap;
 NSMutableDictionary *sGettingDBValuesBlockMap;

NSRunLoop *sBgNSRunloop;

static NSRecursiveLock *sCacheLock;
#define _add_cache_lock() [sCacheLock tryLock]
#define _remove_cache_lock() [sCacheLock unlock]

static NSRecursiveLock *sWriteLock;
#define _add_write_lock() [sWriteLock tryLock]
#define _remove_write_lock() [sWriteLock unlock]

@implementation AsyncCoreData


#pragma mark- config

+(void)initialize
{
    if (sDataBaseCacheMap == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sDataBaseCacheMap = [NSMutableDictionary dictionaryWithCapacity:10];
            sPersistantStoreMap = [NSMapTable strongToWeakObjectsMapTable];
            sPersistantStoreClassMap = [NSMutableDictionary dictionaryWithCapacity:3];
            sSettingDBValuesBlockMap = [NSMutableDictionary dictionaryWithCapacity:3];
            sGettingDBValuesBlockMap = [NSMutableDictionary dictionaryWithCapacity:3];
            
            sCacheLock = [NSRecursiveLock new];
            sWriteLock = [NSRecursiveLock new];
            
        });
    }
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(clearUnNessesaryCachedData)
                                                name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
}



#pragma mark- chache
//注意dbObj参数必须是已经保存到数据库中的数据 即dbObj的objectID.isTemporaryID = NO
+(void)cacheModel:(NSObject *)obj forEntity:(NSString *)entityName
{
    if(!obj)
        return;
    
    _add_cache_lock();
    
    NSString *rootKey = entityName;
    NSMutableDictionary *subMap = [sDataBaseCacheMap objectForKey:rootKey];
    if(!subMap)
    {
        subMap = [NSMutableDictionary dictionaryWithCapacity:200];
        [sDataBaseCacheMap setObject:subMap forKey:rootKey];
    }
    
    if(obj && obj.storeID)
        [subMap setObject:obj forKey:obj.storeID.URIRepresentation];
    
    _remove_cache_lock();
}


+(id)cachedModelForDBModel:(nonnull NSManagedObject *)dbModel forEntity:(NSString *)entityName
{
   NSString *rootKey = entityName;
    
    _add_cache_lock();
    
    NSMutableDictionary *subMap = [sDataBaseCacheMap objectForKey:rootKey];
    if (subMap)
        return [subMap objectForKey:dbModel.objectID.URIRepresentation];
    else
        return nil;
    
    _remove_cache_lock();
}

+(void)removeCachedModelForDBModel:(nonnull NSManagedObject *)dbModel forEntity:(NSString *)entityName
{
    NSString *rootKey = entityName;
    _add_cache_lock();
    NSMutableDictionary *subMap = [sDataBaseCacheMap objectForKey:rootKey];
    if (subMap)
        return [subMap removeObjectForKey:dbModel.objectID.URIRepresentation];
    _remove_cache_lock();
}


+(void)clearUnNessesaryCachedData
{
    _add_cache_lock();

    [sDataBaseCacheMap enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        
        NSMutableDictionary *subMap = (NSMutableDictionary *)obj;
        
        NSMutableArray *mKeysToRemove = [NSMutableArray arrayWithCapacity:subMap.count];
        
        [subMap enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {

            CFIndex retainCount = CFGetRetainCount((__bridge CFTypeRef)obj);
            if(retainCount <= 2) //因为除了dictionary持有obj外，block的形参也持有了obj，所以小于等于2即表示没有其他地方持有了obj
            {
                [mKeysToRemove addObject:key];
            }
        }];
        
        [subMap removeObjectsForKeys:mKeysToRemove];
    }];

    _remove_cache_lock();
}

#pragma mark-


+(void)inter_doBackgroundTask:(void (^)(void))task {
    
    if (BG_USE_SAME_RUNLOOP_)
        [sBgNSRunloop performBlock:task];
    else
        background_async(task);
}

#pragma mark- insert/update



+(nullable id)modelForStoreUrl:(nonnull NSURL *)storeUrl
{
    if(!storeUrl)
        return nil;
    
    NSManagedObjectID *obID = [[self persistentStoreCoordinator] managedObjectIDForURIRepresentation:storeUrl];
    
    return [self modelForStoreID:obID];
}

+(nullable id)modelForStoreID:(nonnull NSManagedObjectID *)storeID {
    
    NSManagedObject *managedObj = [self DBModelForStoreID:storeID];
    if(managedObj)
        return [self queryEntity:managedObj.entity.name modelFromDBModel:managedObj];

    return nil;
}

+(nullable NSManagedObject *)DBModelForStoreID:(nonnull NSManagedObjectID *)storeID {
    
    if(!storeID)
        return nil;
    
    NSError *error;
    NSManagedObject *managedObj = [[self newContext] existingObjectWithID:storeID error:&error];
    
    return managedObj;
}

+(NSError *)queryEntity:(NSString *)entityName saveModels:(nonnull NSArray<id<UniqueValueProtocol>> *)datas {
    return [self queryEntity:entityName saveModels:datas inContext:[self newContext]];
}


+(void)queryEntity:(NSString *)entityName saveModelsAsync:(NSArray<id<UniqueValueProtocol>> *)datas completion:(void (^)(NSError *))block {
    
   [self inter_doBackgroundTask:^{
       
        NSError *e = [self queryEntity:entityName saveModels:datas inContext:[self newContext]];
        main_task(^{
            if(block)
                block(e);
        });
    }];
    
}

+(NSError *)queryEntity:(NSString *)entityName
             saveModels:(nonnull NSArray<id<UniqueValueProtocol>> *)datas
            inContext:(NSManagedObjectContext *)context
{
    NSArray *dCopy = [NSArray arrayWithArray:datas];
    NSMutableArray *modelArray_, *dbArray_;
    NSError *retError;
    _add_write_lock();
        
    for(NSObject<UniqueValueProtocol> *m in dCopy) {
        
        NSManagedObject *DBm = [self queryEntity:entityName DBModelForModel:m createIfNotExist:YES inContext:context];
        if(DBm) {
            
            T_ModelToManagedObjectBlock blk = [sSettingDBValuesBlockMap objectForKey:entityName];
            NSAssert(blk, @"model mapper block haven't set for entity %@, Use +[AsyncCoreData setModelToDataBaseMapper:forEntity:] method to setup",entityName);
            blk(m, DBm);

            //   [self cacheObject:m forManagedObject:DBm]; //cacke比较复杂 如果是更新操作的话，之前的步骤会保证cacke，如果是插入操作的话，到后面再cacke
            
            if(!DBm.objectID.isTemporaryID) {
                m.storeID = DBm.objectID;
            }
            else {
                if(!modelArray_) {
                    modelArray_ = [NSMutableArray arrayWithCapacity:datas.count];
                    dbArray_ = [NSMutableArray arrayWithCapacity:datas.count];
                }
                
                [modelArray_ addObject:m];
                [dbArray_ addObject:DBm];
            }
        }
    }
    
    [context save:&retError];
    
    if(modelArray_.count > 0) {
        NSInteger i = 0;
        for(;i<modelArray_.count;i++) {
            
            NSManagedObject *DBm1 = [dbArray_ objectAtIndex:i];
            NSObject *m1 = [modelArray_ objectAtIndex:i];
            m1.storeID = DBm1.objectID;
            //对新插入的元素进行cacke
            [self cacheModel:m1 forEntity:entityName];
        }
    }
    _remove_write_lock();
    
    return retError;
}

#pragma mark- delete
+(NSError *)queryEntity:(NSString *)entityName deleteModels:(nonnull NSArray<id<UniqueValueProtocol>> *)models {
    return [self queryEntity:entityName deleteModels:models inContext:[self newContext]];
}


+(void)queryEntity:(NSString *)entityName deleteModelsAsync:(nonnull NSArray<id<UniqueValueProtocol>> *)models completion:(void (^)(NSError *))block {

    [self inter_doBackgroundTask:^{
        NSError *e = [self queryEntity:entityName deleteModels:models inContext:[self newContext]];
        main_task(^{
            if(block)
                block(e);
        });
    }];
}


+(NSError *)queryEntity:(NSString *)entityName deleteModels:(nonnull NSArray<id<UniqueValueProtocol>> *)models inContext:(NSManagedObjectContext *)context {
    
    NSArray *dCopy = [NSArray arrayWithArray:models];
    NSError *retError;
    _add_write_lock();
    for(NSObject<UniqueValueProtocol> *m in dCopy) {
        
        NSManagedObject *dbm = [self queryEntity:entityName existingDBModelForModel:m inContext:context];
        if(dbm) {
            [self removeCachedModelForDBModel:dbm forEntity:entityName];
            [context deleteObject:dbm];
        }
    }
    [context save:&retError];
    _remove_write_lock();
    
    return retError;
}

+(NSError *)queryEntity:(NSString *)entityName deleteModelsWithUniquevalues:(nonnull NSArray *)modelUniquevalues {
    return [self queryEntity:entityName deleteModelsWithUniquevalues:modelUniquevalues inContext:[self newContext]];
}

+(void)queryEntity:(NSString *)entityName deleteModelsWithUniquevaluesAsync:(nonnull NSArray *)modelUniquevalues completion:(void (^)(NSError *))block {
    [self inter_doBackgroundTask:^{
        NSError *e = [self queryEntity:entityName deleteModelsWithUniquevalues:modelUniquevalues inContext:[self newContext]];
        main_task(^{
            if(block)
                block(e);
        });
    }];
}

+(NSError *)queryEntity:(NSString *)entityName deleteModelsWithUniquevalues:(nonnull NSArray *)modelUniquevalues inContext:(NSManagedObjectContext *)context {
    
    _add_write_lock();
    NSError *e;
    for(id v in modelUniquevalues) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uniqueID = %@",v];
        NSArray<NSManagedObject *> *a = [self queryEntity:entityName dbModelsWithPredicate:predicate inRange:NSMakeRange(0, NSUIntegerMax) sortByKey:nil reverse:YES inContext:context]; //YES效率会比较高
        for(NSManagedObject *mobj in a) {
            [context deleteObject:mobj];
        }
    }
    
    [context save:&e];
    _remove_write_lock();
    return e;
}

+(NSError *)queryEntity:(NSString *)entityName deleteModelsWithPredicate:(nullable NSPredicate *)predicate {
    return [self queryEntity:entityName deleteModelsWithPredicate:predicate inContext:[self newContext]];
}

+(void)queryEntity:(NSString *)entityName deleteModelsWithPredicateAsync:(nullable NSPredicate *)predicate
                                completion:(void (^)(NSError *))block {
    [self inter_doBackgroundTask:^{
        NSError *e = [self queryEntity:entityName deleteModelsWithPredicate:predicate inContext:[self newContext]];
        
        main_task(^{
            if(block)
                block(e);
        });
    }];
}

+(NSError *)queryEntity:(NSString *)entityName deleteModelsWithPredicate:(nullable NSPredicate *)predicate inContext:(NSManagedObjectContext *)context {
    
    _add_write_lock();
    NSError *e;
    NSArray<NSManagedObject *> *a = [self queryEntity:entityName dbModelsWithPredicate:predicate inRange:NSMakeRange(0, NSUIntegerMax) sortByKey:nil reverse:YES inContext:context]; //YES效率会比较高
    for(NSManagedObject *mobj in a) {
        [context deleteObject:mobj];
    }
    
    [context save:&e];
    _remove_write_lock();
    return e;
}

#pragma mark- find out

+(__kindof NSObject *)queryEntity:(NSString *)entityName modelFromDBModel:(NSManagedObject *)DBModel
{
    NSObject *m = [self cachedModelForDBModel:DBModel forEntity:entityName];
    if(!m) {
        T_ModelFromManagedObjectBlock blk = [sGettingDBValuesBlockMap objectForKey:entityName];
        NSAssert(blk, @"model mapper block haven't set for entity %@, Use +[AsyncCoreData setModelFromDataBaseMapper:forEntity] method to setup",entityName);
        m = blk(nil, DBModel);
        m.storeID = DBModel.objectID;
        [self cacheModel:DBModel forEntity:entityName];
    }
    return m;
}


+(nullable NSManagedObject *)queryEntity:(NSString *)entityName existingDBModelForModel:(__kindof NSObject<UniqueValueProtocol> *)model {
    return [self queryEntity:entityName existingDBModelForModel:model inContext:[self newContext]];
}


+(nullable NSManagedObject *)queryEntity:(NSString *)entityName existingDBModelForModel:(__kindof NSObject<UniqueValueProtocol> *)model inContext:(NSManagedObjectContext *)context {
    
    NSManagedObject *retObj = nil;
    NSPredicate *predicate = nil;
    if(model.uniqueValue)
        predicate = [NSPredicate predicateWithFormat:@"uniqueID = %@",model.uniqueValue];
    
    if(predicate) {
        NSArray *results = [self queryEntity:entityName dbModelsWithPredicate:predicate inRange:NSMakeRange(0, NSIntegerMax) sortByKey:nil reverse:YES inContext:context];
        retObj = [self inter_filtOutOnlyEntityInResultList:results inContext:context];
    }
    else if(model.storeID)
        retObj = [context existingObjectWithID:model.storeID error:nil];
    
    if(retObj)
        [self cacheModel:model forEntity:entityName];
    
    return retObj;
}

+(NSManagedObject *)queryEntity:(NSString *)entityName DBModelForModel:(__kindof NSObject<UniqueValueProtocol> *)model createIfNotExist:(BOOL)create inContext:(NSManagedObjectContext *)context {
    
    NSManagedObject *retObj = [self  queryEntity:entityName existingDBModelForModel:model inContext:context];
    
    if(!retObj && create)
        retObj = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:context];
    
    return retObj;
}

#pragma mark-
+(NSManagedObject *)inter_filtOutOnlyEntityInResultList:(NSArray *)resultList inContext:(NSManagedObjectContext *)context
{
    if(resultList.count==0)
        return nil;
    
    if(resultList.count>2)
    {
        for(int i=1; i<resultList.count;i++)
        {
            NSManagedObject *obj = [resultList objectAtIndex:i];
            [context deleteObject:obj];
        }
    }
    return [resultList firstObject];
}


+(NSArray *)queryEntity:(NSString *)entityName modelsWithPredicate:(nullable NSPredicate *)predicate
                        inRange:(NSRange)range
                      sortByKey:(NSString *)sortKey
                        reverse:(BOOL)reverse {
    return [self queryEntity:entityName modelsWithPredicate:predicate inRange:range sortByKey:sortKey reverse:reverse inContext:[self newContext]];
}

+(void)queryEntity:(NSString *)entityName modelsWithPredicateAsync:(nullable NSPredicate *)predicate
                        inRange:(NSRange)range
                      sortByKey:(NSString *)sortKey
                        reverse:(BOOL)reverse
                     completion:(void (^)(NSArray *))block {
    
    [self inter_doBackgroundTask: ^{
        NSArray *r = [self queryEntity:entityName modelsWithPredicate:predicate inRange:range sortByKey:sortKey reverse:reverse inContext:[self newContext]];
        
        main_task(^{
            if(block)
                block(r);
        });
    }];
}


+(NSArray *)queryEntity:(NSString *)entityName
    modelsWithPredicate:(NSPredicate *)predicate
                              inRange:(NSRange)range
                            sortByKey:(NSString *)sortKey
                              reverse:(BOOL)reverse
                            inContext:(NSManagedObjectContext *)context {

    NSArray *dbDatas = [self queryEntity:entityName dbModelsWithPredicate:predicate inRange:range sortByKey:sortKey reverse:reverse inContext:context];
    
    NSMutableArray *datas = [NSMutableArray arrayWithCapacity:dbDatas.count];
    for(NSManagedObject *dbm in dbDatas) {
        
        NSObject *m = [self queryEntity:entityName modelFromDBModel:dbm];
        [datas addObject:m];
    }
    
    return datas;
}

+(NSArray<NSManagedObject *> *)queryEntity:(NSString *)entityName
                  dbModelsWithPredicate:(NSPredicate *)predicate
                                             inRange:(NSRange)range
                                           sortByKey:(nullable NSString *)sortKey
                                             reverse:(BOOL)reverse
                                           inContext:(NSManagedObjectContext *)context
{
    NSFetchRequest * frqs = [NSFetchRequest fetchRequestWithEntityName:entityName];
    frqs.predicate = predicate;
    return [self  dbModelsWithFetchRequest:frqs inRange:range sortByKey:sortKey reverse:reverse inContext:context];
}


+(NSArray<NSManagedObject *> *)dbModelsWithFetchRequest:(NSFetchRequest *)frqs
                                                inRange:(NSRange)range
                                              sortByKey:(NSString *)sortKey
                                                reverse:(BOOL)reverse
                                              inContext:(NSManagedObjectContext *)context
{
    frqs.fetchOffset = 0;
    frqs.fetchLimit = NSUIntegerMax;
    
    if(sortKey)
    {
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:sortKey ascending:!reverse];
        if(frqs.sortDescriptors)
        {
            NSArray *sortDescriptors = frqs.sortDescriptors;
            NSMutableArray *mArray = [NSMutableArray arrayWithArray:sortDescriptors];
            [mArray addObject:sortDescriptor];
            frqs.sortDescriptors = [NSArray arrayWithArray:mArray];
        }
        else
        {
            frqs.sortDescriptors = @[sortDescriptor];
        }
    }
    
    if(reverse)
    {
        NSError *error;
        
        NSUInteger count;
        
        NSFetchRequest *countFetchRequest;
        if(frqs.resultType == NSCountResultType)
        {
            countFetchRequest = frqs;
        }
        else
        {
            countFetchRequest = [NSFetchRequest fetchRequestWithEntityName:frqs.entityName];
            countFetchRequest.predicate = frqs.predicate;
        }
        
        count = [context countForFetchRequest:countFetchRequest error:&error];
        
        NSInteger loc = count-range.location-range.length;
        NSInteger len = range.length;
        if(loc<0)
        {
            if((loc+len)<0)
                len = 0;
            else
                len = range.length+loc;
            
            loc = 0;
        }
        range = NSMakeRange(loc, len);
    }
    
    if(range.length == 0)
        return nil;
    
    
    frqs.fetchOffset = range.location;
    frqs.fetchLimit = range.length;
    
    NSArray *results = [context executeFetchRequest:frqs error:nil];
    
    if(!sortKey && reverse)
    {
        
#if 0
        //        NSEnumerator *em = [results reverseObjectEnumerator];
        //#warning crash 发现 allObjects 中出现过闪退，而且次数还不少，但做压力测试又无法复现
        //        results = [em allObjects];
        // 有时候发现用NSEnumerator在执行allObjects方法时会闪退，所以这里采用用遍历方式反转数组
        //add by wei.feng 2018.05.18 这样修改之后还是会闪退 results后面加一个copy再看看效果
        //加了copy之后依然会发生闪退，跟外面调用有关，只在TrackDataManager获取轨迹列表和ListDataForTableManager获取活动信息的时候发生过，其他的时候都没有发生
        results = [self reverseArray:[results copy]];
#else
        NSEnumerator *em;
        BOOL catchedReverseException = NO;
        @try {
            em = [results reverseObjectEnumerator];
        } @catch (NSException *exception) {
            catchedReverseException = YES;
        } @finally {
            if(!catchedReverseException)
                results = [em allObjects];
        }
#endif
    }
    
    return results;
}

#pragma mark- statitic/count

+(NSUInteger)queryEntity:(NSString *)entityName numberOfItemsWithPredicate:(nullable NSPredicate *)predicate {
    return [self  queryEntity:entityName numberOfItemsWithPredicate:predicate inContext:[self newContext]];
}

+(void)queryEntity:(NSString *)entityName numberOfItemsWithPredicateAsync:(nullable NSPredicate *)predicate completion:(void(^)(NSUInteger ))block {
    [self inter_doBackgroundTask:^{
        NSUInteger c = [self queryEntity:entityName numberOfItemsWithPredicate:predicate inContext:[self newContext]];
        
        main_task(^{
            if(block)
                block(c);
        });
    }];
}

+(NSUInteger)queryEntity:(NSString *)entityName
numberOfItemsWithPredicate:(nullable NSPredicate *)predicate
               inContext:(NSManagedObjectContext *)context {
    
    NSFetchRequest * frqs = [NSFetchRequest fetchRequestWithEntityName:entityName];
    frqs.predicate = predicate;
    NSUInteger c = [context countForFetchRequest:frqs error:nil];
    return c;
}

#pragma mark- statitic/massive


+(NSExpressionDescription *)expressionDescriptionOfFuction:(NSString *)func forKeyPath:(NSString *)keyPath
{
    NSExpression *keyPathExpression = [NSExpression expressionForKeyPath:keyPath];
    NSExpression *calExpression = [NSExpression expressionForFunction:func arguments:@[keyPathExpression]];
    
    NSExpressionDescription * finalExpressionDescription = [[NSExpressionDescription alloc] init];
    [finalExpressionDescription setExpression:calExpression];
    [finalExpressionDescription setExpressionResultType:NSInteger64AttributeType];
    if([func isEqualToString:@"count:"])
        [finalExpressionDescription setName:@"count"];
    else
        [finalExpressionDescription setName:keyPath];
    
    return finalExpressionDescription;
}

+(NSNumber *)queryEntity:(NSString *)entityName valueWithFuction:(NSString *)func forKey:(NSString *)key withPredicate:(NSPredicate *)predicate {
    return [self queryEntity:entityName valueWithFuction:func forKey:key withPredicate:predicate inContext:[self newContext]];
}

+(void)queryEntity:(NSString *)entityName valueWithFuctionAsync:(NSString *)func forKey:(NSString *)key withPredicate:(NSPredicate *)predicate completion:(void(^)(NSNumber * ))block {
    
    [self inter_doBackgroundTask: ^{
        NSNumber *n = [self queryEntity:entityName valueWithFuction:func forKey:key withPredicate:predicate inContext:[self newContext]];
        main_task(^{
            if(block)
                block(n);
        });
    }];
}

+(NSNumber *)queryEntity:(NSString *)entityName valueWithFuction:(NSString *)func forKey:(NSString *)key withPredicate:(NSPredicate *)predicate inContext:(NSManagedObjectContext *)context
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityName];
    if(predicate)
        fetchRequest.predicate = predicate;
    
    NSArray *propertiesToFetch = @[[self expressionDescriptionOfFuction:func forKeyPath:key]];
    [self set_UpFetch:fetchRequest forProperties:propertiesToFetch sortByKeyPath:nil reverse:NO];
    
    
    NSError *error;
    NSArray *results = [context executeFetchRequest:fetchRequest error:&error];
    if(!error && results.count>0)
    {
        NSDictionary *rDic = [results firstObject];
        id val = [rDic objectForKey:@"requestValue"];
        return val;
    }
    return nil;
}


+(NSArray<NSDictionary *> *)queryEntity:(NSString *)entityName
                  sumValuesForKeyPathes:(NSArray *)keyPathes
                                          groupby:(NSArray <NSString *>*)groups
                                    withPredicate:(NSPredicate *)predicate
                                      sortKeyPath:(NSString *)sortKeyPath
                                          inRange:(NSRange)range {
    return [self queryEntity:entityName sumValuesForKeyPathes:keyPathes groupby:groups withPredicate:predicate sortKeyPath:sortKeyPath inRange:range inContext:[self newContext]];
}

+(void)queryEntity:(NSString *)entityName
sumValuesForKeyPathes:(NSArray *)keyPathes
           groupby:(NSArray <NSString *>*)groups
     withPredicate:(NSPredicate *)predicate
       sortKeyPath:(NSString *)sortKeyPath
           inRange:(NSRange)range
        completion:(void (^)(NSArray<NSDictionary *> *))block {
    [self inter_doBackgroundTask:^{
        NSArray *r = [self queryEntity:entityName sumValuesForKeyPathes:keyPathes groupby:groups withPredicate:predicate sortKeyPath:sortKeyPath inRange:range inContext:[self newContext]];
        main_task(^{
            if(block)
                block(r);
        });
    }];
}

+(NSArray<NSDictionary *> *)queryEntity:(NSString *)entityName
                  sumValuesForKeyPathes:(NSArray *)keyPathes
                                         groupby:(NSArray <NSString *>*)groups
                                   withPredicate:(NSPredicate *)predicate
                                         sortKeyPath:(NSString *)sortKeyPath
                                          inRange:(NSRange)range
                                        inContext:(NSManagedObjectContext *)context
{
    NSArray *groupBys = groups;
    
    NSMutableArray *propertiesToFetch = [NSMutableArray arrayWithArray:groupBys];
    for(NSString *keyPath in keyPathes)
    {
        [propertiesToFetch addObject:[self expressionDescriptionOfFuction:@"sum:" forKeyPath:keyPath]];
    }
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityName];
    fetchRequest.predicate = predicate;
    [self set_UpFetch:fetchRequest forProperties:propertiesToFetch sortByKeyPath:sortKeyPath reverse:NO];
    
    [fetchRequest setPropertiesToGroupBy:groupBys];
    fetchRequest.fetchOffset = range.location;
    fetchRequest.fetchLimit = range.length;
    
    NSError *error;
    NSArray *results = [context executeFetchRequest:fetchRequest error:&error];
    
    return results;
}


+(void)set_UpFetch:(NSFetchRequest *)fetchRequest forProperties:(NSArray *)propertiesToFetch sortByKeyPath:(NSString *)sortKeyPath reverse:(BOOL)reverse
{
    [fetchRequest setReturnsDistinctResults:YES];
    [fetchRequest setPropertiesToFetch:propertiesToFetch];
    [fetchRequest setResultType:NSDictionaryResultType];
    [fetchRequest setFetchBatchSize:20];
    
    if(sortKeyPath)
    {
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:sortKeyPath ascending:!reverse];
        fetchRequest.sortDescriptors = @[sortDescriptor];
    }
}


#pragma mark-
+(NSError *)synchronizeinContext:(NSManagedObjectContext *)context
{
    NSError *e;
    [context save:&e];
    return e;
}


@end
