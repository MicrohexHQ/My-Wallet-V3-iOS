//
//  MainViewController.h
//  Tube Delays
//
//  Created by Ben Reeves on 10/11/2010.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//
#import "Assets.h"
#import "AssetSelectorView.h"

@protocol AssetDelegate
- (void)didSetAssetType:(LegacyAssetType)assetType;
- (void)selectorButtonClicked;
- (void)qrCodeButtonClicked;
@end

@interface TabViewController : UIViewController <UITabBarDelegate> {
    IBOutlet UITabBar *tabBar;
    UIViewController *activeViewController;
	UIViewController *oldViewController;

	int selectedIndex;
}

@property (nonatomic, retain) UINavigationBar *navigationBar;
@property (nonatomic, retain) UIViewController *activeViewController;
@property (nonatomic, retain) IBOutlet UIView *contentView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *tabBarBottomConstraint;
@property (strong, nonatomic) UIView *assetControlContainer;
@property (nonatomic, retain) UIView *menuSwipeRecognizerView;
@property (nonatomic) UIView *tabBarGestureView;

@property(weak, nonatomic) id <AssetDelegate> assetDelegate;

- (void)selectAsset:(LegacyAssetType)assetType;
- (void)setActiveViewController:(UIViewController *)nviewcontroller animated:(BOOL)animated index:(int)index;
- (void)addTapGestureRecognizerToTabBar:(UITapGestureRecognizer *)tapGestureRecognizer;
- (void)removeTapGestureRecognizerFromTabBar:(UITapGestureRecognizer *)tapGestureRecognizer;
- (int)selectedIndex;
- (void)updateBadgeNumber:(NSInteger)number forSelectedIndex:(int)index;
- (void)didFetchEthExchangeRate;
- (void)reloadSymbols;
@end
