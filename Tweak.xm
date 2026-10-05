// FakeDynamicIsland — overlay-only fake Dynamic Island for iPhone 6s / iOS 15.
//
// SAFE BY DESIGN:
//  - Injects ONLY into SpringBoard (filter: com.apple.springboard).
//  - Draws a NON-interactive black pill in a top-level UIWindow (userInteractionEnabled=NO),
//    so it can never steal touches or break the UI.
//  - Does NOT modify any system file, does NOT touch MobileGestalt, does NOT hook any
//    boot-time path. Worst case = SpringBoard runtime crash -> palera1n Safe Mode.
//    It can therefore NOT white-apple (bootloop).
//
// WHY NOT DynamicCow: DynamicCow is a MacDirtyCow app that rewrites
// com.apple.MobileGestalt.plist (deviceSubType) so iOS 16's native Dynamic Island
// renderer believes it runs on an iPhone 14 Pro. iOS 15 has no such renderer, and
// rewriting that plist on iOS 15 is exactly what bootloops devices. Hence a fake,
// self-drawn island is the only safe path on A9 / iOS 15.

#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

// Forward declarations for the Darwin-notification callbacks (defined later).
static void fdiMediaChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static void fdiPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

// Resolve the Darwin notification center at runtime via dlsym — the public iOS
// SDK does not export CFNotificationCenterGetDarwinCenter, so referencing it
// directly fails to link. This avoids any static symbol reference.
static CFNotificationCenterRef fdiDarwinCenter(void) {
    static CFNotificationCenterRef c = NULL;
    static dispatch_once_t t;
    dispatch_once(&t, ^{
        void *sym = dlsym(RTLD_DEFAULT, "CFNotificationCenterGetDarwinCenter");
        if (sym) c = ((CFNotificationCenterRef (*)(void))sym)();
    });
    return c;
}

#define FDI_DOMAIN @"com.you.fakedi"
#define FDI_RELOAD CFSTR("com.you.fakedi/ReloadPrefs")
#define FDI_LOG_PATH @"/var/mobile/Documents/FakeDynamicIsland.log"

static void FDLog(NSString *fmt, ...) {
    va_list a; va_start(a, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:a];
    va_end(a);
    @try {
        NSString *prev = [NSString stringWithContentsOfFile:FDI_LOG_PATH encoding:NSUTF8StringEncoding error:nil];
        if (prev.length > 16000) prev = [prev substringFromIndex:prev.length - 16000];
        NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], s];
        [[prev stringByAppendingString:line] writeToFile:FDI_LOG_PATH atomically:NO encoding:NSUTF8StringEncoding error:nil];
    } @catch (id e) {}
}

@interface FDIManager : NSObject
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIView *pill;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, assign) BOOL enabled, showNowPlaying, showCharging, showAppLaunch, showLowPower, animate;
@property (nonatomic, assign) CGFloat pw, ph, pcr, pyoff, expandDur, collapseDur;
@property (nonatomic, assign) BOOL transient;
+ (instancetype)shared;
- (void)reloadPrefs;
- (void)applyGeometry;
- (void)refresh;
- (void)expandWithText:(NSString*)text glyph:(NSString*)g;
- (void)collapse;
@end

