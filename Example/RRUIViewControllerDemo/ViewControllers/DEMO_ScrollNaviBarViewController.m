#import "DEMO_ScrollNaviBarViewController.h"
#import "RRViewControllerExtension.h"
#import <Masonry/Masonry.h>
static NSString * const kCellIdentifier = @"ScrollNavigationCell";

@interface DEMO_ScrollNavigationPopoverViewController : UIViewController
@end

@implementation DEMO_ScrollNavigationPopoverViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 内容保持透明，便于观察 UIPopoverPresentationController 自带的背景材质、圆角和箭头。
    self.view.backgroundColor = UIColor.clearColor;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"分享至";
    titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    titleLabel.textColor = UIColor.secondaryLabelColor;
    titleLabel.adjustsFontForContentSizeCategory = YES;

    NSArray<NSString *> *shareTitles = @[@"微信", @"朋友圈", @"QQ", @"QQ空间"];
    NSArray<NSString *> *shareSymbols = @[@"message.fill", @"camera.aperture", @"bell.fill", @"star.fill"];
    NSArray<UIColor *> *shareColors = @[
        UIColor.systemGreenColor, UIColor.systemOrangeColor,
        UIColor.systemBlueColor, UIColor.systemYellowColor
    ];
    UIStackView *shareStack = [[UIStackView alloc] init];
    shareStack.axis = UILayoutConstraintAxisHorizontal;
    shareStack.distribution = UIStackViewDistributionFillEqually;
    shareStack.spacing = 4.0;

    for (NSUInteger index = 0; index < shareTitles.count; index++) {
        UIButton *button = [self buttonWithTitle:shareTitles[index]
                                        symbol:shareSymbols[index]
                                     shareItem:YES
                                         color:shareColors[index]];
        [shareStack addArrangedSubview:button];
    }

    UIView *separator = [[UIView alloc] init];
    separator.backgroundColor = UIColor.separatorColor;
    [separator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(0.5);
    }];

    UIStackView *actionStack = [[UIStackView alloc] init];
    actionStack.axis = UILayoutConstraintAxisVertical;
    NSArray<NSString *> *actionTitles = @[@"关注", @"复制链接", @"举报"];
    NSArray<NSString *> *actionSymbols = @[@"person.badge.plus", @"link", @"exclamationmark.triangle"];
    for (NSUInteger index = 0; index < actionTitles.count; index++) {
        UIButton *button = [self buttonWithTitle:actionTitles[index]
                                        symbol:actionSymbols[index]
                                     shareItem:NO
                                         color:UIColor.labelColor];
        [actionStack addArrangedSubview:button];
    }

    UIStackView *contentStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        titleLabel, shareStack, separator, actionStack
    ]];
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.spacing = 12.0;
    [self.view addSubview:contentStack];
    // 箭头一侧由系统提供安全区，内容约束到安全区以避免与箭头重叠。
    [contentStack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(16.0);
        make.left.equalTo(self.view.mas_safeAreaLayoutGuideLeft).offset(16.0);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-16.0);
        make.right.equalTo(self.view.mas_safeAreaLayoutGuideRight).offset(-16.0);
    }];

    CGFloat width = self.preferredContentSize.width;
    CGSize contentSize = [contentStack systemLayoutSizeFittingSize:CGSizeMake(width - 32.0, UILayoutFittingCompressedSize.height)
                                   withHorizontalFittingPriority:UILayoutPriorityRequired
                                         verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    self.preferredContentSize = CGSizeMake(width, ceil(contentSize.height) + 32.0);
}

