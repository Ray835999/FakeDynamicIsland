// FakeDynamicIslandPrefs — Settings pane for Fake Dynamic Island.
// Reads/writes the com.you.fakedi domain; each specifier posts
// "com.you.fakedi/ReloadPrefs" (see FakeDynamicIslandPrefs.plist) which the
// tweak listens for to live-reload.
#import <Preferences/Preferences.h>

@interface FakeDynamicIslandPrefs : PSListController
@end

@implementation FakeDynamicIslandPrefs
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistNamed:@"FakeDynamicIslandPrefs" target:self];
    }
    return _specifiers;
}
@end