@implementation FDIManager
+ (instancetype)shared {
    static FDIManager *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [[FDIManager alloc] init]; });
    return s;
}
- (instancetype)init {
    if ((self = [super init])) {
        [self reloadPrefs];
        [self setupWindow];
        [self observe];
        FDLog(@"[FakeDI] init done enabled=%d", self.enabled);
    }
    return self;
}
- (void)reloadPrefs {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:FDI_DOMAIN];
    id e  = [d objectForKey:@"Enabled"];        self.enabled        = e  ? [e boolValue]  : YES;
    id np = [d objectForKey:@"ShowNowPlaying"]; self.showNowPlaying = np ? [np boolValue] : YES;
    id ch = [d objectForKey:@"ShowCharging"];   self.showCharging   = ch ? [ch boolValue] : YES;
    id al = [d objectForKey:@"ShowAppLaunch"];  self.showAppLaunch  = al ? [al boolValue] : YES;
    id lp = [d objectForKey:@"ShowLowPower"];   self.showLowPower   = lp ? [lp boolValue] : YES;
    id an = [d objectForKey:@"Animate"];        self.animate        = an ? [an boolValue] : YES;
    self.pw         = [d objectForKey:@"PillWidth"]        ? [[d objectForKey:@"PillWidth"]        floatValue] : 120.0f;
    self.ph         = [d objectForKey:@"PillHeight"]       ? [[d objectForKey:@"PillHeight"]       floatValue] : 34.0f;
    self.pcr        = [d objectForKey:@"PillCornerRadius"] ? [[d objectForKey:@"PillCornerRadius"] floatValue] : 17.0f;
    self.pyoff      = [d objectForKey:@"PillYOffset"]      ? [[d objectForKey:@"PillYOffset"]      floatValue] : 8.0f;
    self.expandDur  = [d objectForKey:@"ExpandDuration"]   ? [[d objectForKey:@"ExpandDuration"]   floatValue] : 0.40f;
    self.collapseDur= [d objectForKey:@"CollapseDuration"] ? [[d objectForKey:@"CollapseDuration"] floatValue] : 0.30f;
    FDLog(@"[FakeDI] prefs en=%d np=%d ch=%d al=%d lp=%d an=%d w=%.0f h=%.0f r=%.0f y=%.0f",
          self.enabled, self.showNowPlaying, self.showCharging, self.showAppLaunch,
          self.showLowPower, self.animate, self.pw, self.ph, self.pcr, self.pyoff);
}
- (void)setupWindow {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.windowLevel = UIWindowLevelStatusBar + 10.0;
    self.window.backgroundColor = [UIColor clearColor];
    self.window.userInteractionEnabled = NO;   // never steal touches -> safe
    self.window.hidden = NO;
    UIViewController *rc = [[UIViewController alloc] init];
    self.window.rootViewController = rc;
    self.pill = [[UIView alloc] initWithFrame:CGRectZero];
    self.pill.backgroundColor = [UIColor blackColor];
    self.pill.clipsToBounds = YES;
    self.pill.layer.masksToBounds = YES;
    [rc.view addSubview:self.pill];
    self.label = [[UILabel alloc] initWithFrame:self.pill.bounds];
    self.label.textColor = [UIColor whiteColor];
    self.label.font = [UIFont systemFontOfSize:13];
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.lineBreakMode = NSLineBreakByTruncatingTail;
    self.label.alpha = 0.0;
    [self.pill addSubview:self.label];
    [self applyGeometry];
    FDLog(@"[FakeDI] window created level=%.0f", (double)self.window.windowLevel);
}
- (void)applyGeometry {
    if (!self.pill) return;
    CGRect sr = [[UIScreen mainScreen] bounds];
    CGFloat w = self.pw, h = self.ph;
    CGFloat x = (sr.size.width - w) / 2.0;
    self.pill.frame = CGRectMake(x, self.pyoff, w, h);
    self.pill.layer.cornerRadius = self.pcr;
    self.label.frame = CGRectInset(self.pill.bounds, 8, 4);
}
- (void)expandWithText:(NSString*)text glyph:(NSString*)g {
    if (!self.enabled) return;
    if (text) self.label.text = [NSString stringWithFormat:@"%@ %@", (g ? g : @""), text];
    [UIView animateWithDuration:self.animate ? self.expandDur : 0.0 animations:^{
        CGRect f = self.pill.frame;
        f.size.width  = MAX(self.pw, 220.0);
        f.size.height = MAX(self.ph, 70.0);
        f.origin.x = ([[UIScreen mainScreen] bounds].size.width - f.size.width) / 2.0;
        self.pill.frame = f;
        self.label.frame = CGRectInset(self.pill.bounds, 8, 4);
        self.label.alpha = 1.0;
    }];
}
- (void)collapse {
    if (self.transient) return;   // app-launch transient in progress
    [UIView animateWithDuration:self.animate ? self.collapseDur : 0.0 animations:^{
        [self applyGeometry];
        self.label.alpha = 0.0;
    }];
}
- (void)refresh {
    if (!self.enabled) { self.window.hidden = YES; return; }
    self.window.hidden = NO;
    NSString *txt = nil; NSString *g = @"";
    if (self.showNowPlaying) {
        Class mcCls = NSClassFromString(@"SBMediaController");
        if (mcCls) {
            id mc = [(id)mcCls performSelector:@selector(sharedInstance)];
            if (mc && [mc respondsToSelector:@selector(isPlaying)] &&
                (BOOL)[mc performSelector:@selector(isPlaying)]) {
                id t = [mc respondsToSelector:@selector(nowPlayingTitle)]  ? [mc performSelector:@selector(nowPlayingTitle)]  : nil;
                id a = [mc respondsToSelector:@selector(nowPlayingArtist)] ? [mc performSelector:@selector(nowPlayingArtist)] : nil;
                NSString *ts = [t isKindOfClass:[NSString class]] ? t : nil;
                NSString *as = [a isKindOfClass:[NSString class]] ? a : nil;
                if (ts && as) txt = [NSString stringWithFormat:@"%@ — %@", ts, as];
                else if (ts) txt = ts;
                else txt = @"Now Playing";
                g = @"♪";
            }
        }
    }
    if (!txt && self.showCharging) {
        UIDevice *dev = [UIDevice currentDevice];
        if (dev.batteryState == UIDeviceBatteryStateCharging || dev.batteryState == UIDeviceBatteryStateFull) {
            txt = [NSString stringWithFormat:@"Charging %d%%", (int)(dev.batteryLevel * 100.0)];
            g = @"⚡";
        }
    }
    if (!txt && self.showLowPower) {
        if ([[NSProcessInfo processInfo] respondsToSelector:@selector(isLowPowerModeEnabled)] &&
            [[NSProcessInfo processInfo] isLowPowerModeEnabled]) {
            txt = @"Low Power Mode"; g = @"🍃";
        }
    }
    if (txt) {
        self.transient = NO;
        [self expandWithText:txt glyph:g];
    } else if (!self.transient) {
        [self collapse];
    }
}
- (void)appDidLaunch:(NSNotification*)n {
    if (!self.enabled || !self.showAppLaunch) return;
    NSString *name = nil;
    id app = n.object;
    if (app && [app respondsToSelector:@selector(displayName)]) name = [app displayName];
    [self expandWithText:(name ? [NSString stringWithFormat:@"Opening %@", name] : @"Opening") glyph:@"▶"];
    self.transient = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(endTransient) object:nil];
    [self performSelector:@selector(endTransient) withObject:nil afterDelay:1.3];
}
- (void)endTransient {
    self.transient = NO;
    [self refresh];
}
- (void)observe {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(appDidLaunch:) name:@"SBApplicationDidBeginLaunchingNotification" object:nil];
    [nc addObserver:self selector:@selector(refresh)      name:@"SBApplicationDidFinishLaunchingNotification" object:nil];
    [UIDevice currentDevice].batteryMonitoringEnabled = YES;
    [nc addObserver:self selector:@selector(refresh) name:UIDeviceBatteryStateDidChangeNotification object:nil];
    [nc addObserver:self selector:@selector(refresh) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(isLowPowerModeEnabled)]) {
        [nc addObserver:self selector:@selector(refresh) name:NSProcessInfoPowerStateDidChangeNotification object:nil];
    }
    CFNotificationCenterAddObserver(fdiDarwinCenter(), (__bridge void*)self,
        &fdiMediaChanged, CFSTR("kMRMediaRemoteNowPlayingInfoDidChangeNotification"), NULL,
        CFNotificationSuspensionBehaviorCoalesce);
    CFNotificationCenterAddObserver(fdiDarwinCenter(), (__bridge void*)self,
        &fdiPrefsChanged, FDI_RELOAD, NULL, CFNotificationSuspensionBehaviorCoalesce);
}
@end

static void fdiMediaChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    @try { [[FDIManager shared] refresh]; } @catch (id e) {}
}
static void fdiPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    @try {
        FDIManager *m = [FDIManager shared];
        [m reloadPrefs];
        [m applyGeometry];
        [m refresh];
    } @catch (id e) {}
}

%ctor {
    @try {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        if (![bid isEqualToString:@"com.apple.springboard"]) { FDLog(@"[FakeDI] skip, not SpringBoard (%@)", bid); return; }
        FDLog(@"[FakeDI] ctor SpringBoard iOS %@", [[UIDevice currentDevice] systemVersion]);
        [FDIManager shared];
    } @catch (NSException *e) {
        FDLog(@"[FakeDI] ctor exception: %@", e);
    }
}