- (UIButton *)buttonWithTitle:(NSString *)title
                       symbol:(NSString *)symbol
                    shareItem:(BOOL)shareItem
                        color:(UIColor *)color
{
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.image = [UIImage systemImageNamed:symbol];
    configuration.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:shareItem ? 32.0 : 26.0
                                                                                                        weight:UIImageSymbolWeightRegular];
    configuration.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:@{
        NSFontAttributeName: [UIFont preferredFontForTextStyle:shareItem ? UIFontTextStyleCaption1 : UIFontTextStyleTitle2]
    }];
    configuration.baseForegroundColor = UIColor.labelColor;
    configuration.imageColorTransformer = ^UIColor *(UIColor *incomingColor) {
        return color;
    };
    configuration.imagePlacement = shareItem ? NSDirectionalRectEdgeTop : NSDirectionalRectEdgeLeading;
    configuration.imagePadding = shareItem ? 8.0 : 16.0;
    configuration.contentInsets = shareItem ? NSDirectionalEdgeInsetsMake(8, 0, 8, 0) : NSDirectionalEdgeInsetsMake(12, 8, 12, 8);

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.configuration = configuration;
    button.contentHorizontalAlignment = shareItem ? UIControlContentHorizontalAlignmentCenter : UIControlContentHorizontalAlignmentLeading;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.accessibilityLabel = title;
    [button addTarget:self action:@selector(didSelectPopoverItem:) forControlEvents:UIControlEventTouchUpInside];
    [button mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_greaterThanOrEqualTo(shareItem ? 80.0 : 56.0);
    }];
    return button;
}

- (void)didSelectPopoverItem:(UIButton *)sender
{
    // Demo 仅反馈选中项，避免接入分享 SDK 或修改真实业务状态。
    NSLog(@"Popover 选中：%@", sender.accessibilityLabel);
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@interface DEMO_ScrollNaviBarViewController () <UITableViewDataSource, UITableViewDelegate, UIPopoverPresentationControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) CGFloat headerImageAspectRatio;
@property (nonatomic, assign) UITableViewStyle tableViewStyle;
@property (nonatomic, assign) BOOL navigationBarOpaque;
@end

@implementation DEMO_ScrollNaviBarViewController

- (instancetype)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _tableViewStyle = style;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.edgesForExtendedLayout = UIRectEdgeAll;
    self.extendedLayoutIncludesOpaqueBars = YES;
    self.navigationItem.title = @"滚动导航栏";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:self.tableViewStyle];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    // 图片从页面顶部开始，透明与不透明切换时都保持列表延伸至导航栏下方。
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.bottom.mas_equalTo(self.view);
    }];
    self.tableView.backgroundColor = [UIColor whiteColor];
    self.tableView.rowHeight = 60.0;
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.tableView.automaticallyAdjustsScrollIndicatorInsets = NO;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:kCellIdentifier];

    UIImage *image = [UIImage imageNamed:@"bg_activity_cover@2x.jpg"];
    if (image.size.width > 0.0 && image.size.height > 0.0) {
        self.headerImageAspectRatio = image.size.height / image.size.width;
        CGFloat width = CGRectGetWidth(self.view.bounds);
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, width * self.headerImageAspectRatio)];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        [headerView addSubview:imageView];
        [imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(headerView);
        }];

        UILabel *label = [[UILabel alloc] init];
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = UIColor.whiteColor;
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        label.adjustsFontForContentSizeCategory = YES;
        label.text = @"图片底部到达导航栏时，导航栏变为不透明";
        [headerView addSubview:label];
        [label mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(headerView);
            make.leading.trailing.equalTo(headerView).inset(16.0);
        }];
        self.tableView.tableHeaderView = headerView;
    }

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"]
                                                                         style:UIBarButtonItemStylePlain
                                                                        target:self
                                                                        action:@selector(showPopover:)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = @"更多操作";
}
- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    // 顶部不留白；底部保留安全区，避免最后一行被 Home Indicator 遮挡。
    UIEdgeInsets safeArea = self.view.safeAreaInsets;
    UIEdgeInsets contentInset = UIEdgeInsetsMake(0.0, 0.0, safeArea.bottom, 0.0);
    if (!UIEdgeInsetsEqualToEdgeInsets(self.tableView.contentInset, contentInset)) {
        self.tableView.contentInset = contentInset;
    }
    self.tableView.verticalScrollIndicatorInsets = UIEdgeInsetsMake(safeArea.top, 0.0, safeArea.bottom, 0.0);
    UIView *header = self.tableView.tableHeaderView;
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    CGFloat height = width * self.headerImageAspectRatio;
    if (header != nil && width > 0.0 &&
        (CGRectGetWidth(header.frame) != width || CGRectGetHeight(header.frame) != height)) {
        // tableHeaderView 的高度由 frame 决定，旋转或分屏后需重新赋值才能更新列表内容尺寸。
        header.frame = CGRectMake(0, 0, width, height);
        self.tableView.tableHeaderView = header;
    }
    [self updateNavigationBarForScrollView:self.tableView];
}

