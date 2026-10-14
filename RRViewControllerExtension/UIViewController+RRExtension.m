//
//  UIViewController+RRExtension.m
//  Roen(罗亮富）zxllf23@163.com 2015.07

#import "UIViewController+RRExtension.h"
#import <objc/runtime.h>


//RRStatisticBridge只是用来
@interface UIViewController (RRStatisticBridge)
//只在viewWillDisappear:方法中调用
+(void)staticviewWillDisappearForViewController:(UIViewController *)viewController;
//只在-viewDidAppear:方法中调用
+(void)staticviewDidAppearForViewController:(UIViewController *)viewController;
@end


static UIImage *backIndicatorImage;
static NSMutableDictionary *sBeforeHookBlockMap;
static NSMutableDictionary *sAfterHookBlockMap;
#if VC_MemoryLeakDetectionEnabled
static NSHashTable *sVcLeakDetectionHashTable;
static NSMutableSet *sVcLeakDetectionDefaultExceptions;
__weak UIView *sMemleakWarningView;
#endif


#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
@interface RRNavigationScrollEdgeState : NSObject
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, assign) BOOL originalHidden;
@end

@implementation RRNavigationScrollEdgeState
@end

// 不递归进入自定义组件；复杂页面通过 UIKit 的公开接口明确指定列表。
static UIScrollView *RRNavigationContentScrollView(UIViewController *controller) API_AVAILABLE(ios(26.0));
static UIScrollView *RRNavigationContentScrollView(UIViewController *controller)
{
    UIScrollView *explicitScrollView = [controller contentScrollViewForEdge:NSDirectionalRectEdgeTop];
    if (explicitScrollView) {
        return explicitScrollView;
    }
    UIView *rootView = controller.viewIfLoaded;
    if (!rootView || rootView.hidden || rootView.alpha <= 0.01) {
        return nil;
    }
    if ([rootView isKindOfClass:UIScrollView.class]) {
        return (UIScrollView *)rootView;
    }
    UIScrollView *candidate = nil;
    for (UIView *view in rootView.subviews) {
        if (view.hidden || view.alpha <= 0.01 || ![view isKindOfClass:UIScrollView.class]) {
            continue;
        }
        UIResponder *responder = view.nextResponder;
        if ([responder isKindOfClass:UIViewController.class] && responder != controller) {
            continue;
        }
        if (candidate) {
            return nil;
        }
        candidate = (UIScrollView *)view;
    }
    return candidate;
}

