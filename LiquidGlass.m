// LiquidGlass.m : applique l'effet "liquid glass" (UIGlassEffect, iOS 26+) à Spotify.
// Pas de dépendance à Substrate : simple swizzling Objective-C, injectable via Sideloadly.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const NSInteger kGlassTag = 0x4C47;

static BOOL IsiOS26(void) {
    return [[UIDevice currentDevice].systemVersion compare:@"26.0" options:NSNumericSearch] != NSOrderedAscending;
}

static UIVisualEffect *MakeEffect(BOOL interactive) {
    Class g = NSClassFromString(@"UIGlassEffect");
    if (g && IsiOS26()) {
        @try {
            id e = [[g alloc] init];
            if (interactive) [e setValue:@YES forKey:@"interactive"];
            return e;
        } @catch (__unused NSException *ex) {}
    }
    // Repli pour iOS < 26 : flou fin (pas du vrai liquid glass)
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
}

// Ajoute une vue de verre au fond de `host`. radius < 0 => capsule.
static void ApplyGlass(UIView *host, CGFloat radius, BOOL interactive) {
    UIVisualEffectView *fx = (UIVisualEffectView *)[host viewWithTag:kGlassTag];
    if (![fx isKindOfClass:[UIVisualEffectView class]]) {
        fx = [[UIVisualEffectView alloc] initWithEffect:MakeEffect(interactive)];
        fx.tag = kGlassTag;
        fx.userInteractionEnabled = NO;
        fx.clipsToBounds = YES;
        fx.layer.cornerCurve = kCACornerCurveContinuous;
        [host insertSubview:fx atIndex:0];
        host.backgroundColor = UIColor.clearColor;
    }
    if (host.subviews.firstObject != fx) [host sendSubviewToBack:fx];
    if (!CGRectEqualToRect(fx.frame, host.bounds)) fx.frame = host.bounds;
    CGFloat r = radius < 0 ? MIN(host.bounds.size.width, host.bounds.size.height) / 2.0 : radius;
    if (fx.layer.cornerRadius != r) fx.layer.cornerRadius = r;
    // Masque les fonds opaques propres à l'app (classes dont le nom contient "Background")
    for (UIView *s in host.subviews) {
        if (s != fx && [NSStringFromClass([s class]) containsString:@"Background"]) s.alpha = 0;
    }
}

typedef NS_ENUM(NSInteger, Kind) { KindGlass, KindHide };

static void Hook(NSString *name, Kind kind, CGFloat radius, BOOL interactive) {
    Class cls = NSClassFromString(name);
    if (!cls || ![cls isSubclassOfClass:[UIView class]]) return;
    SEL sel = @selector(layoutSubviews);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    IMP orig = method_getImplementation(m);
    const char *types = method_getTypeEncoding(m);
    IMP newImp = imp_implementationWithBlock(^(UIView *v) {
        ((void (*)(id, SEL))orig)(v, sel);
        if (kind == KindHide) { v.alpha = 0; return; }
        ApplyGlass(v, radius, interactive);
    });
    if (!class_addMethod(cls, sel, newImp, types)) method_setImplementation(m, newImp);
    NSLog(@"[LiquidGlass] hook %@", name);
}

#if DUMP
static void Dump(UIView *v, int depth, NSMutableString *out) {
    if (depth > 14) return;
    [out appendFormat:@"%*s%@ %@\n", depth * 2, "", NSStringFromClass([v class]), NSStringFromCGRect(v.frame)];
    for (UIView *s in v.subviews) Dump(s, depth + 1, out);
}
static void DumpHierarchyToPasteboard(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *w = nil;
        for (UIScene *sc in UIApplication.sharedApplication.connectedScenes)
            if ([sc isKindOfClass:[UIWindowScene class]])
                for (UIWindow *x in ((UIWindowScene *)sc).windows) if (x.isKeyWindow) w = x;
        if (!w) return;
        NSMutableString *out = [NSMutableString string];
        Dump(w, 0, out);
        UIPasteboard.generalPasteboard.string = out;
    });
}
#endif

static void InstallHooks(void) {
    // Cibles de la v1 (noms trouvés dans le binaire, à affiner avec le dump de hiérarchie)
    Hook(@"SPTTabBar",                              KindGlass, -1, YES);  // barre d'onglets en capsule
    Hook(@"SPTNowPlayingBar",                       KindGlass, 22, YES);  // mini-lecteur
    Hook(@"SPTAdaptiveTabBarBackgroundContainer",   KindHide,   0, NO);   // ancien fond de la tab bar
}

__attribute__((constructor))
static void LiquidGlassInit(void) {
    InstallHooks();
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
        object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n) {
            InstallHooks(); // 2e passage au cas où certaines classes se chargent tard
#if DUMP
            DumpHierarchyToPasteboard();
#endif
        }];
}
