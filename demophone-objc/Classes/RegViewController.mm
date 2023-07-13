/*
 * 
 * RegViewController.m
 * demophone
 * 
 * Created by jiri on 4/24/12.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import "RegViewController.h"
#import "demophoneAppDelegate.h"

@interface RegViewController()

@property(nonatomic,weak) IBOutlet UILabel * regState;
@property(nonatomic,weak) IBOutlet UITextField * number;

@end

@implementation RegViewController


// ******************************************************************
- (BOOL)textFieldShouldReturn:(UITextField *)textField
// ******************************************************************
{
	[textField resignFirstResponder];

	return YES;
}

// ******************************************************************
- (IBAction) onCall
// ******************************************************************
{
	[[demophoneAppDelegate theApp] callNumber:[self.number text]];
}

// ******************************************************************
-(IBAction) dumpLog
// ******************************************************************
{
	[[demophoneAppDelegate theApp] dumpLog];
}

// ******************************************************************
-(IBAction) onRegister
// ******************************************************************
{
	[[demophoneAppDelegate theApp] registerAccount];
}

// ******************************************************************
-(IBAction) onUnregister
// ******************************************************************
{
	[[demophoneAppDelegate theApp] unregisterAccount];
}

// ******************************************************************
-(IBAction) onSendSMS
// ******************************************************************
{
	[[demophoneAppDelegate theApp] sendExampleSMSTo: [self.number text]];
}

// ******************************************************************
-(IBAction) onSendSMSWithAttachment
// ******************************************************************
{
    [[demophoneAppDelegate theApp] sendExampleSMSWithAttachmentTo: [self.number text]];
}
@end

