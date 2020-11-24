//
//  ViewController.m
//  BWTools
//
//  Created by bairdweng on 2020/11/23.
//

#import "ViewController.h"
#import "BWLabel.h"
#import "BWCache.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initAsyncLabel];
    
    
    // Do any additional setup after loading the view.
}

- (void)initAsyncLabel {
    BWLabel *textLabel = [[BWLabel alloc]initWithFrame:CGRectMake(0, 100, 100, 40)];
    textLabel.backgroundColor = [UIColor redColor];
    textLabel.text = @"我是异步渲染";
    [self.view addSubview:textLabel];
}

- (void)initBWCache {
    BWCache *cache = [BWCache cacheWithName:@"userInfo"];
    
    [cache setObject:@"hello world" forKey:@"hello"];
}

@end
