#import <React/RCTUIManager.h>
#import <React/RCTViewManager.h>

/**
 * Registers the SceneKit preview as a React Native view.
 *
 * Prop names must match `ArmenusModelViewNativeComponent.ts` exactly; they are
 * paired by string, so a rename on one side stops the prop arriving rather
 * than failing the build.
 */
@interface RCT_EXTERN_MODULE (ArmenusModelViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(source, NSString)
RCT_EXPORT_VIEW_PROPERTY(posterUrl, NSString)

RCT_EXPORT_VIEW_PROPERTY(cameraOrbitTheta, double)
RCT_EXPORT_VIEW_PROPERTY(cameraOrbitPhi, double)
RCT_EXPORT_VIEW_PROPERTY(cameraDistance, double)
RCT_EXPORT_VIEW_PROPERTY(exposure, double)
RCT_EXPORT_VIEW_PROPERTY(shadowIntensity, double)
RCT_EXPORT_VIEW_PROPERTY(autoRotate, BOOL)
RCT_EXPORT_VIEW_PROPERTY(interactionEnabled, BOOL)

RCT_EXPORT_VIEW_PROPERTY(onModelLoad, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onModelError, RCTDirectEventBlock)

@end
