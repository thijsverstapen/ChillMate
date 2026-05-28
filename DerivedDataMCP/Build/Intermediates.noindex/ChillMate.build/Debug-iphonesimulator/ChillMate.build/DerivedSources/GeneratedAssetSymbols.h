#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.codex.ChillMate";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "HeaderSplash" asset catalog image resource.
static NSString * const ACImageNameHeaderSplash AC_SWIFT_PRIVATE = @"HeaderSplash";

/// The "SplashScreen" asset catalog image resource.
static NSString * const ACImageNameSplashScreen AC_SWIFT_PRIVATE = @"SplashScreen";

#undef AC_SWIFT_PRIVATE
