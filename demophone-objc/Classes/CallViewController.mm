/*
 * 
 * CallViewController.mm
 * demophone
 * 
 * Created by jiri on 4/24/12.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import "CallViewController.h"
#import "demophoneAppDelegate.h"
#import "Ali/ali_mac_str_utils.h"
#import <Softphone/Call/CallRedirectionManager.h>
#import <Softphone/SdkServiceHolder.h>
#import "TargetPickerViewController.h"
#import "UIViewController+Alert.h"

@interface CallViewController() <TargetPickerDelegate, CallRedirectionTargetChangeDelegate>
{
    ali::array<Softphone::EventHistory::CallEvent::Pointer> _attendedTransferTargets;
}

@property(nonatomic,weak) IBOutlet UILabel * remoteHold;
@property(nonatomic,weak) IBOutlet UILabel * stats;
@property(nonatomic,weak) IBOutlet UILabel * callId;
@property(nonatomic,weak) IBOutlet UITableView * callTable;

@end

@implementation CallViewController

// ******************************************************************
- (void) viewDidLoad
// ******************************************************************
{
    [super viewDidLoad];
    [[demophoneAppDelegate theApp] addTargetChangeDelegate:self];

    self.callDataSource = [[CallDataSource alloc] init];
    self.callTable.dataSource = self.callDataSource;
    
    [self refresh];
}

// ******************************************************************
- (void)dealloc
// ******************************************************************
{
    [[demophoneAppDelegate theApp] removeTargetChangeDelegate:self];
}

// ******************************************************************
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
// ******************************************************************
{
    if ([segue.identifier isEqualToString:@"TARGET_PICKER"])
    {
        TargetPickerViewController *picker = (TargetPickerViewController *)segue.destinationViewController;
        picker.pickerDelgate = self;
        [picker setAttendedTransferTargets:_attendedTransferTargets];
    }
}

// ******************************************************************
/// @brief refreshes the @ref CallDataSource to get the most up-to-date image of call repository and reloads the
/// UITableView. It tries to select the same item as before refresh (if it still exists).
- (void) refresh
// ******************************************************************
{
    NSIndexPath * path = [self.callTable indexPathForSelectedRow];
    
    [self.callDataSource updateEntries];
    
    [self.callTable reloadData];
    
    // try to re-select the same path
    if(path == nil)
        path = [NSIndexPath indexPathForRow:0 inSection:0];
                
    if([self.callDataSource numberOfSectionsInTableView:self.callTable] > [path section]
 &&
       [self.callDataSource tableView:self.callTable numberOfRowsInSection:[path section]] > [path row])
    {
        [self.callTable selectRowAtIndexPath:path
                                    animated:NO 
                              scrollPosition:UITableViewScrollPositionMiddle];
    }
}

// ******************************************************************
-(Entry *) selectedEntry
// ******************************************************************
{
    NSIndexPath * path = [self.callTable indexPathForSelectedRow];
    if(!path) return nil;

    return [self.callDataSource entryForIndexPath:path];
}

// ******************************************************************
-(ali::string) groupNotContainingCall:(Softphone::EventHistory::CallEvent::Pointer) call
// ******************************************************************
{
    const ali::string groupId = [demophoneAppDelegate theApp].softphone->calls()->conferences()->get(call);
    const ali::array_set<ali::string> allGroups = [demophoneAppDelegate theApp].softphone->calls()->conferences()->list();

    for(auto otherGroup : allGroups)
    {
        if(otherGroup == groupId
           || [demophoneAppDelegate theApp].softphone->calls()->conferences()->getSize(otherGroup) == 0)
            continue;

        return otherGroup;
    }

    return ali::string();
}

// ******************************************************************
-(Softphone::EventHistory::CallEvent::Pointer) otherCall:(Softphone::EventHistory::CallEvent::Pointer) call
// ******************************************************************
{
    // find another call. Pick the first call found, the proper GUI should let the
	// user choose the call to transfer to
    const ali::array_set<ali::string> allGroups = [demophoneAppDelegate theApp].softphone->calls()->conferences()->list();

    for(auto groupId : allGroups)
	{
        ali::array_set<Softphone::EventHistory::CallEvent::Pointer> calls =
            [demophoneAppDelegate theApp].softphone->calls()->conferences()->getCalls(groupId);
        
        for(auto otherCall : calls)
		{
			if(otherCall != call)
			{
                return otherCall;
			}
		}
	}
    
    return nullptr;
}

// ******************************************************************
-(ali::string) selectedGroupId
// ******************************************************************
{
    Entry * e = [self selectedEntry];
    if(e == nullptr)
        return ali::string();
    
    if(e.isGroup)
        return ali::mac::str::from_nsstring(e.group);
    else
        return [demophoneAppDelegate theApp].softphone->calls()->conferences()->get(e.call);
}

// ******************************************************************
-(void) alertNoCallSelected
// ******************************************************************
{
    [self showAlertWithTitle:@"Error"
                  andMessage:@"No call selected"];
}

// ******************************************************************
- (void)showCompleteAttTransferAlert
// ******************************************************************
{
    auto callRedirectionManager = Softphone::SdkServiceHolder::get<Call::Redirection::Manager>();
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Confirmation"
                                                                   message:@"Do you want to complete the attended transfer?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *completeAction = [UIAlertAction actionWithTitle:@"Complete"
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
        callRedirectionManager->performAttendedTransfer();
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {
        callRedirectionManager->cancelRedirect();
    }];
    
    [alert addAction:completeAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// ******************************************************************
/// @brief Hangs up a call if call is selected, or all calls in a group if
/// group is selected.
-(IBAction) onHangup
// ******************************************************************
{
    Entry * e = [self selectedEntry];
    if(!e)
    {
        [self alertNoCallSelected];
        return;
    }
    
    if(e.isGroup)
    {
        [[demophoneAppDelegate theApp] hangupGroup: ali::mac::str::from_nsstring(e.group)];
    }else
    {
        [[demophoneAppDelegate theApp] hangupCall:e.call];
    }
    [self refresh];
}

// ******************************************************************
/// Toggles the microphone mute. Applies globally.
-(IBAction) onMute
// ******************************************************************
{
//    [[demophoneAppDelegate theApp] playSimulatedMic];
	[[demophoneAppDelegate theApp] toggleMute];
}

// ******************************************************************
/// Toggles speakerphone mode. Applies globally.
-(IBAction) onSpeaker
// ******************************************************************
{
	[[demophoneAppDelegate theApp] toggleSpeaker];
}

// ******************************************************************
/// @brief Toggles to hold state of the selected call, or the active
/// state of the whole group.
///
/// In case a group is selected and it contains more than one call, the calls in the group are not put on hold.
/// Instead, the local audio (microphone+playback) is disconnected from the group, but the media mixing contimues, so
/// the two or more remaining participants can still hear each other.
-(IBAction) onHold
// ******************************************************************
{
    Entry * e = [self selectedEntry];
    if(!e)
    {
        [self alertNoCallSelected];
        return;
    }
    
    if(e.isGroup)
    {
        [[demophoneAppDelegate theApp] toggleActiveGroup:ali::mac::str::from_nsstring(e.group)];
    }else
    {
        [[demophoneAppDelegate theApp] toggleHoldForCall:e.call];
    }
} 


// ******************************************************************
/// @brief Joins the selected call to the first group which is found
///
/// In case a group is selected, or in case no group which doesn't contain the selected call is found, an error
/// message is shown.
-(IBAction) onJoin
// ******************************************************************
{
    Entry * e = [self selectedEntry];
    if(!e)
    {
        [self alertNoCallSelected];
        return;
    }
    
    if(e.isGroup)
    {
        [self showAlertWithTitle:@"Error"
                      andMessage:@"Select a single call"];
		return;
    }
    
    const ali::string otherGroup = [self groupNotContainingCall:e.call];
	
	if(otherGroup.is_empty())
	{
        [self showAlertWithTitle:@"Error"
                      andMessage:@"You need two separate calls to join them together"];
		return;
	}

	[[demophoneAppDelegate theApp] joinCall:e.call toGroup:otherGroup];
}

// ******************************************************************
/// @brief Depending on whether group or call is selected, it calls the @ref demophoneAppDelegate#splitGroup: or
/// @ref demophoneAppDelegate#splitCall: method. Shows an error message if called with a group which already has only
/// one participant.
-(IBAction) onSplit
// ******************************************************************
{
    Entry * e = [self selectedEntry];
    if(!e)
    {
        [self alertNoCallSelected];
        return;
    }
    
    if(e.isGroup)
    {
        [[demophoneAppDelegate theApp] splitGroup:ali::mac::str::from_nsstring(e.group)];
    }else
    {
        const ali::string groupId = [demophoneAppDelegate theApp].softphone->calls()->conferences()->get(e.call);
        
        if([demophoneAppDelegate theApp].softphone->calls()->conferences()->getSize(groupId) > 1)
        {
            [[demophoneAppDelegate theApp] splitCall:e.call];
        }
        else
        {
            [self showAlertWithTitle:@"Error"
                          andMessage:@"The call is already alone in its group"];
        }
    }
}

// ******************************************************************
/// @brief makes sure that a single call is selected and calls @ref demophoneAppDelegate#transferCall:
-(IBAction) onXfr
// ******************************************************************
{
    Entry * e = [self selectedEntry];
    if(!e)
    {
        [self alertNoCallSelected];
        return;
    }
    
    if(e.isGroup)
    {
        [self showAlertWithTitle:@"Error"
                      andMessage:@"Select a single call"];
    }
    else
    {
        auto callRedirectionManager = Softphone::SdkServiceHolder::get<Call::Redirection::Manager>();
        if (callRedirectionManager->canInitiateRedirect() && callRedirectionManager->getRedirectCapabilities(e.call).canBlindTransfer())
        {
            callRedirectionManager->setBlindTransferSource(e.call);
            self.tabBarController.selectedIndex = 0;
        }
    }
}

// ******************************************************************
/// @brief makes sure that a single call is selected, then finds some other (random) call id which is different and
/// calls @ref <demophoneAppDelegate::attendedTransferFromCall:to:>
/// Proper GUI should have some picker where the user picks the call to transfer to.
-(IBAction) onAttendedXfr
// ******************************************************************
{
    Entry * e = [self selectedEntry];
    if(!e)
    {
        [self alertNoCallSelected];
        return;
    }
    
    if(e.isGroup)
    {
        [self showAlertWithTitle:@"Error"
                      andMessage:@"Select a single call"];
		return;
    }
  
    auto redirectManager = Softphone::SdkServiceHolder::get<Call::Redirection::Manager>();
    Call::Redirection::RedirectCapabilities redirectCapabilities = redirectManager->getRedirectCapabilities(e.call);
    
    if (redirectCapabilities.attendedTransferCapability == Call::Redirection::AttendedTransferCapability::Direct())
    {
        //transfer to the suggested target immediately
        redirectManager->performAttendedTransferBetween(e.call, redirectCapabilities.attendedTransferTargets[0]);
    }
    else if (redirectCapabilities.attendedTransferCapability == Call::Redirection::AttendedTransferCapability::NewCall())
    {
        // initiate the attended transfer flow
        redirectManager->setAttendedTransferSource(e.call);
        self.tabBarController.selectedIndex = 0;
    }
    else if (redirectCapabilities.attendedTransferCapability == Call::Redirection::AttendedTransferCapability::PickAnotherCall())
    {
        redirectManager->setAttendedTransferSource(e.call);
        _attendedTransferTargets = redirectCapabilities.attendedTransferTargets;
        
        [self performSegueWithIdentifier:@"TARGET_PICKER" sender:nil];
    }
    else
    {
        [self showAlertWithTitle:@"Invalid Call"
                      andMessage:@"You can only transfer a single established phone call"];
    }
}

// ******************************************************************
/// @brief called in response to touchDown event. Starts the DTMF tone by calling
/// @ref demophoneAppDelegate#dtmfOnForKey:
-(IBAction) dtmfOn:(id)sender
// ******************************************************************
{
	UIView * v = (UIView *)sender;
	char key;
	switch([v tag])
	{
		case 100: key = '*';break;
		default: return;
	}
	
	[[demophoneAppDelegate theApp] dtmfOnForKey:key];
}

// ******************************************************************
/// @brief called in response to touchUp or touchCanceled event. Stops the DTMF tone by calling
/// @ref demophoneAppDelegate#dtmfOff
-(IBAction) dtmfOff:(id)sender
// ******************************************************************
{
	[[demophoneAppDelegate theApp] dtmfOff];	
}

// ******************************************************************
/// @brief Makes sure the selected item is a single call in states IncomingRingong or IncomingIgnored and calls
/// @ref demophoneAppDelegate#answerIncomingCall: to answer the call.
-(IBAction) onAnswer
// ******************************************************************
{
    Entry * e = [self selectedEntry];
    if(!e)
    {
        [self alertNoCallSelected];
        return;
    }
    
    if(e.isGroup)
    {
        [self showAlertWithTitle:@"Error"
                      andMessage:@"Select a single call"];
		return;
    }
    
    Call::State::Type const state = 
        [demophoneAppDelegate theApp].softphone->calls()->getState(e.call);
    
    if( state == Call::State::IncomingRinging 
       || state == Call::State::IncomingIgnored)
    {
        [[demophoneAppDelegate theApp] answerIncomingCall:e.call];
    }
}

// ******************************************************************
/// @brief Makes sure the selected item is a single call in states IncomingRingong or IncomingIgnored and calls
/// @ref demophoneAppDelegate#rejectIncomingCall: to reject the call.
-(IBAction) onReject
// ******************************************************************
{
    Entry * e = [self selectedEntry];
    if(!e)
    {
        [self alertNoCallSelected];
        return;
    }
    
    if(e.isGroup)
    {
        [self showAlertWithTitle:@"Error"
                      andMessage:@"Select a single call"];
		return;
    }
    
    Call::State::Type const state = 
    [demophoneAppDelegate theApp].softphone->calls()->getState(e.call);
    
    if( state == Call::State::IncomingRinging 
       || state == Call::State::IncomingIgnored)
    {
        [[demophoneAppDelegate theApp] rejectIncomingCall:e.call];
    }
}

// ******************************************************************
- (void)pickerViewController:(TargetPickerViewController *)picker didSelectTarget:(Softphone::EventHistory::CallEvent::Pointer)target
// ******************************************************************
{
    auto callRedirectionManager = Softphone::SdkServiceHolder::get<Call::Redirection::Manager>();
    callRedirectionManager->setAttendedTransferTarget(target);
    callRedirectionManager->performAttendedTransfer();
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// ******************************************************************
- (void)pickerViewControllerDidCancel:(TargetPickerViewController *)picker
// ******************************************************************
{
    auto callRedirectionManager = Softphone::SdkServiceHolder::get<Call::Redirection::Manager>();
    callRedirectionManager->cancelRedirect();
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - CallRedirectionTargetChangeDelegate
// ******************************************************************
-(void)redirectTargetChanged:(Softphone::EventHistory::CallEvent::Pointer)callEvent type:(Call::Redirection::RedirectType)type
// ******************************************************************
{
    if (!callEvent.is_null() && type == Call::Redirection::RedirectType::AttendedTransfer()) {
        [self showCompleteAttTransferAlert];
    }
}

@end


