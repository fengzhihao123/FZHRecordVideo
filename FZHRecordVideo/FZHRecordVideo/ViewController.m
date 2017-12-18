//
//  ViewController.m
//  FZHRecordVideo
//
//  Created by 1 on 2017/12/18.
//  Copyright © 2017年 fengzhihao. All rights reserved.
//

#import "ViewController.h"
#import "FZHRVViewController.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self presentViewController:[[FZHRVViewController alloc]init] animated:YES completion:nil];
}
@end