static void RRUpdateNavigationScrollEdge(UIViewController *controller, BOOL suppress) API_AVAILABLE(ios(26.0));
static void RRUpdateNavigationScrollEdge(UIViewController *controller, BOOL suppress)
{
    static char stateKey;
    static char scrollOwnerKey;
    RRNavigationScrollEdgeState *state = objc_getAssociatedObject(controller, &stateKey);
    UIScrollView *scrollView = suppress ? RRNavigationContentScrollView(controller) : nil;

    // 列表替换、候选变得不明确或退出透明状态时，恢复之前接管的列表。
    if (state && (!scrollView || state.scrollView != scrollView)) {
        UIScrollView *previousScrollView = state.scrollView;
        if (previousScrollView && objc_getAssociatedObject(previousScrollView, &scrollOwnerKey) == state) {
            previousScrollView.topEdgeEffect.hidden = state.originalHidden;
            objc_setAssociatedObject(previousScrollView, &scrollOwnerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        objc_setAssociatedObject(controller, &stateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        state = nil;
    }
    if (!scrollView) {
        return;
    }
    RRNavigationScrollEdgeState *currentOwner = objc_getAssociatedObject(scrollView, &scrollOwnerKey);
    if (!state || currentOwner != state) {
        state = [[RRNavigationScrollEdgeState alloc] init];
        state.scrollView = scrollView;
        // 父子控制器显式关联同一列表时传递原值，旧控制器退出不能撤销新控制器的接管。
        state.originalHidden = currentOwner ? currentOwner.originalHidden : scrollView.topEdgeEffect.hidden;
        objc_setAssociatedObject(controller, &stateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(scrollView, &scrollOwnerKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    scrollView.topEdgeEffect.hidden = YES;
}
#endif

@implementation UIViewController (RRExtension)

//2022.09.14 move from +(void)initialize since ios16
+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        Class class = [self class];
        
        SEL originalSelector = @selector(loadView);
        SEL swizzledSelector = @selector(exchg_loadView);
        method_exchangeImplementations(class_getInstanceMethod(class, originalSelector), class_getInstanceMethod(class, swizzledSelector));
        
        originalSelector = @selector(viewDidLoad);
        swizzledSelector = @selector(exchg_viewDidLoad);
        method_exchangeImplementations(class_getInstanceMethod(class, originalSelector), class_getInstanceMethod(class, swizzledSelector));
        
        originalSelector = @selector(viewWillAppear:);
        swizzledSelector = @selector(exchg_viewWillAppear:);
        method_exchangeImplementations(class_getInstanceMethod(class, originalSelector), class_getInstanceMethod(class,swizzledSelector));
        
        originalSelector = @selector(viewDidAppear:);
        swizzledSelector = @selector(exchg_viewDidAppear:);
        method_exchangeImplementations(class_getInstanceMethod(class, originalSelector), class_getInstanceMethod(class,swizzledSelector));
        
        originalSelector = @selector(viewWillDisappear:);
        swizzledSelector = @selector(exchg_viewWillDisappear:);
        method_exchangeImplementations(class_getInstanceMethod(class, originalSelector), class_getInstanceMethod(class,swizzledSelector));
        
        originalSelector = @selector(viewDidDisappear:);
        swizzledSelector = @selector(exchg_viewDidDisappear:);
        method_exchangeImplementations(class_getInstanceMethod(class, originalSelector), class_getInstanceMethod(class,swizzledSelector));
        
        
        originalSelector = @selector(willMoveToParentViewController:);
        swizzledSelector = @selector(exchg_willMoveToParentViewController:);
        method_exchangeImplementations(class_getInstanceMethod(class, originalSelector), class_getInstanceMethod(class,swizzledSelector));
        
#if VC_MemoryLeakDetectionEnabled
        sVcLeakDetectionHashTable = [NSHashTable weakObjectsHashTable];
        sVcLeakDetectionDefaultExceptions = [NSMutableSet setWithObjects:@"UIAlertController",
                                             @"_UIRemoteInputViewController",
                                             @"UICompatibilityInputViewController",
                                             @"SFAirDropViewController",
                                             @"UISystemInputAssistantViewController",
                                             nil];
#endif
        

    });
}

#pragma mark- hook
+(void)hookLifecycle:(RRViewControllerLifeCycleMethod)lifecycleMethod
            onTiming:(RRMethodInsertTiming)timing
           withBlock:(RRViewControllerLifecycleHookBlock)block
{
    if(block)
    {
        if(timing == RRMethodInsertTimingBefore)
        {
            if(!sBeforeHookBlockMap)
                sBeforeHookBlockMap = [NSMutableDictionary dictionary];
            
            [sBeforeHookBlockMap setObject:block forKey:@(lifecycleMethod)];
        }
        else if(timing == RRMethodInsertTimingAfter)
        {
            if(!sAfterHookBlockMap)
                sAfterHookBlockMap = [NSMutableDictionary dictionary];
    
            [sAfterHookBlockMap setObject:block forKey:@(lifecycleMethod)];
        }
    }
}

-(void)invokeBeforeHookForLifecycle:(RRViewControllerLifeCycleMethod)lifecycleMethod animated:(BOOL)animate
{
    RRViewControllerLifecycleHookBlock blk = [sBeforeHookBlockMap objectForKey:@(lifecycleMethod)];
    if(blk)
        blk(self,animate);
}

-(void)invokeAfterHookForLifecycle:(RRViewControllerLifeCycleMethod)lifecycleMethod animated:(BOOL)animate
{
    RRViewControllerLifecycleHookBlock blk = [sAfterHookBlockMap objectForKey:@(lifecycleMethod)];
    if(blk)
        blk(self,animate);
}

#pragma mark- global setting
+(UIImage *)navigationBackBarButtonItemImage {
    if(!backIndicatorImage) {
        if (@available(iOS 26.0, *)) {
            // 旧版箭头画布含 44pt 高度和左侧偏移，新栏使用系统符号保持玻璃按钮居中；显式定制图片仍优先。
            backIndicatorImage = [UIImage systemImageNamed:@"chevron.backward"];
        } else {
            CGRect rect = CGRectMake(0, 0, 24, 44);
            CGFloat yInset = 14;
            CGFloat xOrg = 1;
            CGFloat xLen = 8;
            UIGraphicsBeginImageContextWithOptions(rect.size, NO, [UIScreen mainScreen].scale);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetStrokeColorWithColor(context,[UIColor blackColor].CGColor);
            CGContextSetLineJoin(context, kCGLineJoinRound);
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextSetLineWidth(context, 2.0);
            CGMutablePathRef path = CGPathCreateMutable();
            CGPathMoveToPoint(path, NULL, xOrg+xLen, yInset);
            CGPathAddLineToPoint(path, NULL, xOrg, rect.size.height/2);
            CGPathAddLineToPoint(path, NULL, xOrg+xLen, rect.size.height-yInset);
            CGContextAddPath(context, path);
            CGContextStrokePath(context);
            backIndicatorImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            CGPathRelease(path);

            if (@available(iOS 10.0, *)) {
                UIView *v = [UIView new];
                if(v.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) {
                    backIndicatorImage = [UIImage imageWithCGImage:backIndicatorImage.CGImage scale:backIndicatorImage.scale orientation:UIImageOrientationDown ];
                }
            }
        }
        
  
    }
    return backIndicatorImage;
}
+(void)setNavigationBackBarButtonItemImage:(UIImage *)image
{
    backIndicatorImage = image;
}

#pragma mark - exchanged life cyle methods

-(void)exchg_loadView
{
    [self invokeBeforeHookForLifecycle:RRViewControllerLifeCycleLoadView animated:NO];
    
    [self exchg_loadView];
    
    //有时候会在loadView中设置navigationItem,用户改变了这些设置的话，这里就不做其他处理了
    if([self shouldShowBackItem])
        [self showNavigationBackItem:YES];
    
    [self invokeAfterHookForLifecycle:RRViewControllerLifeCycleLoadView animated:NO];
}

- (void)exchg_viewDidLoad
{
    [self invokeBeforeHookForLifecycle:RRViewControllerLifeCycleViewDidLoad animated:NO];
    
    [self exchg_viewDidLoad];
    
    self.rr_visibleState = RRViewControllerViewDidLoad;
    
    //发现有些vc并不会调用exchg_loadView方法，所以这里再加一步保障
    if([self shouldShowBackItem])
        [self showNavigationBackItem:YES];

    [self invokeAfterHookForLifecycle:RRViewControllerLifeCycleViewDidLoad animated:NO];
    
}

- (void)exchg_viewWillAppear:(BOOL)animated
{
    [self invokeBeforeHookForLifecycle:RRViewControllerLifeCycleViewWillAppear animated:animated];
    
    [self exchg_viewWillAppear:animated];

    self.rr_visibleState = RRViewControllerWillAppear;
    
    [self updateNavigationAppearance:animated];
    self.navigationController.interactivePopGestureRecognizer.delegate = self;
    // self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    
    [self invokeAfterHookForLifecycle:RRViewControllerLifeCycleViewWillAppear animated:animated];
}

-(void)exchg_viewDidAppear:(BOOL)animated
{
    [self invokeBeforeHookForLifecycle:RRViewControllerLifeCycleViewDidAppear animated:animated];
    
    [self exchg_viewDidAppear:animated];
    
    self.rr_visibleState = RRViewControllerDidAppear;
    
    [UIViewController staticviewDidAppearForViewController:self];
    
//    objc_setAssociatedObject(self, @"viewAppear", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self setNeedsStatusBarAppearanceUpdate];

    [self invokeAfterHookForLifecycle:RRViewControllerLifeCycleViewDidAppear animated:animated];
}

- (void)exchg_viewWillDisappear:(BOOL)animated
{
    [self invokeBeforeHookForLifecycle:RRViewControllerLifeCycleViewWillDisappear animated:animated];
    
    [self exchg_viewWillDisappear:animated];
    
    self.rr_visibleState = RRViewControllerWillDisappear;
    
    [UIViewController staticviewWillDisappearForViewController:self];
    
    [self invokeAfterHookForLifecycle:RRViewControllerLifeCycleViewWillDisappear animated:animated];
    
}

-(void)exchg_viewDidDisappear:(BOOL)animated
{
    [self invokeBeforeHookForLifecycle:RRViewControllerLifeCycleViewDidDisappear animated:animated];
    [self exchg_viewDidDisappear:animated];
    
    self.rr_visibleState = RRViewControllerDidDisappear;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        // 等页面实际消失再恢复，避免交互返回尚未完成时透明页面闪出边缘效果。
        RRUpdateNavigationScrollEdge(self, NO);
    }
#endif
    
//    objc_setAssociatedObject(self, @"viewAppear", @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self invokeAfterHookForLifecycle:RRViewControllerLifeCycleViewDidDisappear animated:animated];
    
#if VC_MemoryLeakDetectionEnabled
    if(self.memoryLeakDetectionEnabled)
    {
        [sVcLeakDetectionHashTable addObject:self];
        [self detectMemoryLeak];
    }
#endif
}

-(void)exchg_willMoveToParentViewController:(UIViewController *)parent {
    [self exchg_willMoveToParentViewController:parent];
}
#pragma mark- extended properties
-(BOOL)isViewAppearing
{
//    NSNumber *v = objc_getAssociatedObject(self, @"viewAppear");
//    return v.boolValue;
    RRViewControllerVisibleState state = self.rr_visibleState;
    return state >= RRViewControllerDidAppear && state <= RRViewControllerWillDisappear;
}


static char kAssociatedObjectKey_visibleState;
-(void)setRr_visibleState:(RRViewControllerVisibleState)rr_visibleState {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_visibleState, @(rr_visibleState), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(RRViewControllerVisibleState)rr_visibleState {
    return [((NSNumber *)objc_getAssociatedObject(self, &kAssociatedObjectKey_visibleState)) unsignedIntegerValue];
}

static char kAssociatedObjectKey_overtyleSettingsByYourSelf;
-(void)setRr_overtyleSettingsByYourSelf:(BOOL)rr_overtyleSettingsByYourSelf {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_overtyleSettingsByYourSelf, @(rr_overtyleSettingsByYourSelf), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        if (rr_overtyleSettingsByYourSelf) {
            RRUpdateNavigationScrollEdge(self, NO);
        }
    }
#endif
}
-(BOOL)rr_overtyleSettingsByYourSelf {
    return [(objc_getAssociatedObject(self, &kAssociatedObjectKey_overtyleSettingsByYourSelf)) boolValue];
}
#pragma mark-

//only adapt for calling in method -loadView
-(BOOL)shouldShowBackItem {

     return (   self.navigationController
             &&  !self.navigationItem.leftBarButtonItems
             && ![self inter_prefersNavigationBackItemHidden]
             );
}

-(void)showNavigationBackItem:(BOOL)show
{
    NSMutableArray *leftItems = [NSMutableArray arrayWithArray:self.navigationItem.leftBarButtonItems];
    UIBarButtonItem *backItem = self.navigationBackItem;
    
    if(!backItem)
        return;

    if(show)
    {
        if(![leftItems containsObject:backItem])
        {
            [leftItems insertObject:backItem atIndex:0];
        }
    }
    else if([leftItems containsObject:backItem])
    {
        [leftItems removeObject:backItem];
    }
    
    
    self.navigationItem.leftBarButtonItems = leftItems;
}

-(void)updateNavigationAppearance:(BOOL)animated
{
    BOOL managesAppearance = self.navigationController && self.isViewLoaded &&
        ![self.navigationController isKindOfClass:UIImagePickerController.class] &&
        ![self overtyleSettingsByYourSelf] && !self.rr_overtyleSettingsByYourSelf;
    if (!managesAppearance) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
        if (@available(iOS 26.0, *)) {
            RRUpdateNavigationScrollEdge(self, NO);
        }
#endif
        return;
    }

    BOOL hidden = [self prefersNavigationBarHidden];

    if(hidden)
    {
        [self.navigationController setNavigationBarHidden:YES animated:animated];
    }
    else
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
        if (!self.searchDisplayController.isActive)
        {
            [self.navigationController setNavigationBarHidden:NO animated:animated];
        }
#pragma clang diagnostic pop
    }
    
    //only set in viewDidLoad
  //  [self showNavigationBackItem:![self inter_prefersNavigationBackItemHidden]];
    
    BOOL transparent = [self prefersNavigationBarTransparent];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        // 转场中的源页面保持当前效果，真正退出时由 viewDidDisappear 统一恢复。
        if (self.rr_visibleState != RRViewControllerWillDisappear) {
            BOOL active = self.rr_visibleState != RRViewControllerDidDisappear;
            RRUpdateNavigationScrollEdge(self, transparent && !hidden && active);
        }
    }