- (void)showPopover:(UIBarButtonItem *)sender
{
    if (self.presentedViewController != nil) {
        return;
    }

    DEMO_ScrollNavigationPopoverViewController *controller = [[DEMO_ScrollNavigationPopoverViewController alloc] init];
    controller.modalPresentationStyle = UIModalPresentationPopover;
    controller.preferredContentSize = CGSizeMake(MIN(360.0, CGRectGetWidth(self.view.bounds) - 32.0), 360.0);

    UIPopoverPresentationController *popover = controller.popoverPresentationController;
    popover.barButtonItem = sender;
    popover.delegate = self;
    [self presentViewController:controller animated:YES completion:nil];
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller
{
    // iPhone 的紧凑宽度默认会转为 Sheet；返回 None 才能直接观察 Popover 效果。
    return UIModalPresentationNone;
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller
                                                            traitCollection:(UITraitCollection *)traitCollection
{
    return UIModalPresentationNone;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 40;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier forIndexPath:indexPath];
    UIListContentConfiguration *content = [cell defaultContentConfiguration];
    content.text = [NSString stringWithFormat:@"列表项 %ld", (long)indexPath.row + 1];
    cell.contentConfiguration = content;
    cell.backgroundColor = UIColor.systemBackgroundColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self updateNavigationBarForScrollView:scrollView];
}

- (void)scrollViewDidChangeAdjustedContentInset:(UIScrollView *)scrollView
{
    [self updateNavigationBarForScrollView:scrollView];
}

- (void)updateNavigationBarForScrollView:(UIScrollView *)scrollView
{
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    if (scrollView != self.tableView || self.view.window == nil ||
        navigationBar.window != self.view.window ||
        self.navigationController.topViewController != self) {
        return;
    }

    // 在同一坐标系比较实际边缘，兼容安全区、列表样式及导航栏高度变化，避免硬编码滚动阈值。
    UIView *header = self.tableView.tableHeaderView;
    CGRect headerRect = header ? [header convertRect:header.bounds toView:self.view] : CGRectZero;
    CGRect navigationBarRect = [navigationBar convertRect:navigationBar.bounds toView:self.view];
    BOOL opaque = header == nil || CGRectGetMaxY(headerRect) <= CGRectGetMaxY(navigationBarRect);
    if (self.navigationBarOpaque == opaque) {
        return;
    }
    self.navigationBarOpaque = opaque;

    // 离屏列表也可能收到 offset 回调，不能覆盖当前页面的共享导航栏外观。
    if (self.navigationController.topViewController == self && self.view.window != nil) {
        [self updateNavigationAppearance:NO];
    }
}
-(UIImage *)preferredNavigationBarBackgroundImage {
    return [UIImage imageNamed:@"cusNavigationBar"];
}
- (BOOL)prefersNavigationBarTransparent
{
    return !self.navigationBarOpaque;
}

- (UIColor *)preferredNavatationBarColor
{
    return UIColor.systemBackgroundColor;
}

- (UIColor *)preferredNavigationItemColor
{
    return self.navigationBarOpaque ? UIColor.labelColor : UIColor.whiteColor;
}

- (NSDictionary *)preferredNavigationTitleTextAttributes
{
    return @{NSForegroundColorAttributeName: [self preferredNavigationItemColor]};
}

@end
