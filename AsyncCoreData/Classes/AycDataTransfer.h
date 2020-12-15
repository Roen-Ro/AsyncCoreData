//
//  AycDataTransfer.h
//  AsyncCoreData
//
//  Created by 罗亮富 on 2020/12/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//TODO: 1.指定迁移的Entity 2.解决自定义唯一索引冲突(目前解决了uniqueID字段冲突，当目标库存在的话就不拷贝)


//数据迁移，将指定Entity的数据从一个数据库文件迁移到另一个数据库
@interface AycDataTransfer : NSObject

//全库拷贝，拷贝后原数据仍然保留
+(void)copyDataOfModel:(NSString *)modelName from:(NSURL *)srcDBFileUrl to:(NSURL *)destDBFileUrl error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
