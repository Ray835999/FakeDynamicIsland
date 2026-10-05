// FakeDynamicIslandPrefs — Settings pane for Fake Dynamic Island.
// Reads/writes the com.you.fakedi domain; each specifier posts
// "com.you.fakedi/ReloadPrefs" (see FakeDynamicIslandPrefs.plist) which the
// tweak listens for to live-reload.
//
// DEFENSIVE: this pane loads inside Settings.app. Any failure while building
// the specifier list must NEVER throw past this method — otherwise it takes
// down the whole Settings app (which eagerly loads preference bundles). We
// guard the loader and return an empty list on any error instead of crashing.
#import "Preferences.h"
#import <objc/runtime.h>

@interface FakeDynamicIslandPrefs : PSListController
@end

@implementation FakeDynamicIslandPrefs
- (NSArray *)specifiers {
    NSArray *s = objc_getAssociatedObject(self, "fdi_specifiers");
    if (!s) {
        @try {
            if ([self respondsToSelector:@selector(loadSpecifiersFromPlistNamed:target:)]) {
                s = [self loadSpecifiersFromPlistNamed:@"FakeDynamicIslandPrefs" target:self];
            }
        } @catch (id e) {
            s = nil;
        }
        if (!s) s = @[];
        objc_setAssociatedObject(self, "fdi_specifiers", s, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return s;
}
@end
