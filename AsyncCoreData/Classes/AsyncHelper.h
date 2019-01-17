//
//  AsyncHelper.h
//  AsyncCoreData
//
//  Created by 罗亮富 on 2019/1/17.
//

#ifndef AsyncHelper_h
#define AsyncHelper_h
#import <Foundation/Foundation.h>

extern void background_async(void(^task)(void));
extern void background_async_high(void(^task)(void));
extern void background_async_low(void(^task)(void));

extern void main_task(void(^task)(void));

#endif /* AsyncHelper_h */