#endif
    [self.navigationController setNavigationBarTransparent:transparent];
    if(!transparent)
    {
//#warning 这里是否欠妥，如果设置为nil的话，是不是把上次设定的默认图片也覆盖了
        //set navigation bar background image
        UIImage *bgImage = [self preferredNavigationBarBackgroundImage];
        [self.navigationController.navigationBar reloadBarBackgroundImage:bgImage];
        [self.navigationController.navigationBar reloadBarShadowImage:nil];
    }
    
    
    //set navigation bar tintColor
    [self.navigationController.navigationBar reloadBarBackgroundColor:[self preferredNavatationBarColor]];
    
    //set navigation bar item tintColor
    UIColor *barItemTintColor = [self preferredNavigationItemColor];
    [self.navigationController.navigationBar setTintColor:barItemTintColor];
    
    //set navigation bar title attributed
    [self.navigationController.navigationBar reloadBarTitleTextAttributes:[self preferredNavigationTitleTextAttributes]];

    if (@available(iOS 26.0, *)) {
        // Item 外观优先于共享导航栏；同步最终配置，避免旧 Item 背景遮住头图或阻止上滑后恢复。
        UINavigationBarAppearance *appearance = [self.navigationController.navigationBar.standardAppearance copy];
        self.navigationItem.standardAppearance = appearance;
        self.navigationItem.scrollEdgeAppearance = appearance;
        self.navigationItem.compactAppearance = appearance;
        self.navigationItem.compactScrollEdgeAppearance = appearance;
    }
    
}


