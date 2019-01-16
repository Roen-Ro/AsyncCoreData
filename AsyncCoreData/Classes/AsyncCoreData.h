//
//  AsyncCoreData.h
//  ZhuShouCustomize
//
//  Created by 罗亮富 on 2019/1/9.
//  Copyright © 2019年 罗亮富. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "UniqueValueProtocol.h"


#ifndef lazy
#define lazy readonly
#endif

#define QUERY_ENTITY(entityName) AsyncCoreData queryEntity:entityName \


@class AsyncCoreData;


@interface AsyncCoreData : NSObject


#pragma mark- insert/update

/**
 写入数据库（插入/更新）

 插入更新规则：
 1.数据模型uniqueValue(UniqueValueProtocol协议规范)值不为nil，则判断数据表中对应的uniqueValue值是否存在，若存在则更新，不存在则插入
 2.数据模型uniqueValue若为nil，则：
    a> 若数据模型本身是从数据库中读取的，则写入的时候将覆盖原来读取时候对应的那条数据
    b> 若数据模型不是来源于数据库中，则将数据插入到数据表中
 */
+(NSError *)queryEntity:(nonnull NSString *)entityName
             saveModels:(nonnull NSArray<id<UniqueValueProtocol>> *)datas;

+(void)queryEntity:(nonnull NSString *)entityName
   saveModelsAsync:(NSArray<id<UniqueValueProtocol>> *)datas
        completion:(void (^)(NSError *))block;

#pragma mark- delete

/**
 删除记录
 
 删除规则：
 1.数据模型uniqueValue(UniqueValueProtocol协议规范)值不为nil，则判断数据表中对应的uniqueValue值是否存在，若存在则删除，否则忽略
 2.数据模型uniqueValue若为nil，则：
    a> 若数据模型本身是从数据库中读取的，则删除数据模型对应的数据库记录
    b> 若数据模型不是来源于数据库中，则忽略
 */
+(NSError *)queryEntity:(nonnull NSString *)entityName
           deleteModels:(nonnull NSArray<id<UniqueValueProtocol>> *)models;

+(void)queryEntity:(nonnull NSString *)entityName
 deleteModelsAsync:(nonnull NSArray<id<UniqueValueProtocol>> *)models
        completion:(void (^)(NSError *))block;


//根据数据模型uniqueValue值删除数据库中对应记录
+(NSError *)queryEntity:(nonnull NSString *)entityName
    deleteModelsWithUniquevalues:(nonnull NSArray *)modelUniquevalues;

+(void)queryEntity:(nonnull NSString *)entityName
       deleteModelsWithUniquevaluesAsync:(nonnull NSArray *)modelUniquevalues
                                completion:(void (^)(NSError *))block;


//按设定条件删除记录
+(NSError *)queryEntity:(nonnull NSString *)entityName
    deleteModelsWithPredicate:(nullable NSPredicate *)predicate;

+(void)queryEntity:(nonnull NSString *)entityName
    deleteModelsWithPredicateAsync:(nullable NSPredicate *)predicate
                        completion:(void (^)(NSError *))block;



#pragma mark- filt out

/**
 按照条件查询数据库

 @param entityName 数据表
 @param predicate 查询条件
 @param range 读取数据范围（就像是分页一样）
 @param sortKey 排序的字段，注意这个字段是数据库表的字段，而非数据模型的字段
 @param reverse 是否按照插入顺序反序输出， YES先插入的在后面，NO后插入的在前面
 @return 返回查询到的“数据模型”数组
 */
+(NSArray *)queryEntity:(nonnull NSString *)entityName
    modelsWithPredicate:(nullable NSPredicate *)predicate
                inRange:(NSRange)range
              sortByKey:(NSString *)sortKey
                reverse:(BOOL)reverse;

+(void)queryEntity:(nonnull NSString *)entityName
modelsWithPredicateAsync:(nullable NSPredicate *)predicate
           inRange:(NSRange)range
         sortByKey:(NSString *)sortKey
           reverse:(BOOL)reverse
        completion:(void (^)(NSArray *))block;



#pragma mark- statitic/count

+(NSUInteger)queryEntity:(nonnull NSString *)entityName
    numberOfItemsWithPredicate:(nullable NSPredicate *)predicate;

+(void)queryEntity:(nonnull NSString *)entityName
    numberOfItemsWithPredicateAsync:(nullable NSPredicate *)predicate
                         completion:(void(^)(NSUInteger ))block;



#pragma mark- statitic/massive

//function could be @"max:" @"min:" @"count"() @"sum:"
+(NSNumber *)queryEntity:(NSString *)entityName
        valueWithFuction:(NSString *)func
                  forKey:(NSString *)key
           withPredicate:(NSPredicate *)predicate;

+(void)queryEntity:(NSString *)entityName
    valueWithFuctionAsync:(NSString *)func
            forKey:(NSString *)key
     withPredicate:(NSPredicate *)predicate
        completion:(void(^)(NSNumber * ))block;


+(NSArray<NSDictionary *> *)queryEntity:(NSString *)entityName
                  sumValuesForKeyPathes:(NSArray *)keyPathes
                                groupby:(NSArray <NSString *>*)groups
                          withPredicate:(NSPredicate *)predicate
                            sortKeyPath:(NSString *)sortKeyPath
                                inRange:(NSRange)range;

+(void)queryEntity:(NSString *)entityName
    sumValuesForKeyPathes:(NSArray *)keyPathes
                  groupby:(NSArray <NSString *>*)groups
            withPredicate:(NSPredicate *)predicate
              sortKeyPath:(NSString *)sortKeyPath
                  inRange:(NSRange)range
               completion:(void (^)(NSArray<NSDictionary *> *))block;


#pragma mark- for subclasses
+(nullable NSManagedObject *)queryEntity:(NSString *)entityName
                 existingDBModelForModel:(__kindof NSObject<UniqueValueProtocol> *)model
                               inContext:(nonnull NSManagedObjectContext *)context;


+(nullable NSArray<NSManagedObject *> *)queryEntity:(nonnull NSString *)entityName
                     dbModelsWithPredicate:(NSPredicate *)predicate
                                   inRange:(NSRange)range
                                 sortByKey:(nullable NSString *)sortKey
                                   reverse:(BOOL)reverse
                                 inContext:(nonnull NSManagedObjectContext *)context;


+(nullable NSArray<NSManagedObject *> *)dbModelsWithFetchRequest:(nullable NSFetchRequest *)frqs
                                                inRange:(NSRange)range
                                              sortByKey:(nullable NSString *)sortKey
                                                reverse:(BOOL)reverse
                                              inContext:(nonnull NSManagedObjectContext *)context;


//将数据库同步到磁盘 for subclass
+(nullable NSError *)synchronizeinContext:(nonnull NSManagedObjectContext *)context;

@end


#import "AsyncCoreData+Configration.h"
