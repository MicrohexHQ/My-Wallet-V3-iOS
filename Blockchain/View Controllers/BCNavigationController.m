//
//  BCNavigationController.m
//  Blockchain
//
//  Created by Kevin Wu on 10/12/16.
//  Copyright © 2016 Blockchain Luxembourg S.A. All rights reserved.
//

#import "BCNavigationController.h"
#import "Blockchain-Swift.h"

@interface BCNavigationController ()

@end

@implementation BCNavigationController

- (id)initWithRootViewController:(UIViewController *)rootViewController title:(NSString *)headerTitle;
{
    if (self = [super initWithRootViewController:rootViewController]) {
        self.headerTitle = headerTitle;
        self.shouldHideBusyView = YES; // default behavior
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];

    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    CGFloat safeAreaInsetTop;
    if (@available(iOS 11.0, *)) {
        safeAreaInsetTop = window.rootViewController.view.safeAreaInsets.top;
    } else {
        safeAreaInsetTop = 20;
    }

    CGFloat topBarHeight = ConstantsObjcBridge.defaultNavigationBarHeight + safeAreaInsetTop;
    self.topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, topBarHeight)];
    self.topBar.backgroundColor = UIColor.brandPrimary;
    [self.view addSubview:self.topBar];
    
    self.headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, safeAreaInsetTop + 6, 200, 30)];
    self.headerLabel.font = [UIFont fontWithName:FONT_MONTSERRAT_REGULAR size:FONT_SIZE_TOP_BAR_TEXT];
    self.headerLabel.textColor = [UIColor whiteColor];
    self.headerLabel.textAlignment = NSTextAlignmentCenter;
    self.headerLabel.adjustsFontSizeToFitWidth = YES;
    self.headerLabel.text = self.headerTitle;
    self.headerLabel.center = CGPointMake(self.topBar.center.x, self.headerLabel.center.y);

    [self.topBar addSubview:self.headerLabel];
    
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.closeButton.frame = CGRectMake(self.view.frame.size.width - 80, 15, 80, 51);
    self.closeButton.imageEdgeInsets = IMAGE_EDGE_INSETS_CLOSE_BUTTON_X;
    self.closeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    
    UIImage *closeImage = [[UIImage imageNamed:@"close"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.closeButton setImage:closeImage forState:UIControlStateNormal];
    self.closeButton.center = CGPointMake(self.closeButton.center.x, self.headerLabel.center.y);
    [self.closeButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self.closeButton setTintColor:[UIColor whiteColor]];
    [self.topBar addSubview:self.closeButton];
    
    self.backButton = [[UIButton alloc] initWithFrame:CGRectZero];
    self.backButton.imageEdgeInsets = UIEdgeInsetsMake(5, 8, 5, 0);
    self.backButton.frame = CGRectMake(0, 0, 85, 51);
    self.backButton.center = CGPointMake(self.backButton.center.x, self.headerLabel.center.y);
    self.backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.backButton setTitle:@"" forState:UIControlStateNormal];
    UIImage *backImage = [[UIImage imageNamed:@"back_chevron_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.backButton setImage:backImage forState:UIControlStateNormal];
    [self.backButton addTarget:self action:@selector(popViewController) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:self.backButton];    
}

- (void)applyNavigationBarAppearance:(NavigationBarAppearance)appearance withBackgroundColor:(UIColor *)backgroundColor
{
    UIColor *appearanceColor = appearance == NavigationBarAppearanceDark ? [UIColor whiteColor] : [UIColor brandPrimary];

    [self.backButton setTintColor:appearanceColor];
    [self.closeButton setTintColor:appearanceColor];
    [self.headerLabel setTextColor:appearanceColor];
    [self.backButton setTintColor:appearanceColor];
    [self.topBar setBackgroundColor:backgroundColor];
}

- (void)setHeaderTitle:(NSString *)headerTitle
{
    _headerTitle = headerTitle;
    self.headerLabel.text = headerTitle;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if (self.viewControllers.count > 1) {
        self.
        self.backButton.hidden = NO;
        self.closeButton.hidden = YES;
    } else {
        self.backButton.hidden = YES;
        self.closeButton.hidden = NO;
    }
}

- (void)popViewController
{
    if (self.viewControllers.count > 1) {
        [self popViewControllerAnimated:YES];
    } else {
        [self dismiss];
    }
    
    if (self.onPopViewController) self.onPopViewController();
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (self.onViewWillDisappear) self.onViewWillDisappear();
}

- (void)dismiss
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
