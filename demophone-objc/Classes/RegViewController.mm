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
#import <Softphone/Call/CallRedirectionManager.h>
#import <Softphone/SdkServiceHolder.h>
#import <Softphone/SdkServiceLocator.h>
#import <ali/ali_mac_str_utils.h>
#import "UIViewController+Alert.h"

@interface RegViewController() <CallRedirectionStateChangeDelegate>

@property(nonatomic,weak) IBOutlet UIButton * callButton;
@property(nonatomic,weak) IBOutlet UILabel * regState;
@property(nonatomic,weak) IBOutlet UITextField * number;
@property(nonatomic,weak) IBOutlet UIButton * videoCallButton;
@property(nonatomic,weak) IBOutlet UILabel * usernameLabel;

@end

@implementation RegViewController

// ******************************************************************
- (void)viewDidLoad
// ******************************************************************
{
    [super viewDidLoad];
    
    [[demophoneAppDelegate theApp] addStateChangeDelegate:self];
    
#ifdef SOFTPHONE_VIDEO
    self.videoCallButton.hidden = NO;
#else
    self.videoCallButton.hidden = YES;
#endif
    
    Softphone::Instance * inst = [demophoneAppDelegate theApp].softphone;
    auto defaultAccount = inst->registration()->getDefaultAccount();
    if (defaultAccount != nullptr) {
        auto username = defaultAccount->getStringProp("username"_s).value | ""_s;
        self.usernameLabel.text = ali::mac::str::to_nsstring(username);
    }
}

// ******************************************************************
- (void)dealloc
// ******************************************************************
{
    [[demophoneAppDelegate theApp] removeStateChangeDelegate:self];
}

// ******************************************************************
- (BOOL)textFieldShouldReturn:(UITextField *)textField
// ******************************************************************
{
	[textField resignFirstResponder];

	return YES;
}

// ******************************************************************
- (void)startCallWithDialAction:(NSString *)dialAction
// ******************************************************************
{
    auto callRedirectionManager = Softphone::SdkServiceLocator::getCallRedirectionManager();
    if (callRedirectionManager->getCurrentRedirectFlow() == Call::Redirection::RedirectType::BlindTransfer()) {
        if (self.number.text.length == 0)
            return;
        
        if (!callRedirectionManager->getRedirectSource().is_null()) {
            [[demophoneAppDelegate theApp] transferCall:callRedirectionManager->getRedirectSource()];
            return;
        }
    }
    
    if ([[demophoneAppDelegate theApp] callNumber:self.number.text dialAction:dialAction]) {
        self.tabBarController.selectedIndex = 1;
    }
}

#pragma mark - CallRedirectionStateChangeDelegate
// ******************************************************************
-(void)redirectStateChanged:(Call::Redirection::Callbacks::StateChangeData const&) data
// ******************************************************************
{
    _callButton.selected = data.type == Call::Redirection::RedirectType::BlindTransfer() && data.newState == Call::Redirection::RedirectState::SourceAssigned();
    
    bool isTransferType = data.type.isTransferType();
    NSString *message = @"";
    
    if (data.newState == Call::Redirection::RedirectState::Succeeded())
    {
        message = isTransferType ? @"Transfer Complete" : @"Forward Complete";
        [self showAlertWithTitle:@"Success" andMessage:message];
    }
    else if (data.newState == Call::Redirection::RedirectState::Failed())
    {
        message = isTransferType ? @"Transfer Failed" : @"Forward Failed";
        [self showAlertWithTitle:@"Error" andMessage:message];
    }
    else if (data.newState == Call::Redirection::RedirectState::Cancelled())
    {
        message = isTransferType ? @"Transfer Cancelled" : @"Forward Cancelled";
        [self showAlertWithTitle:@"Error" andMessage:message];
    }
    else if(data.newState == Call::Redirection::RedirectState::InProgress())
    {
        message = isTransferType ? @"Transfer in Progress" : @"Forward in Progress";
    }
}

#pragma mark - IBActions

// ******************************************************************
- (IBAction) onTapGesture
// ******************************************************************
{
    [self.view endEditing:YES];
}

// ******************************************************************
- (IBAction) onCall
// ******************************************************************
{
    [self startCallWithDialAction:@"voiceCall"];
}

// ******************************************************************
- (IBAction) onVideoCall
// ******************************************************************
{
    [self startCallWithDialAction:@"videoCall"];
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

