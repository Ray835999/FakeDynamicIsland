// Minimal local stub for PSListController so the preference bundle compiles
// without the (often-missing) private Preferences.framework headers.
// At runtime the real class is provided by Settings.app.
#ifndef FDI_PREFERENCES_H
#define FDI_PREFERENCES_H
#import <UIKit/UIKit.h>

@interface PSListController : UIViewController
- (NSArray *)loadSpecifiersFromPlistNamed:(NSString *)name target:(id)target;
- (void)setPreferenceValue:(id)value specifier:(id)specifier;
- (id)readPreferenceValue:(id)specifier;
@end

#endif
