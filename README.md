# AsyncCoreData

- 对CoreData数据库支持同步/异步操作
- 自带内存缓存，保证同一数据在内存中的唯一性
- 线程安全
- 灵活的接口封装


## 使用

假设有个类`PlaceModel` ，要将他存到数据库中

```objc
//PlaceModel.h
@interface PlaceModel : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *country;
@property (nonatomic, strong) NSString *zipCode;
@property (nonatomic) int level;
@end
```

### 配置
 1  **数据模型实现`UniqueValueProtocol`的协议方法**
```objc
//PlaceModel.m
-(id)uniqueValue {
    return self.zipCode; 
}
```
这个协议的目的是约束对象的‘唯一’值，有点类似mysql的唯一索引，比如是用户信息的话，一般以`user_id`来代表用户的唯一性，那么就返回`user_id`(`return @self.user_id`),如果有些对象不具备唯一性，那么就直接返回`nil`,比如消息，就不具备唯一性，那就返回`nil`。

2 **在Xcode中创建数据库模型文件**    

- 通过Xcode创建一个名为“RRCDModel.xcdatamodeled”的数据库模型文件 
- 创建一个名词为PlaceEntity的Entity，设定相应字段（假设设定字段为 `"uniqueID","name","country","level"`）

<font color=Purple>*注意*
- *每一个Entity必须要有一个String类型的 `uniqueID` 字段，这个字段就好比是mysql数据库中的唯一索引，不同的是这个字段可以为`nil`*  
- *在CoreData数据库中，`uniqueID` 字段值将“自动”设定为模型中的`uniqueValue`值（即为何要遵循`UniqueValueProtocol`协议方法规范)*  
- *在进行数据写入的时候，`AsyncCoreData` 将会自动检查数据模型的`uniqueValue`值（在不为`nil`的情况下）对应的记录在数据库中是否存在，若存在则更新该记录，否则则插入一条新记录*
</font>  


3 **配置数据库存储位置及数据模型来源文件**  

<font color=Purple>*数据库配置的方法全部定义在`AsyncCoreData+Configration.h`文件中*</font>
```objc
//这个是你数据库文件在本地的存储地址，可以灵活变换
NSURL *dataStoreUlr = [myDataDirectory URLByAppendingPathComponent:@"PrivateDataBase.sqlite"];

//@“RRCDModel”为你在Xcode中创建的数据库模型文件名称，后缀.xcdatamodeld忽略
[AsyncCoreData setPersistantStore:dataStoreUlr withModel:@"RRCDModel" completion:^{
    NSLog(@"Core Data finished setup store");
}];
```
有两个牛逼的地方需要注意：
- `+[AsyncCoreData setPersistantStore: withModel:completion]` 这个类方法的调用时机是不受限制的，可以通过这个方法来切换数据库，例如在户外助手中，每个登录用户都有自己独立的数据库文件，这个时候，在切换了登录用的时候，就需要通过它来切换数据库。
- `AsyncCoreData`可以子类化，子类和父类可以分别独立设置不同的数据库，例如在户外助手中，有些数据是随App的，比如轨迹、运动这些东西，那么就保存在App共用数据库中，这个时候可以可以创建一个`AppPublicCoreData`的子类，对这个子类单独配置

举个栗子：
```objc
//定义一个子类继承自 AsyncCoreData
@interface AppPublicCoreData : AsyncCoreData
@end
```

```objc
//公共数据库存储地址
NSURL *url = [publicDataDirectory URLByAppendingPathComponent:@"AppDataBase.sqlite"];

//@“RRCDModel”为你在Xcode中创建的数据库模型文件名称，后缀.xcdatamodeld忽略
[AppPublicCoreData setPersistantStore:url withModel:@"PublicDataModel" completion:^{
    NSLog(@"Core Data finished setup store");
}];
```

4 **设定数据库读写映射方法**
```objc
//模型数据写入数据库配置方法
[AsyncCoreData setModelToDataBaseMapper:^(PlaceModel * model, NSManagedObject * _Nonnull managedObject) {
    [managedObject setValue:model.zipCode forKey:@"uniqueID"];
    [managedObject setValue:model.name forKey:@"name"];
    [managedObject setValue:model.country forKey:@"country"];
    [managedObject setValue:@(model.level) forKey:@"level"];

} forEntity:@"PlaceEntity"];

//从数据库数据获取数据模型方法
[AsyncCoreData setModelFromDataBaseMapper:^__kindof NSObject * _Nonnull(PlaceModel * _Nullable model, NSManagedObject * _Nonnull managedObject) {

    if(!model)//注意这里如果外部没有传入数据模型的话，要负责创建
        model = [PlaceModel new];
    model.zipCode = [managedObject valueForKey:@"uniqueID"];
    model.name = [managedObject valueForKey:@"name"];
    model.country = [managedObject valueForKey:@"country"];
    model.level = [[managedObject valueForKey:@"level"] intValue];

    return model;

} forEntity:@"PlaceEntity"];
```
至此数据库的配置操作都已经完成

### 使用 

<font color=Purple>*Tips: 因为`CoreData`对数据库操作都是通过 `NSManagedObjectContext` 来进行的，而 `NSManagedObjectContext` 又是”非线程安全“的*  

*`AsyncCoreData`跟业务相关的代码都定义在`AsyncCoreData.h`文件中*</font>

`AsyncCoreData`针对多线程，对每一种类型的业务都设计了三种不同类型的方法:
```objc
//类型A 同步操作，最常规的数据，每次调用都会创建一个NSManagedObjectContext，相对来说效率并不是非常高
+[AsyncCoreData queryEntity:(NSString *)entityName xxx:];

//类型B 利用已有NSManagedObjectContext进行同步操作，这种方法的目的是解决类型A的效率问题，比如在一段循环代码中(这段代码都在同一个线程执行)需要频繁地进行数据库操作，这个时候就可以+[AsyncCoreData newContext]获取一个tempContext并引用住，然后每次调用的话将tempContext传给context
+[AsyncCoreData queryEntity:(NSString *)entityName xxx:... inContext:(NSManagedObjectContext *)context];

//类型C 带有xxxAsync:的方法，异步操作，这种方法的所有操作都是在“同一个‘后台线程进行, 操作结果通过block回调
+[AsyncCoreData queryEntity:(NSString *)entityName xxxAsync:... completion:^(xxx){
    //block
}];
```
<font color=red>*Note: 由于实际验证，类型B相对于类型A效果提升并不明显，所以现在版本已经将类型B方法从接口中移除*</font>

### 使用宏定义简化代码
在 `AsyncCoreData.h` 文件中有一个宏定义 `QUERY_ENTITY()`

可以利用这个宏来简化我们的代码

举个栗子：

不实用宏定义，写起来是这样的
```objc
[AsyncCoreData queryEntity:@"PlaceEntity" saveModels:myDataModels];//保存数据

[AsyncCoreData queryEntity:@"PlaceEntity"  modelsWithPredicate:predicate inRange:range sortByKey:level reverse:YES];//查询数据

```

使用宏定义

```objc
//首先自己定义一个封装自 QUERY_ENTITY 的宏
#define DB_PLACE QUERY_ENTITY(@"PlaceEntity")
```

```objc
[DB_PLACE saveModels:myDataModels];//保存数据

[DB_PLACE modelsWithPredicate:predicate inRange:range sortByKey:level reverse:YES];//查询数据

```


## Installation

AsyncCoreData is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'AsyncCoreData'
```

## Author

罗亮富 zxllf23@163.com 

## License

AsyncCoreData is available under the MIT license. See the LICENSE file for more info.
