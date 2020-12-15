#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AsyncCoreData+Configration.h"
#import "AsyncCoreData.h"
#import "AsyncHelper.h"
#import "AycDataTransfer.h"
#import "UniqueValueProtocol.h"

FOUNDATION_EXPORT double AsyncCoreDataVersionNumber;
FOUNDATION_EXPORT const unsigned char AsyncCoreDataVersionString[];

