//
//  FZHRVViewController.h
//  FZHRecordVideo
//
//  Created by 1 on 2017/12/18.
//  Copyright © 2017年 fengzhihao. All rights reserved.
//

#import "ViewController.h"
typedef void(^TakeOperationSureBlock)(id item);
@interface FZHRVViewController : ViewController
@property (copy, nonatomic) TakeOperationSureBlock takeBlock;
@end
