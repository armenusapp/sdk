#import <React/RCTBridgeModule.h>

/**
 * Exposes the Swift `ArmenusAr` module to React Native.
 *
 * Swift cannot declare RCT_EXTERN_MODULE, so the registration lives in this
 * thin Objective-C++ file. The selector strings here must match the `@objc`
 * signatures in ArmenusAr.swift exactly — a mismatch is not a build error, it
 * is a method that silently never gets called.
 */
@interface RCT_EXTERN_MODULE (ArmenusAr, NSObject)

RCT_EXTERN_METHOD(isArAvailable
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(prefetch
                  : (NSString *)url resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(presentAr
                  : (NSDictionary *)options resolve
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(cacheSize
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(clearCache
                  : (RCTPromiseResolveBlock)resolve reject
                  : (RCTPromiseRejectBlock)reject)

/*
 * Presentation touches UIKit, so the module must be set up on the main queue.
 * Returning NO here makes React Native construct it on its own thread and the
 * first `presentAr` throws a main-thread assertion in a release build.
 */
+ (BOOL)requiresMainQueueSetup {
  return YES;
}

@end
