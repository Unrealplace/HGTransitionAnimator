//
//  HGTransitioningDelegate.m
//  HGTransitionAnimator
//
//  Created by 查昊 on 16/5/23.
//  Copyright © 2016年 haocha. All rights reserved.
//

#import "HGTransitionAnimator.h"
#import "HGPresentationController.h"
#import "UIView+HGExtension.h"
#import <objc/runtime.h>


static NSString * const HGPresentationControllerKey=@"HGPresentationControllerKey";
const  NSTimeInterval defaultDuratin=0.52;

@interface  HGTransitionAnimator()

@property (nonatomic, weak)   UIView *relateView;//<-参照的View
@property (nonatomic, assign) BOOL  willPresent;//<- 即将展示
@property (nonatomic, assign) BOOL animated;//<- 是否动画
@property (nonatomic, assign) CGRect presentFrame;//<- 弹出视图的的frame
@property (nonatomic, assign) HGTransitionAnimatorStyle animateStyle;//<- 动画样式
@property (nonatomic, assign) NSTimeInterval duration;//<- 动画时间
@property (nonatomic, strong) UIColor *backgroundColor;//<- 蒙版背景色
@property (nonatomic, assign, nullable) id <HGTransitionAnimatorDelegate> delegate;//<- 代理

@end

@implementation HGTransitionAnimator

-(instancetype)initWithAnimateStyle:(HGTransitionAnimatorStyle)animateStyle
                         relateView:(UIView *)relateView
                       presentFrame:(CGRect)presentFrame
                    backgroundColor:(UIColor *)backgroundColor
                           delegate:(id<HGTransitionAnimatorDelegate>)delegate
                           animated:(BOOL)animated
{
    if (self=[super init]) {
        _animateStyle = animateStyle;
        _relateView = relateView;
        _presentFrame = presentFrame;
        _delegate = delegate;
        _animated = animated;
        _duration = _animated ? defaultDuratin: 0;
        _backgroundColor = backgroundColor == nil ? [UIColor clearColor] : backgroundColor;
    }
    return self;
}

