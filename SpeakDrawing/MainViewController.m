//
//  MainViewController.m
//  SpeakDrawing
//
//  Created by YiBin on 2014/6/11.
//  Copyright (c) 2014年 YB. All rights reserved.
//

#import "MainViewController.h"

@interface MainViewController ()

- (IBAction)touchDownMicrophone:(id)sender;
- (IBAction)touchUpMicrophone:(id)sender;

@end

@implementation MainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // setup background
    self.view.backgroundColor = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"Background1"]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)touchDownMicrophone:(id)sender
{
}

- (IBAction)touchUpMicrophone:(id)sender
{
}

@end
