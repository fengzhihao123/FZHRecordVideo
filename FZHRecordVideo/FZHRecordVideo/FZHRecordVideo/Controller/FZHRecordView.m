//
//  FZHRecordView.m
//  FZHRecordVideo
//
//  Created by 1 on 2017/12/20.
//  Copyright © 2017年 fengzhihao. All rights reserved.
//

#import "FZHRecordView.h"
static const NSInteger kAnimationOffset = 20;
@interface FZHRecordView()
@property (nonatomic, assign) NSInteger maxRecordNum;
@property (nonatomic, strong) UIView *whiteView;
@end

@implementation FZHRecordView

- (instancetype)initWithFrame:(CGRect)frame withMaxRecordNum:(NSInteger)maxRecordNum {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor lightGrayColor];
        self.layer.cornerRadius = frame.size.width/2;
        self.layer.masksToBounds = YES;
        _maxRecordNum = maxRecordNum;
        [self awakeFromNib];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    _whiteView = [[UIView alloc]initWithFrame:CGRectMake(5, 5, self.frame.size.width - 10, self.frame.size.height - 10)];
    _whiteView.backgroundColor = [UIColor whiteColor];
    _whiteView.layer.cornerRadius = _whiteView.frame.size.width/2;
    _whiteView.layer.masksToBounds = YES;
    [self addSubview:_whiteView];
    [self addLongPressTapGesture];
}

- (void)addLongPressTapGesture {
    UILongPressGestureRecognizer *longPressTap = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longPressAction)];
    longPressTap.minimumPressDuration = 1.0;
    [self addGestureRecognizer:longPressTap];
}

- (void)longPressAction {
    [UIView animateWithDuration:0.1 animations:^{
        self.frame = CGRectMake(self.frame.origin.x - kAnimationOffset/2, self.frame.origin.y - kAnimationOffset/2, self.frame.size.width + kAnimationOffset, self.frame.size.height + kAnimationOffset);
        _whiteView.frame = CGRectMake(_whiteView.frame.origin.x + kAnimationOffset/4, _whiteView.frame.origin.y + kAnimationOffset/4, _whiteView.frame.size.width - kAnimationOffset/2, _whiteView.frame.size.height - kAnimationOffset/2);
    } completion:^(BOOL finished) {
        
    }];
}
@end
