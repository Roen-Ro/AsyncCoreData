//
//  AsyncHelper.m
//  AsyncCoreData
//
//  Created by 罗亮富 on 2019/1/17.
//

#import <Foundation/Foundation.h>

void background_async(void(^task)(void)){
    
    if(task) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),task);
    }
}

void background_async_high(void(^task)(void)){
    
    if(task) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),task);
    }
}
void background_async_low(void(^task)(void)){
    
    if(task) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),task);
    }
}

void main_task(void(^task)(void)){
    
    if(task) {
        dispatch_async(dispatch_get_main_queue(),task);
    }
}
