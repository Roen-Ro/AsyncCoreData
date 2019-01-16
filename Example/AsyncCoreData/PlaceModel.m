//
//  PlaceModel.m
//  AsyncCoreData_Example
//
//  Created by lolaage on 2019/1/12.
//  Copyright © 2019年 zxllf23@163.com. All rights reserved.
//

#import "PlaceModel.h"



@implementation PlaceModel

-(NSString *)uniqueValue {
    
    return self.zipCode;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p>{name:%@; country:%@; zipCode:%@; level:%d}",NSStringFromClass([self class]),self,_name,_country,_zipCode,_level];
}

@end