-(UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented
                                                     presentingViewController:(UIViewController *)presenting
                                                         sourceViewController:(UIViewController *)source
{
    
    BOOL response = YES;
    if (self.delegate && [self.delegate respondsToSelector:@selector(transitionAnimatorCanResponse:)]) {
        response = [self.delegate transitionAnimatorCanResponse:self];
    }
    HGPresentationController *presentController =
    [[HGPresentationController alloc] initWithPresentedViewController:presented
                                             presentingViewController:presenting
                                                      backgroundColor:_backgroundColor
                                                         animateStyle:_animateStyle
                                                         presentFrame:_presentFrame
                                                             duration:_duration response:response];
    
    objc_setAssociatedObject(self, &HGPresentationControllerKey, presentController,OBJC_ASSOCIATION_ASSIGN);
    return presentController;
}

-(id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
                                                                 presentingController:(UIViewController *)presenting
                                                                     sourceController:(UIViewController *)source
{
    self.willPresent = YES;
    if (self.delegate&&[self.delegate respondsToSelector:@selector(transitionAnimator:animationControllerForPresentedController:)]) {
        [self.delegate transitionAnimator:self animationControllerForPresentedController:source];
    }
    return self;
}

-(id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    self.willPresent = NO;
    if (self.delegate&&[self.delegate respondsToSelector:@selector(transitionAnimator:animationControllerForDismissedController:)]) {
        [self.delegate transitionAnimator:self animationControllerForDismissedController:dismissed];
    }
    return self;
}

-(NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    if(self.delegate&&[self.delegate respondsToSelector:@selector(transitionDuration:)]){
        _duration = !_animated ? 0 : [self.delegate transitionDuration:self];
       };
    return _duration;
}

-(void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIView *coverView = [self getPresentationControllerCoverView];
    if (_willPresent) {
        UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
         UIView *toView = toViewController.view;
        toView.frame = _presentFrame;
        [[transitionContext containerView] addSubview:toView];
        if (_animateStyle == HGTransitionAnimatorCustomStyle) { // 自定义
            NSAssert(self.delegate&&[self.delegate respondsToSelector:@selector(transitionAnimator:animateTransitionToView:duration:)], @"自定义样式必须实现transitionAnimator:animateTransitionToView:duration:代理方法!");
            [self.delegate transitionAnimator:self animateTransitionToView:toView duration:_duration];
            [UIView animateWithDuration:_duration animations:^{
                coverView.backgroundColor = _backgroundColor;
            } completion:^(BOOL finished) {
                [transitionContext completeTransition:YES];
            }];
        }else{
            [self setupPushAnimator:toView context:transitionContext coverView:coverView];
        }
    }else{
//        UIView *fromView=[transitionContext viewForKey:UITransitionContextFromViewKey];
        UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
        UIView *fromView = fromViewController.view;
        if (_animateStyle == HGTransitionAnimatorCustomStyle) { // 自定义
            NSAssert(self.delegate&&[self.delegate respondsToSelector:@selector(transitionAnimator:animateTransitionFromView:duration:)], @"自定义样式必须实现transitionAnimator:animateTransitionFromView:duration:代理方法!");
            [self.delegate transitionAnimator:self animateTransitionFromView:fromView duration:_duration];
            [UIView animateWithDuration:_duration animations:^{
                coverView.backgroundColor = [UIColor clearColor];
            } completion:^(BOOL finished) {
                [transitionContext completeTransition:YES];
            }];
        }else{
            [self setupPopAnimator:fromView context:transitionContext coverView:coverView];
        }
    }
}

- (void)setupPopAnimator:(UIView *)fromView context:(id<UIViewControllerContextTransitioning>)transitionContext coverView:(UIView *)coverView
{
    HGWeakSelf;
    if (_animateStyle == HGTransitionAnimatorFromLeftStyle) {
        [self fromView:fromView context:transitionContext animations:^{
            fromView.x = [self relateViewXToWindow] - fromView.width;
        }];
    }else if (_animateStyle == HGTransitionAnimatorFromRightStyle){
        [self fromView:fromView context:transitionContext animations:^{
            fromView.x=[self relateViewXToWindow] + weakSelf.relateView.width;
        }];
    }else if (_animateStyle == HGTransitionAnimatorFromTopStyle){
        [self fromView:fromView context:transitionContext animations:^{
            fromView.y = [self relateViewXToWindow] - fromView.height;
        }];
    }else if (_animateStyle == HGTransitionAnimatorFromBottomStyle){
        [self fromView:fromView context:transitionContext animations:^{
            fromView.y = [self relateViewYToWindow] + weakSelf.relateView.height + fromView.height;
        }];
    }else if (_animateStyle == HGTransitionAnimatorHiddenStyle){
        [self fromView:fromView context:transitionContext animations:^{
            fromView.alpha=0.0f;
        }];
    }else if (_animateStyle == HGTransitionAnimatorVerticalScaleStyle){
        [self fromView:fromView context:transitionContext animations:^{
            fromView.transform = CGAffineTransformMakeScale(1.0, 0.000001);
        }];
    }else if (_animateStyle == HGTransitionAnimatorHorizontalScaleStyle){
        [self fromView:fromView context:transitionContext animations:^{
            fromView.transform = CGAffineTransformMakeScale(0.000001, 1.0);
        }];
    }else{
        [self fromView:fromView context:transitionContext animations:^{
            fromView.transform = CGAffineTransformMakeScale(0.000001, 0.000001);
        }];
    }
}

- (void)setupPushAnimator:(UIView *)toView context:(id<UIViewControllerContextTransitioning>)transitionContext coverView:(UIView *)coverView
{
    HGWeakSelf;
    if (_animateStyle == HGTransitionAnimatorFromLeftStyle) {
        [self toView:toView context:transitionContext actions:^{
            toView.x = [weakSelf relateViewXToWindow] - toView.width;
        } animations:^{
            toView.x = [weakSelf relateViewXToWindow];
        }];
    }else if (_animateStyle == HGTransitionAnimatorFromTopStyle){
        [self toView:toView context:transitionContext actions:^{
            toView.y = [self relateViewYToWindow]-toView.height;
        } animations:^{
            toView.y = [self relateViewYToWindow];
        }];
    }else if (_animateStyle == HGTransitionAnimatorFromRightStyle){
        [self toView:toView context:transitionContext actions:^{
            toView.x = [self relateViewXToWindow] + [self relateViewWidthToWindow] + toView.width;
        } animations:^{
            toView.x = [self relateViewXToWindow] + self.relateView.width -toView.width;
        }];
    }else if (_animateStyle == HGTransitionAnimatorFromBottomStyle){
        [self toView:toView context:transitionContext actions:^{
            toView.y = CGRectGetMaxY(toView.frame);
        } animations:^{
            toView.y = [self relateViewYToWindow]+self.relateView.height-toView.height;
        }];
    }else if (_animateStyle == HGTransitionAnimatorHiddenStyle){
        [self toView:toView context:transitionContext actions:nil animations:^{
            toView.alpha=1.0f;
        }];
    }else{
        CGPoint anchorPoint = CGPointZero;
        CGAffineTransform CGAffineTransformScale;
        if (_animateStyle == HGTransitionAnimatorVerticalScaleStyle){
            anchorPoint = CGPointMake(0.5, 0);
            CGAffineTransformScale = CGAffineTransformMakeScale(1.0, 0.0);
        }else if (_animateStyle == HGTransitionAnimatorHorizontalScaleStyle){
            anchorPoint = CGPointMake(0, 0.5);
            CGAffineTransformScale = CGAffineTransformMakeScale(0.0, 1.0);
        }else if (_animateStyle == HGTransitionAnimatorCenterStyle){
            anchorPoint = CGPointMake(0.5, 0.5);
            CGAffineTransformScale = CGAffineTransformMakeScale(0.0, 0.0);
        }else if (_animateStyle == HGTransitionAnimatorFocusTopRightStyle){
            anchorPoint = CGPointMake(1, 0);
            CGAffineTransformScale = CGAffineTransformMakeScale(0.0, 0.0);
        }else if (_animateStyle == HGTransitionAnimatorFocusTopCenterStyle){
            anchorPoint = CGPointMake(0.5, 0);
            CGAffineTransformScale = CGAffineTransformMakeScale(0.0, 0.0);
        }else if (_animateStyle == HGTransitionAnimatorFocusTopLeftStyle){
            anchorPoint = CGPointMake(0, 0);
            CGAffineTransformScale = CGAffineTransformMakeScale(0.0, 0.0);
        }
        toView.layer.anchorPoint = anchorPoint;
        toView.transform = CGAffineTransformScale;
        [UIView animateWithDuration:_duration animations:^{
            toView.transform = CGAffineTransformIdentity;
            [self getPresentationControllerCoverView].backgroundColor = weakSelf.backgroundColor;
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:YES];
        }];
    }
}

// 方法抽取
- (void)toView:(UIView *)view context:(id<UIViewControllerContextTransitioning>)transitionContext actions:(void(^)())actions animations:(void (^)(void))animations
{
    HGWeakSelf;
    if (actions){
        view.hidden = YES;
        actions();
        view.hidden = NO;
    }else{
        view.alpha = 0.0f;
    }
    
    __block UIView * coverView = [self getPresentationControllerCoverView];
    void (^endAnimations) (void) = ^ (void){
        if (animations) animations();
        coverView.backgroundColor = weakSelf.backgroundColor;
    };
    [UIView animateWithDuration:weakSelf.duration animations:endAnimations completion:^(BOOL finished){
        [transitionContext completeTransition:YES];
    }];
}

// 方法抽取
- (void)fromView:(UIView *)view context:(id<UIViewControllerContextTransitioning>)transitionContext animations:(void (^)(void))animations
{
    HGWeakSelf;
    __block UIView * coverView = [self getPresentationControllerCoverView];
    void (^completeTransitionBlock) (BOOL) = ^(BOOL finished){
        [transitionContext completeTransition:YES];
    };
    [UIView animateWithDuration:weakSelf.duration animations:^{
        animations();
        coverView.backgroundColor = [UIColor clearColor];
    } completion:completeTransitionBlock];
}

- (CGRect)relateViewToWindow
{
    return  [self.relateView convertRect:self.relateView.bounds toView:[[[UIApplication sharedApplication] windows] firstObject]];
}

- (HGPresentationController *)getPresentationController
{
    return  objc_getAssociatedObject(self, &HGPresentationControllerKey);
}

- (CGFloat)relateViewMaxXToWindow
{
    return  [self relateViewXToWindow]+_relateView.width;
}

- (CGFloat)relateViewMaxYToWindow
{
    return  [self relateViewYToWindow]+_relateView.height;
}

- (CGFloat)relateViewXToWindow
{
    return  [self relateViewToWindow].origin.x;
}

- (CGFloat)relateViewYToWindow
{
    return  [self relateViewToWindow].origin.y;
}

- (CGFloat)relateViewWidthToWindow
{
    return  [self relateViewToWindow].size.width;
}

- (UIView *)getPresentationControllerCoverView
{
    return  [self getPresentationController].coverView;
}

@end

