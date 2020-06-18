//
//  DBModelMapProtocol.h
//  ZhuShouCustomize
//
//  Created by 罗亮富 on 2019/1/10.
//  Copyright © 2019年 罗亮富. All rights reserved.
//

#import <Foundation/Foundation.h>



@protocol UniqueValueProtocol <NSObject>

@required
/*
 在Xcode给Entity添加属性的时候
 1.需要设置一个uniqueID属性，该属性需为String类型
 2.在Inspector中将uniqueID其添加到Constraints
 3.为了加快查询速度，建议对uniqueID添加索引，添加方法为1)选中Entity,鼠标长按Xcode下面的”Add Entity“加号按钮，然后选中Add Fetch Indexes
 */
@property (nullable, readonly) NSString *uniqueValue; 

@end

