//
//  GateViewScreen.m
//
//  Created by JungWoon Kwon on 2016. 5. 26..
//  Copyright © 2016년 JungWoon Kwon. All rights reserved.
//

#import "GateViewScreen.h"
#import "SysUtils.h"

@interface GateViewScreen ()

@end

@implementation GateViewScreen

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIView *statusBar = [[[UIApplication sharedApplication] valueForKey:@"statusBarWindow"] valueForKey:@"statusBar"];
    
    if ([statusBar respondsToSelector:@selector(setBackgroundColor:)]) {
        statusBar.backgroundColor = [UIColor whiteColor];
    }
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callPicture:) name:@"callPicture" object:nil];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


- (void)callPicture:(NSNotification *)note {
    if ([SysUtils isNull:note] == YES)
        return;

    NSDictionary* dicMenuInfo    = [[note userInfo] objectForKey:@"data_menu"];
    
    if ([SysUtils isNull:dicMenuInfo] == YES)
        return;
    
}


- (BOOL)shouldAutorotate {
    return NO;
}



@end