-(UIBarButtonItem *)navigationBackItem
{
    UIBarButtonItem *backItem = objc_getAssociatedObject(self, @"backItem");
    if(!backItem)
    {
        backItem = [[UIBarButtonItem alloc] initWithImage:[[self class] navigationBackBarButtonItemImage] style:UIBarButtonItemStylePlain target:nil action:nil];
        objc_setAssociatedObject(self, @"backItem", backItem, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        backItem.target = self;
        backItem.action = @selector(dismissBarButtonItemEventHandle:);
    }
    
    return backItem;
}

-(UIColor *)preferredNavatationBarColor
{
    UIColor *c = self.navigationController.defaultNavatationBarColor;
    if(!c)
        c = [UINavigationBar appearance].barTintColor;
    
    return c;
}

-(UIColor *)preferredNavigationItemColor
{
    UIColor *c = self.navigationController.defaultNavigationItemColor;
    if(!c)
        c =  [UINavigationBar appearance].tintColor;
    
    return c;
}

-(NSDictionary *)preferredNavigationTitleTextAttributes
{
    NSDictionary *dic = self.navigationController.defaultNavigationTitleTextAttributes;
    
    if(!dic)
        dic = [[UINavigationBar appearance] titleTextAttributes];
    
    return dic;
}

-(UIImage *)preferredNavigationBarBackgroundImage
{
    UIImage *img = self.navigationController.defaultNavigationBarBackgroundImage;

    if(!img)
        img = [[UINavigationBar appearance] backgroundImageForBarMetrics:UIBarMetricsDefault];
    
    return img;
}

-(BOOL)prefersNavigationBarTransparent
{
    return self.navigationController.defaultNavigationBarTransparent;
}
/// 自己设置样式 yes 则不会在 viewWillAppear 中触发 updateNavigationAppearance NO 则会触发 默认为NO
-(BOOL)overtyleSettingsByYourSelf {
    return NO;
}

-(BOOL)prefersNavigationBarHidden
{
    NSString *className = NSStringFromClass(self.class);
    if ([className hasPrefix:@"TXY"]) {
        /// 人脸识别的controller
        return true;
    }
    return self.navigationController.defaultNavigationBarHidden;
}

-(BOOL)inter_prefersNavigationBackItemHidden
{
    BOOL hidden = NO;
    if(!self.navigationController.presentingViewController)
    {
        if(self.navigationController.childViewControllers.count > 0)
        {
            if(self.navigationController.viewControllers.firstObject == self)
                hidden = YES;
        }
    }
   
    return hidden;
}


-(BOOL)viewControllerShouldDismiss
{
    return YES;
}

-(void)navitationItemPush
{
    [self.navigationItem popStatus];
}
-(void)navitationItemPop
{
    [self.navigationItem pushStatus];
}

#pragma mark-

-(IBAction)dismissBarButtonItemEventHandle:(UIBarButtonItem *)backItem
{
    if([self viewControllerShouldDismiss])
        [self dismissView];
}


-(void)dismissView
{
    [self dismissViewWithCompletionBlock:nil];
}

- (void)dismissViewWithCompletionBlock: (void (^ __nullable)(void))completion
{
    [self dismissViewAnimated:YES completionBlock:completion];
    
}

- (void)dismissViewAnimated:(BOOL)animate completionBlock: (void (^ __nullable)(void))completion
{
    __weak typeof(self) weak_self = self;
    UIViewController *popBackVc = nil;
    if(self.navigationController)
    {
        NSArray *viewControllers = weak_self.navigationController.viewControllers;
        NSUInteger selfIndx = NSNotFound;//
        
        UIViewController *tmpVc = self;
        
        //这个操作骚不骚？Coquettish operation 就这么叫吧
        for(int i=0; i<1000; i++) //limit loop time to avoid dead loop
        {
            //TODO: 这里应该判断一下tmpVc是否为nil
            selfIndx = [viewControllers indexOfObject:tmpVc];
            if(selfIndx != NSNotFound)
                break;
            
            tmpVc = tmpVc.parentViewController;
        }
        
        
        if(selfIndx > 0 && selfIndx != NSNotFound)
            popBackVc = [viewControllers objectAtIndex:selfIndx-1];
    }
    
    if(popBackVc)
    {
        [self.navigationController popToViewController:popBackVc animated:animate completionBlock:completion];
    }
    else if(self.presentingViewController || self.navigationController.presentingViewController)
    {
        [self dismissViewControllerAnimated:animate completion:completion];
    }
}

#pragma mark- Navigation pull back
-(BOOL)navigationControllerAllowSidePanPopBack
{
    if(self.navigationController.childViewControllers.count == 1)//必须增加这个判断条件 否则会阻断用户触摸事件
        return NO;
    else
    {
        return [self viewControllerShouldDismiss];
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if(gestureRecognizer == self.navigationController.interactivePopGestureRecognizer)
    {
        return [self navigationControllerAllowSidePanPopBack];
    }
    else
        return YES;
}


#pragma mark- memory leak detection

-(void)detectMemoryLeak
{
#if VC_MemoryLeakDetectionEnabled
    if(self == [UIApplication sharedApplication].keyWindow.rootViewController)
        return;
    
    __weak typeof(self) weak_self = self;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if(weak_self
           && !weak_self.parentViewController
           && !weak_self.presentingViewController
           && !weak_self.view.superview)
        {
//            __strong typeof(weak_self) strong_self = weak_self;
            if([sVcLeakDetectionHashTable containsObject:weak_self]) {
                [weak_self didReceiveMemoryLeakWarning];
            }
        }
    });
    
#endif
}

