#import "DEMO_ScrollNaviBarViewController.h"
#import "RRViewControllerExtension.h"
#import <Masonry/Masonry.h>
static NSString * const kCellIdentifier = @"ScrollNavigationCell";

@interface DEMO_ScrollNaviBarViewController () <UITableViewDataSource, UITableViewDelegate>
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

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:@"Next" forState:UIControlStateNormal];
    [btn sizeToFit];
    [btn addTarget:self action:@selector(_pushNext:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:btn];
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

-(void)_pushNext:(UIButton*)btn {
    DEMO_ScrollNaviBarViewController *controller = [[DEMO_ScrollNaviBarViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [self.navigationController pushViewController:controller animated:YES];
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
