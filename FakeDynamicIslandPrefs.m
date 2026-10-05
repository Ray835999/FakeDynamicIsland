// FakeDynamicIslandPrefs — Settings pane for Fake Dynamic Island.
// Reads/writes the com.you.fakedi domain; each specifier posts
// "com.you.fakedi/ReloadPrefs" (see FakeDynamicIslandPrefs.plist) which the
// tweak listens for to live-reload.
#import "Preferences.h"
#import <objc/runtime.h>

@interface FakeDynamicIslandPrefs : PSListController
@end

@implementation FakeDynamicIslandPrefs
- (NSArray *)specifiers {
    NSArray *s = objc_getAssociatedObject(self, "fdi_specifiers");
    if (!s) {
        s = [self loadSpecifiersFromPlistNamed:@"FakeDynamicIslandPrefs" target:self];
        objc_setAssociatedObject(self, "fdi_specifiers", s, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return s;
}
@end
