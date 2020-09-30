//
//  AsyncCoreData+Configration.h
//  AsyncCoreData
//
//  Created by 罗亮富 on 2019/1/15.
//

#import "AsyncCoreData.h"

@protocol UniqueValueProtocol;

typedef void(^T_ModelToManagedObjectBlock)(__kindof NSObject<UniqueValueProtocol> * __nonnull  model,  NSManagedObject * _Nonnull managedObject);

typedef __kindof NSObject  * _Nonnull  (^T_ModelFromManagedObjectBlock)(__kindof NSObject<UniqueValueProtocol> * __nullable  model,  NSManagedObject * _Nonnull managedObject);


@interface AsyncCoreData (Configration)

/**
 设置当前类的persistantStore,使用前，必须调用此方法来设置,子类的设置可以独立于父类，子类和父类设置互不影响,如果子类没有单独设置，则使用父类的persistantStore
 
 举个栗子:
 假如MyMessageManager 继承自 AsyncCoreData
 ```objc
 [AsyncCoreData setPersistantStore:url1 withModel:@"mymodel1" completion:^{}];
 [MyMessageManager setPersistantStore:url2 withModel:@"mymodel2" icloudStoreName:@"myIcloudCoreData" completion:^{}];
 ```
 AsyncCoreData 对应为 存储在url1的，对应数据模型为mymodel1的数据库
 MyMessageManager 对应为 存储在url2的，对应数据模型为mymodel2的数据库,其数据会进行icloud同步
 (必须在Xcode中的Capabilities将你的项目打开iCloud功能,必须勾选[iCloud Documents] 并且也在开发中心设置iCloud container; core data icloud 设计参考 https://developer.apple.com/documentation/coredata/synchronizing_a_local_store_to_the_cloud?language=objc
  https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/UsingCoreDataWithiCloudPG/Introduction/Introduction.html )
 如果不设置MyMessageManager的话，那么MyMessageManager默认使用AsyncCoreData的设置
 */
+(void)setPersistantStore:(nullable NSURL *)persistantFileUrl
                withModel:(nonnull NSString *)modelName
               completion:(void(^ _Nonnull )(void))mainThreadBlock;

#warning 注意，如果这里设置了icloudStoreName参数iName的值不为nil，那么所有的 \
+[AsyncCoreData queryEntity:(NSString *)entityName xxx:] 类方法只能在主线程调用 \
+[AsyncCoreData queryEntity:(NSString *)entityName xxxAsync:... completion:^(xxx){ xxx }]; 类异步方法暂时不要使用\

+(void)setPersistantStore:(nullable NSURL *)persistantFileUrl
                withModel:(nonnull NSString *)modelName
          icloudStoreName:(nullable NSString *)iName
               completion:(void(^ _Nonnull )(void))mainThreadBlock;


/**
 数据库写入和读取时候，通过block来设定数据映射规则
 举个栗子:
 有个LAGProjectInfo的数据模型，它的数据将要写到数据库中保存，辣么它的值一定要和数据表有映射关系才能进行读写操作
 1.写入映射
 [AsyncCoreData setModelMapToDataBaseBlock:^(__kindof LAGProjectInfo<UniqueIDProtocol> * _Nonnull model, NSManagedObject * _Nonnull managedObject) {
 [managedObject setValue:model.identifier forKey:@"uniqueID"];
 [managedObject setValue:model.author forKey:@"author_"];
 [managedObject setValue:model.title forKey:@"title_"];
 } forEntity:@"DBProject"];
 
 //读取映射
 [AsyncCoreData setModelFromDataBase:^__kindof NSObject * _Nonnull(__kindof LAGProjectInfo<UniqueIDProtocol> * _Nullable model, NSManagedObject * _Nonnull managedObject) {
 
 if(!model) //注意这里没有对象的话，要负责创建对象
 model = [LAGProjectInfo new];
 model.identifier = [managedObject valueForKey:@"uniqueID"];
 model.author = [managedObject valueForKey:@"author_"];
 model.title = [managedObject valueForKey:@"title_"];
 
 return model;
 
 } forEntity:@"DBProject"];
 
 */
+(void)setModelToDataBaseMapper:(nonnull T_ModelToManagedObjectBlock)mapper forEntity:(nonnull NSString *)entityName;//非线程安全
+(void)setModelFromDataBaseMapper:(nonnull T_ModelFromManagedObjectBlock)mapper forEntity:(nonnull NSString *)entityName; //非线程安全

//如果有些表的数据不需要缓存模型（比如词汇表），通过这方法来设置
+(void)addDisableModelCacheForEnity:(nonnull NSString *)entityName;
+(nullable NSSet *)disabledModelCahceEntities;

+(nullable NSPersistentStoreCoordinator *)persistentStoreCoordinator;
+(void)invalidatePersistantSotre;//一般不会用到，测试的时候用

+(nonnull NSManagedObjectContext *)newContext; //在当前线程创建一个新的context
+(nonnull NSManagedObjectContext *)getContext; //根据当前条件返回合适的context

+(BOOL)useSharedMainContext;

@end


//只是实验性尝试，打开的话会造成所有操作都集中在一个线程，造成任务拥堵，不能很好地利用多线程资源。
#define BG_USE_SAME_RUNLOOP_  0 //@available(macOS 10.2, iOS 10, *)