-(void)didReceiveMemoryLeakWarning
{
#if VC_MemoryLeakDetectionEnabled
    NSString *info = [NSString stringWithFormat:@" %@:%@",NSStringFromClass([self class]),self.title];
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    
    if(!sMemleakWarningView)
    {
        UIView *v = [[UIView alloc]initWithFrame:CGRectMake(0, keyWindow.frame.size.height - 100, keyWindow.frame.size.width, 100)];
        v.alpha = 0.9;
        [keyWindow addSubview:v];
        
        UITextView *txV = [[UITextView alloc]initWithFrame:v.bounds];
        txV.tag = 23;
        txV.editable = NO;
        txV.backgroundColor = [UIColor redColor];
        txV.textColor = [UIColor yellowColor];
        txV.font  = [UIFont systemFontOfSize:14];
        txV.text = @"Memory leak warnings:";
        [v addSubview:txV];
        
        UIButton *clsBtn = [[UIButton alloc]initWithFrame:CGRectMake(txV.frame.size.width-50, 5, 44, 30)];
        clsBtn.backgroundColor = [UIColor colorWithWhite:1 alpha:0.5];
        [clsBtn setTitle:@"x" forState:UIControlStateNormal];
        [clsBtn setTintColor:[UIColor greenColor]];
        [clsBtn addTarget:[self class] action:@selector(closeWarning) forControlEvents:UIControlEventTouchUpInside];
        [v addSubview:clsBtn];
        
        sMemleakWarningView = v;
    }
    
    UITextView *txV = [sMemleakWarningView viewWithTag:23];
    
    NSMutableString *mStr = [NSMutableString stringWithString:txV.text];
    [mStr appendFormat:@"\n%@",info];
    txV.text = mStr;
    [keyWindow bringSubviewToFront:sMemleakWarningView];
    NSLog(@"WARNING:Detected memory leak with %@",info);
#endif
}

