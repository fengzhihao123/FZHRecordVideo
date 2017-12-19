//
//  FZHAVPlayer.h
//  FZHRecordVideo
//
//  Created by 1 on 2017/12/19.
//  Copyright © 2017年 fengzhihao. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FZHAVPlayer : UIView
@property (nonatomic, copy) NSURL *videoUrl;
- (instancetype)initWithFrame:(CGRect)frame withShowInView:(UIView *)bgView url:(NSURL *)url;
- (void)stopPlayer;
@end
