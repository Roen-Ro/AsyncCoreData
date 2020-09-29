//
//  PlaceModel.h
//  AsyncCoreData_Example
//
//  Created by lolaage on 2019/1/12.
//  Copyright © 2019年 zxllf23@163.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AsyncCoreData/AsyncCoreData.h>

@protocol UniqueValueProtocol;

@interface PlaceModel : NSObject<NSCopying, UniqueValueProtocol>

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *country;
@property (nonatomic, strong) NSString *zipCode;
@property (nonatomic) int level;
@end