#if VC_MemoryLeakDetectionEnabled
+(void)closeWarning
{
    [sMemleakWarningView removeFromSuperview];
}
#endif

-(void)setEnabledMemoryLeakDetection:(BOOL)enable
{
#if VC_MemoryLeakDetectionEnabled
    objc_setAssociatedObject(self, @"memleakDetec", [NSNumber numberWithBool:enable], OBJC_ASSOCIATION_RETAIN);
#endif
}

-(BOOL)memoryLeakDetectionEnabled
{
#if VC_MemoryLeakDetectionEnabled
    NSNumber *n = objc_getAssociatedObject(self, @"memleakDetec");
    if(n)
        return n.boolValue;
    else
    {
        NSString *myClassStr = NSStringFromClass([self class]);
        return ![sVcLeakDetectionDefaultExceptions containsObject:myClassStr];
    }
#else
    return NO;
#endif
}

+(NSMutableSet<NSString *> *)memoryLeakDetectionExcludedClasses
{
#if VC_MemoryLeakDetectionEnabled
    return sVcLeakDetectionDefaultExceptions;
#else
    return nil;
#endif
}

// MARK: - Other class methods
+(NSString *)stackStringFor:(NSArray<UIViewController *> *)viewControllers {
    NSMutableString *retStr = [NSMutableString stringWithCapacity:1024];
    [retStr appendString:@"[\n"];
    int i = 0;
    for(UIViewController *vc in viewControllers) {
        [retStr appendString:[self logStringFor:vc]];
        if(i < viewControllers.count - 1) {
            [retStr appendString:@"\n"];
        }
        i++;
    }
    [retStr appendString:@"\n]"];
    return retStr.copy;
}


+(NSString *)logStringFor:(UIViewController *)viewController {
    return [NSString stringWithFormat:@"%@.%@<%p>",NSStringFromClass(viewController.class), viewController.title,viewController];;
}

@end
