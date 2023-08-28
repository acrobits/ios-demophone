//
//  UIViewController+UIViewController_Alert.m
//  demophone
//
//  Created by Adeel Ur Rehman on 17/08/2023.
//

#import "UIViewController+Alert.h"

// ******************************************************************
@implementation UIViewController (Alert)
// ******************************************************************

// ******************************************************************
-(void)showAlertWithTitle:(NSString *)title andMessage:(NSString *)message
// ******************************************************************
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
