/*
 * 
 * demophoneAppDelegate.m
 * demophone
 * 
 * Created by jiri on 3/28/10.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import "demophoneAppDelegate.h"
#include "ali/ali_mac_str_utils.h"
#include "ali/ali_xml_parser2_interface.h"
#include "ali/ali_objc.h"
#include "Softphone/PreferenceKeys/BasicKey.h"
#include <Softphone/LicenseManagement/LicensingException.h>
#include <Softphone/Call/CallRedirectionManager.h>
#include <Softphone/Badges/BadgeManager.h>
#include <Softphone/SdkServiceHolder.h>

#import "RegViewController.h"
#import "CallViewController.h"
#import "VideoViewController.h"
#import "NSString+CallState.h"
#import "NSString+RegState.h"
#import "NSDictionary+XML.h"

#import <CoreTelephony/CTCallCenter.h>
#import <CoreTelephony/CTCall.h>
#import <CallKit/CallKit.h>

NSString * const LicensingManagementErrorDomain = @"cz.acrobits.LisensingManagementErrorDomain";

typedef NS_ENUM(NSInteger, LicensingManagementErrorCode) {
    LicenseMissing = 1,
    LicenseInvalid,
};

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
using ali::operator""_s;
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
enum ImagePurpose
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    Payload,
    NetworkPreview,
    LocalPreview,
    TemporaryLocalPreview
};

//************************************************************
//************************************************************
//************************************************************


//************************************************************
//************************************************************
//************************************************************
@interface demophoneAppDelegate ()
{
    ali::handle2 badgeCountChangeHandle;
}

@property (nonatomic, strong) NSHashTable<id<CallRedirectionStateChangeDelegate>> *stateChangeDelegates;
@property (nonatomic, strong) NSHashTable<id<CallRedirectionSourceChangeDelegate>> *sourceChangeDelegates;
@property (nonatomic, strong) NSHashTable<id<CallRedirectionTargetChangeDelegate>> *targetChangeDelegates;

@end


@implementation demophoneAppDelegate
{
    PKPushRegistry *_pushRegistry;
    ali::auto_ptr_array_map<ali::string, ali::handle> _pushHandles;

}
//   TODO: fill in the correct account credentials below. For details about all
//   SIP account settings, please refer to the doc folder.

ali::string_literal sip_account{"<account id=\"sip\">"
                    "<title>Sip Account</title>"
					"<username>1275</username>"
					"<password>misscom</password>"
					"<host>pbx.acrobits.cz</host>"
                    "<icm>push</icm>"
                    "<transport>udp</transport>"
					"<codecOrder>0,8,9,3,102</codecOrder>"
					"<codecOrder3G>102,3,9,0,8</codecOrder3G>"
					"</account>"};

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void)applicationDidFinishLaunching:(UIApplication *)application
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    _stateChangeDelegates = [NSHashTable weakObjectsHashTable];
    _sourceChangeDelegates = [NSHashTable weakObjectsHashTable];
    _targetChangeDelegates = [NSHashTable weakObjectsHashTable];
    
    self.tabcon = (UITabBarController *)self.window.rootViewController;
    self.regViewController = [self.tabcon.viewControllers objectAtIndex:0];
    self.callViewController = [self.tabcon.viewControllers objectAtIndex:1];
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"provisioning" ofType:@"xml"];
    
    NSError *error = nil;
    NSString *fileContents = [NSString stringWithContentsOfFile:filePath
                                                         encoding:NSUTF8StringEncoding
                                                            error:&error];
    if (fileContents)
    {
        // initialize the SDK with the SaaS license
        if ([self initialize:fileContents error:&error])
        {
            // obtain the SDK instance
            _softphone = Softphone::instance();
            
            Softphone::Preferences & preferences = _softphone->settings()->getPreferences();
            preferences.trafficLogging.set(true);
            preferences.echoSuppressionEnabled.set(true);
            preferences.volumeBoostPlayback.set(1);
            preferences.volumeBoostMicrophone.set(3);
            preferences.maxNumberOfConcurrentCalls.overrideDefault(3);
            
            _softphoneObserverProxy = new SoftphoneObserverProxy(self);
            _softphone->setObserver(_softphoneObserverProxy);
            
            [self setupCallRedirectionProxies];
            [self setupBadgeCountChange];

            bool const hasCT = NSClassFromString(@"CTCallCenter") != nil;
            
            if(hasCT && !([CXProvider class] && preferences.useCallKit.get()))
            {
                CTCallCenter *cc = [[CTCallCenter alloc] init];
                cc.callEventHandler = ^(CTCall* call)
                {
                    NSLog(@"%@",call.callState);
                    if (cc.currentCalls.count != 0)
                    {
                        [self performSelectorOnMainThread:@selector(putActiveCallOnHold) withObject:nil waitUntilDone:NO];
                    }
                };
            }

            [self refreshCallViews];
            
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            center.delegate = self;
            [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert)
                                  completionHandler:^(BOOL granted, NSError * _Nullable error) {
                                      if (granted)
                                          NSLog(@"\n\nUser Notification authorization granted\n");
                                      else
                                          NSLog(@"\n\nUser Notification authorization granted\n");
                                  }];

            int errorIndex = 0;
            BOOL success = ali::xml::parse(_sipAccount, sip_account, &errorIndex);
            ali_assert(success);
            
            // accounts are saved persistently, in this demo we always create them
            // again. The account ID's are in the XML above
            if(_softphone->registration()->getAccount("sip"_s) != nullptr)
                _softphone->registration()->deleteAccount("sip"_s);
            
            _softphone->registration()->saveAccount(_sipAccount);
            
            // we use a single-account configuration in this example, make sure account
            // with our id "sip" is set as default
            
            _softphone->registration()->updateAll();
            
            [Softphone_iOS sharedInstance].delegate = self;
            [self registerForPushNotifications];
        }
        else {
            switch (error.code) {
                case LicensingManagementErrorCode::LicenseInvalid:
                    NSLog(@"Invalid License");
                    break;
                    
                case LicensingManagementErrorCode::LicenseMissing:
                    NSLog(@"License Missing");
                    break;
                    
                default:
                    break;
            }
        }
    }
    else {
        NSLog(@"Failed to load the content of file");
        return;
    }
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-(void)updateBadge
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    auto badgeManager = Softphone::service<Softphone::BadgeManager>().lock();
    auto count = badgeManager->countForChannelSafe(Softphone::BadgeAddress::Calls);
    unsigned int missedCallCount = count.is_null() ? 0 : *count;
    NSLog(@"Missed Call Count = %d", missedCallCount);
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-(BOOL)initialize:(NSString *)license error:(NSError **) error
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    int errorIndex = 0;
    bool success;
    
    ali::xml::tree licenceXml;
    using namespace LicenseManagement;
    
    success = ali::xml::parse(licenceXml, ali::mac::str::from_nsstring(license) ,&errorIndex);
    ali_assert(success);
    try {
        return Softphone::init(licenceXml);
    } catch (const InvalidLicenseException& e)
    {
        NSString *errorMsg = ali::mac::str::to_nsstring(e.what());
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: errorMsg };
        *error = [NSError errorWithDomain: LicensingManagementErrorDomain code: LicensingManagementErrorCode::LicenseInvalid userInfo:userInfo];
    } catch (const LicenseNotProvidedException& e)
    {
        NSString *errorMsg = ali::mac::str::to_nsstring(e.what());
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: errorMsg };
        *error = [NSError errorWithDomain:LicensingManagementErrorDomain code: LicensingManagementErrorCode::LicenseMissing userInfo:userInfo];
    }
    return NO;
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-(BOOL) isRegistrationInactive
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    Registrator::State::Type curState =
		_softphone->registration()->getRegistrationState("sip"_s);
	
	switch (curState)
	{
		case Registrator::State::Unregistering:
		case Registrator::State::Registered:
			return false;
		default:
			return true;
	}
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
- (void) applicationWillTerminate:(UIApplication *)application
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
+ (demophoneAppDelegate *) theApp
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	return (demophoneAppDelegate*)[[UIApplication sharedApplication] delegate];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) refreshCallViews
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    [self.callViewController refresh];

#ifdef SOFTPHONE_VIDEO
    [self.videoViewController refresh];
#endif
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) applicationWillResignActive:(UIApplication *)application
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) applicationDidBecomeActive:(UIApplication *)application
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) applicationDidEnterBackground:(UIApplication *)application
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void)applicationWillEnterForeground:(UIApplication *)application
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) closeTerminalCalls
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    ali::array_set<Softphone::EventHistory::CallEvent::Pointer> callsToDelete;
    
    ali::array_set<ali::string> allCallGroups = _softphone->calls()->conferences()->list();
    
    for(auto groupId : allCallGroups)
	{
        ali::array_set<Softphone::EventHistory::CallEvent::Pointer> callsInGroup(_softphone->calls()->conferences()->getCalls(groupId));
        
        for(auto callEvent : callsInGroup)
		{
            const Call::State::Type cs = _softphone->calls()->getState(callEvent);
            
            if(Call::State::isTerminal(cs))
            {
                callsToDelete.insert(callEvent);
            }
		}
	}
	
    for(auto callEvent : callsToDelete)
    {
		_softphone->calls()->close(callEvent);
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (BOOL) callNumber:(NSString *) number
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    if([number length] == 0)
        return NO;
    
    Softphone::EventHistory::CallEvent::Pointer newCall = Softphone::EventHistory::CallEvent::create("sip"_s,ali::mac::str::from_nsstring(number));
    
    Softphone::EventHistory::EventStream::Pointer stream = Softphone::EventHistory::EventStream::load(Softphone::EventHistory::StreamQuery::legacyCallHistoryStreamKey);
    
    newCall->setStream(stream);
    
    newCall->transients["dialAction"_s] = "voiceCall"_s;
    
    Softphone::Instance::Events::PostResult::Type const result = _softphone->events()->post(newCall);

    if(result ==  Softphone::Instance::Events::PostResult::Success) {
        return YES;
    }
    
    [self refreshCallViews];
    
    return NO;
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void)startSimulatedMicrophone
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *resourcePath = [bundle resourcePath];
 
    _softphone->calls()->startSimulatedMicrophone(ali::filesystem2::path(ali::mac::str::from_nsstring(resourcePath)) / "eliseb.wav"_s, false);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void)stopSimulatedMicrophone
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    _softphone->calls()->stopSimulatedMicrophone();
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) toggleMute
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    bool const newMute = !_softphone->audio()->isMuted();
    
    _softphone->audio()->setMuted(newMute);

    [self refreshCallViews];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) toggleSpeaker
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    bool const newSpeaker = _softphone->audio()->getCallAudioRoute() != Softphone::AudioRoute::Speaker;
    
    _softphone->audio()->setCallAudioRoute(newSpeaker? Softphone::AudioRoute::Speaker : Softphone::AudioRoute::Receiver);
    [self refreshCallViews];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) unregisterAccount
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    _sipAccount.nodes["icm"_s].data = "off"_s;
    
    NSLog(@"%s", ali::xml::pretty_string_from_tree(_sipAccount).c_str());

	_softphone->registration()->saveAccount(_sipAccount);
    _softphone->registration()->updateAll();
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) registerAccount
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    _sipAccount.nodes["icm"_s].data = "push"_s;

	_softphone->registration()->saveAccount(_sipAccount);
    _softphone->registration()->updateAll();
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) toggleActiveGroup:(ali::string const&) groupId
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    bool const wasActive = (_softphone->calls()->conferences()->getActive() == groupId);
    
    if(wasActive)
        _softphone->calls()->conferences()->setActive(ali::opt_string(nullptr));
    else
        _softphone->calls()->conferences()->setActive(groupId);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) putActiveCallOnHold
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    ali::opt_string activeGroupId = _softphone->calls()->conferences()->getActive();
    if(activeGroupId.is_null())
        return;
    
    ali::array_set<Softphone::EventHistory::CallEvent::Pointer> calls
        = _softphone->calls()->conferences()->getCalls(*activeGroupId);
    
    for(auto callEvent : calls)
    {
        _softphone->calls()->setHeld(callEvent,true);
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) toggleHoldForCall:(Softphone::EventHistory::CallEvent::Pointer) call
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	bool const newHeld = _softphone->calls()->isHeld(call).local != Call::HoldState::Held;
    
	if(newHeld)
	{
		_softphone->registration()->includeNonStandardSipHeader("sip"_s,"INVITE"_s,""_s,"X-HoldCause"_s,"button"_s);
	}else
	{
		_softphone->registration()->excludeNonStandardSipHeader("sip"_s,"INVITE"_s,""_s,"X-HoldCause"_s);
	}
	
	_softphone->calls()->setHeld(call,newHeld);
    
    if(!newHeld)
    {
        if(_softphone->calls()->conferences()->getSize(call) == 1)
        {
            // if we are putting a single call off-hold, make its group active to
            // make the microphone output mix-into the conversation, otherwise it
            // doesn't make much sense
            _softphone->calls()->conferences()->setActive(call);
        }
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) answerIncomingCall:(Softphone::EventHistory::CallEvent::Pointer) call
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    Call::State::Type cs = _softphone->calls()->getState(call);

	if(cs != Call::State::IncomingRinging && cs != Call::State::IncomingIgnored)
		return;
	
	_softphone->calls()->answerIncoming(call,self.currentDesiredMedia);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) rejectIncomingCall:(Softphone::EventHistory::CallEvent::Pointer) call
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    Call::State::Type cs = _softphone->calls()->getState(call);
    
    if(cs != Call::State::IncomingRinging && cs != Call::State::IncomingIgnored)
        return;

    _softphone->calls()->rejectIncomingHere(call);
	_softphone->calls()->close(call);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) hangupCall:(Softphone::EventHistory::CallEvent::Pointer) callEvent
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	_softphone->calls()->close(callEvent);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) hangupGroup:(ali::string const&)groupId
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    ali::array_set<Softphone::EventHistory::CallEvent::Pointer> calls
        = _softphone->calls()->conferences()->getCalls(groupId);

    for(auto callEvent : calls)
    {
        _softphone->calls()->close(callEvent);
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(Call::Statistics) getStatisticsForCall:(Softphone::EventHistory::CallEvent::Pointer) call
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    return _softphone->calls()->getStatistics(call);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) dtmfOnForKey:(char) key
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	_softphone->audio()->dtmfOn(key);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) dtmfOff
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	_softphone->audio()->dtmfOff();	
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) dumpLog
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	ali::string log = _softphone->log()->get();
	_softphone->log()->clear();
	
	printf("========================================================\n");
	printf("%s",log.c_str());
	printf("========================================================\n");
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) sendExampleSMSTo:(NSString *) recipient
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    if([recipient length] == 0)
        return;
    
    const ali::string defaultAccount = "sip"_s;//_softphone->registration()->getAccountId();
    
    Softphone::EventHistory::StreamParty party;
    party.setCurrentTransportUri(ali::mac::str::from_nsstring(recipient));
    party.match(defaultAccount);
    
    Softphone::EventHistory::MessageEvent::Pointer msg = Softphone::EventHistory::MessageEvent::create();
    msg->setBody("TEST MESSAGE"_s);
    msg->addRemoteUser(Softphone::EventHistory::RemoteUser(party));
    msg->setAccount(defaultAccount);
    
    Softphone::Instance::Events::PostResult::Type const result = _softphone->events()->post(msg);
    
    if(result !=  Softphone::Instance::Events::PostResult::Success)
    {
        // report failure
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(Softphone::Instance *) softphone
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	return _softphone;
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) joinCall:(Softphone::EventHistory::CallEvent::Pointer) call toGroup:(const ali::string &)group
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    _softphone->calls()->conferences()->move(call,group);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) splitCall:(Softphone::EventHistory::CallEvent::Pointer) call
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    ali::string groupId = _softphone->calls()->conferences()->get(call);
    _softphone->calls()->conferences()->split(call, true);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) splitGroup:(ali::string const&) groupId
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    ali::array_set<Softphone::EventHistory::CallEvent::Pointer> calls =
        _softphone->calls()->conferences()->getCalls(groupId);

    for(auto call : calls)
    {
        _softphone->calls()->conferences()->split(call, false);
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) transferCall:(Softphone::EventHistory::CallEvent::Pointer) callEvent
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	if([self.regViewController.number.text length] == 0)
	{
		// no number entered
		return;
	}
    
    Softphone::EventHistory::CallEvent::Pointer newCall = Softphone::EventHistory::CallEvent::create("sip"_s,ali::mac::str::from_nsstring(self.regViewController.number.text));
    Softphone::EventHistory::EventStream::Pointer stream = Softphone::EventHistory::EventStream::load(Softphone::EventHistory::StreamQuery::legacyCallHistoryStreamKey);
    newCall->setStream(stream);

    auto callRedirectionManager = Softphone::SdkServiceHolder::get<Call::Redirection::Manager>().lock();
    callRedirectionManager->performBlindTransferToTarget(newCall);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) attendedTransferFromCall:(Softphone::EventHistory::CallEvent::Pointer) call
                               to:(Softphone::EventHistory::CallEvent::Pointer) otherCall
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
	_softphone->calls()->conferences()->attendedTransfer(call,otherCall);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(Call::DesiredMedia) currentDesiredMedia
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    return Call::DesiredMedia::voiceOnly();
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) adjustCxCallUpdate: (CXCallUpdate*) callUpdate forCall: (Softphone::EventHistory::CallEvent::Pointer) call
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    /* a way to reject the call prior to callkit incoming call jumps in
     *
     
    if (_softphone->calls()->getState(call) == Call::State::IncomingRinging)
    {
        if (call->getRemoteUser().getTransportUri().username_from_uri() == "1000"_s)
        {
            _softphone->calls()->rejectIncoming(call);
        }
    }
     
     */
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-(void) registerForPushNotifications
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    Softphone::Preferences const& preferences = _softphone->settings()->getPreferences();

    if (preferences.pushNotificationsUsePushKit.get())
    {
        _pushRegistry = [[PKPushRegistry alloc] initWithQueue: dispatch_get_main_queue()];
        _pushRegistry.desiredPushTypes = [NSSet setWithObject: PKPushTypeVoIP];
        
        _pushRegistry.delegate = self;
    }

    if (!preferences.pushNotificationsUsePushKit.get() || preferences.dualPushes.get())
    {
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    ali::string_const_ref token(static_cast<const char*>(credentials.token.bytes), static_cast<int>(credentials.token.length));
    NSLog(@"Got push credentials for %@\n", credentials.type);
    
    auto const usage = _softphone->settings()->getPreferences().dualPushes.get() ? Softphone::PushToken::Usage::IncomingCall : Softphone::PushToken::Usage::All;
    
    _softphone->notifications()->push()->setRegistrationId(token, usage);
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    NSLog(@"Got voip push");
    ali::auto_ptr<ali::xml::tree> xml = [NSDictionary XMLFromDictionary: payload.dictionaryPayload];
    Softphone::instance()->notifications()->push()->handle(*xml, Softphone::PushToken::Usage::IncomingCall, nullptr);
}


//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
- (void) application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)dev
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    
    ali::string_const_ref token(static_cast<const char*>(dev.bytes), static_cast<int>(dev.length));
    NSLog(@"Got remote-notification token\n");
    
    auto const usage = _softphone->settings()->getPreferences().dualPushes.get() ? Softphone::PushToken::Usage::Other : Softphone::PushToken::Usage::All;

    _softphone->notifications()->push()->setRegistrationId(token, usage);
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
- (void) application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    NSLog(@"Did fail to get remote-notification token\n");
    auto const usage = _softphone->settings()->getPreferences().dualPushes.get() ? Softphone::PushToken::Usage::Other : Softphone::PushToken::Usage::All;
    
    _softphone->notifications()->push()->setRegistrationId({}, usage);
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(nonnull NSDictionary *)userInfo fetchCompletionHandler:(nonnull void (^)(UIBackgroundFetchResult))completionHandler
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    NSLog(@"Got remote-notification push");
    ali::auto_ptr<ali::xml::tree> xml = [NSDictionary XMLFromDictionary: userInfo];
    
    ali::string identifier = ali::mac::str::from_nsstring([NSUUID UUID].UUIDString);
    
    auto handle = Softphone::instance()->notifications()->push()->handle(*xml, Softphone::PushToken::Usage::Other, [self, identifier, completionHandler](auto const& info)
                                                           {
        using namespace Softphone::PushNotificationProcessor;
        switch (info.result)
        {
            case PushNotificationCompletionInfo::Result::NewData:
                completionHandler(UIBackgroundFetchResultNewData);
                break;
            case PushNotificationCompletionInfo::Result::NoData:
                completionHandler(UIBackgroundFetchResultNoData);
                break;
            case  PushNotificationCompletionInfo::Result::Failed:
            default:
                completionHandler(UIBackgroundFetchResultFailed);
                break;
        }
        
        _pushHandles.erase(identifier);

        
    });
    
    _pushHandles.set(identifier, ali::move(handle));
}

#pragma mark - Send Message With Attachment
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void)sendExampleSMSWithAttachmentTo:(NSString *)recipient
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    UIImage *attachmentSource = [UIImage imageNamed:@"MessageAttachment"];
    
    Softphone::EventHistory::EventAttachment attachment(ali::mime::content_type("image/jpeg"_s), Softphone::EventHistory::Attribute::Value{});
    [self storeImage: attachmentSource forAttachment: attachment purpose: Payload];
    [self storeImage: attachmentSource forAttachment: attachment purpose: NetworkPreview];
    [self storeImage: attachmentSource forAttachment: attachment purpose: LocalPreview];
    
    Softphone::Instance::Events::PostResult::Type const result = [self sendMessage:@"TEST MESSAGE WITH ATTACHMENT"
                                                                    withAttachment:&attachment
                                                                       toRecipient:recipient];
    
    if (result != Softphone::Instance::Events::PostResult::Type::Success)
    {
        // report failure
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (Softphone::Instance::Events::PostResult::Type)sendMessage:(NSString *)message withAttachment:(Softphone::EventHistory::EventAttachment *)attachment toRecipient:(NSString *)number
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    if(number.length == 0)
        return Softphone::Instance::Events::PostResult::Type::NoRecipient;
    
    ali::string const& accountId = Softphone::instance()->registration()->getAccountId(Softphone::instance()->registration()->getDefaultAccountIndex());
    if (accountId.is_empty())
        return Softphone::Instance::Events::PostResult::Type::NoAccount;
    
    ali::string uri = ali::mac::str::from_nsstring(number);
    
    Softphone::EventHistory::StreamParty party;
    party.setCurrentTransportUri(uri);
    party.match(accountId);
    
    Softphone::EventHistory::MessageEvent::Pointer messageEvent = Softphone::EventHistory::MessageEvent::create();
    messageEvent->setAccount(accountId);
    messageEvent->addRemoteUser(Softphone::EventHistory::RemoteUser(party));
    
    if (message)
        messageEvent->setBody(ali::mac::str::from_nsstring(message));
    
    if (attachment != nullptr)
        messageEvent->addAttachment(ali::move(*attachment));
    
    return Softphone::instance()->events()->post(messageEvent);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (NSString *)getUniqueId
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MMddyyhhmmss"];
    return [dateFormatter stringFromDate:date];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void)storeImage:(UIImage*)source forAttachment:(Softphone::EventHistory::EventAttachment &)attachment purpose:(ImagePurpose)purpose
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    NSData *data = nil;
    ali::string fileId = "att_"_s + ali::mac::str::from_nsstring([self getUniqueId]);
    
    switch (purpose)
    {
        case Payload:
            data = UIImageJPEGRepresentation(source, .9);
            break;
        case LocalPreview:
        case TemporaryLocalPreview:
        {
            data = UIImageJPEGRepresentation(source, 5);
        }
            break;
        case NetworkPreview:
        {
            data = UIImageJPEGRepresentation(source, 0);
        }
            break;
        default:
            ali_assert(0);
    }
    
    Softphone::EventHistory::Attribute::Value pathAttr;
    
    pathAttr.type = Softphone::EventHistory::Attribute::Expandable | Softphone::EventHistory::Attribute::Attachment;
    if (purpose == Payload)
    {
        pathAttr.value = "%data%"_s;
    } else
    {
        pathAttr.value = "%previews%"_s;
    }
    pathAttr.value += '/';
    pathAttr.value += fileId;
    pathAttr.value += ".jpg"_s;
    
    ali::filesystem2::path const& toPath = Softphone::EventHistory::expandFile(pathAttr);
    
    ali::string const& pathWithoutFileName = toPath.format_platform_string_without_last_segment();
    if (ali::filesystem2::query(pathWithoutFileName).is_not_found())
    {
        ali::filesystem2::folder::create_all(pathWithoutFileName);
    }
    
    [data writeToFile:ali::mac::str::to_nsstring(toPath.format_platform_string()) atomically:YES];
    
    switch (purpose)
    {
        case Payload:
            attachment.updateContentPath(pathAttr);
            break;
        case LocalPreview:
            attachment.updateLocalThumbnailPath(pathAttr);
            break;
        case NetworkPreview:
        case TemporaryLocalPreview:
            attachment.updateNetworkThumbnailPath(pathAttr);
            break;
    }
}

#pragma mark - UNUserNotificationCenterDelegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    completionHandler(UNNotificationPresentationOptionList | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

#pragma mark - Notification
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void)showMissedCallNotification:(Softphone::EventHistory::CallEvent::Pointer)call
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = ali::mac::str::to_nsstring(call->getRemoteUser().getDisplayName());
    content.body = @"Missed Call";
    
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[NSUUID UUID].UUIDString
                                                                          content:content
                                                                          trigger:nil];
    
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Notification request error: %@", error.localizedDescription);
        }
    }];
}

#pragma mark - SoftphoneDelegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) softphoneRegistrationStateChanged:(Registrator::State::Type) state
#if defined(SOFTPHONE_MULTIPLE_ACCOUNTS)
                               forAccount:(const ali::string &)accountId
#endif

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    self.regViewController.regState.text = [NSString stringFromRegState:state];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) softphoneCall:(Softphone::EventHistory::CallEvent::Pointer) call changedState:(Call::State::Type) state
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    [self refreshCallViews];
    [self closeTerminalCalls];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) softphoneCallRepositoryChanged
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    [self refreshCallViews];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) softphoneCall:(Softphone::EventHistory::CallEvent::Pointer) call
   mediaStatusChanged:(Call::MediaStatus const&) media;
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    [self refreshCallViews];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) softphoneCall:(Softphone::EventHistory::CallEvent::Pointer) call changedHoldStates:(Call::HoldStates const& ) holdStates
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    [self refreshCallViews];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) onSimulatedMicrophoneStopped
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    NSLog(@"Simulated microphone STOPPED\n");
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) microphone:(Softphone::Microphone::Type) microphone muted:(BOOL) muted
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    NSLog(@"microphone %s changed to: %@\n",Softphone::Microphone::toString(microphone).data(),
          muted?@"MUTED":@"NOT MUTED");
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) softphoneTransferOffered:(Softphone::EventHistory::CallEvent::Pointer) call
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    // we accept all transfers automatically
    _softphone->calls()->conferences()->acceptOfferedTransfer(call,self.currentDesiredMedia);
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) softphoneTransferResultForCall:(Softphone::EventHistory::CallEvent::Pointer) call
                               success:(bool)success
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) softphoneHasChangedEvents:(Softphone::EventHistory::ChangedEvents) events
                          streams:(Softphone::EventHistory::ChangedStreams) streams
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    [self refreshCallViews];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) voicemailAvailable:(Voicemail::Record const&)voicemail

#if defined(SOFTPHONE_MULTIPLE_ACCOUNTS)
                forAccount:(const ali::string &)accountId
#endif
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    printf("%d new voicemail messages\n",voicemail.getNewMessages());
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) softphoneHasIncomingEvent:(Softphone::EventHistory::Event::Pointer) incomingEvent
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    if(incomingEvent->isCall())
    {
        auto const state = _softphone->calls()->getState(incomingEvent.asCall());
        NSLog(@"state is %s",Call::State::toString(state).data());
        ali::xml::tree const* from = _softphone->calls()->findSipHeader(incomingEvent, "From"_s);
        if(from)
        {
            NSLog(@"display name from FROM: %@",ali::mac::str::to_nsstring(from->attrs["display-name"_s].value));
            NSLog(@"%@",ali::mac::str::to_nsstring(ali::xml::string_from_tree(*from)));
        }
    }

    NSLog(@"display name is %@",ali::mac::str::to_nsstring(incomingEvent->getRemoteUser(0).getDisplayName()));

    switch (incomingEvent->eventType)
    {
        case Softphone::EventHistory::EventType::Call:
        {
            [self closeTerminalCalls];
            [self refreshCallViews];

        }
        break;
        case Softphone::EventHistory::EventType::Message:
        {
            Softphone::EventHistory::MessageEvent::Pointer msg = incomingEvent.asMessage();

            UIAlertView * av = [[UIAlertView alloc] initWithTitle:@"Message"
                                                          message:ali::mac::str::to_nsstring(msg->getBody())
                                                         delegate:nil
                                                cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [av show];
        }

        default:
            // unhandled event type
            break;
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void) softphoneAudioRouteChanged:(Softphone::AudioRoute::Type)route
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    [self refreshCallViews];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void) onMissedCalls:(const ali::array<Softphone::EventHistory::CallEvent::Pointer>) calls
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    // Here you can iterate through the calls and present notification for each call.
    for (auto call : calls) {
        [self showMissedCallNotification:call];
    }
}

#pragma mark - Badge Manager

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void)setupBadgeCountChange
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    auto weakSelf = ali::mac::make_weak(self);
    
    auto badgeManager = Softphone::service<Softphone::BadgeManager>().lock();
    badgeCountChangeHandle =  badgeManager->registerBadgeCountChangeCallback([weakSelf]() {
        auto self = weakSelf.strong();
        [self updateBadge];
    });
}

#pragma mark - Call Redirection Manager

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
- (void)setupCallRedirectionProxies
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    auto weakSelf = ali::mac::make_weak(self);
    
    auto callRedirectionManager = Softphone::SdkServiceHolder::get<Call::Redirection::Manager>().lock();
    callRedirectionManager->notifyStateChange((__bridge void*)self, [weakSelf](Call::Redirection::RedirectType type, Call::Redirection::RedirectState state) {
        auto self = weakSelf.strong();
        [self onRedirectStateChanged:state type:type];
    });
    
    callRedirectionManager->notifySourceChange((__bridge void*)self, [weakSelf](Call::Redirection::RedirectType type, Softphone::EventHistory::CallEvent::Pointer callEvent) {
        auto self = weakSelf.strong();
        [self onRedirectSourceChanged:type call:callEvent];
    });
    
    callRedirectionManager->notifyTargetChange((__bridge void*)self, [weakSelf](Call::Redirection::RedirectType type, Softphone::EventHistory::CallEvent::Pointer callEvent) {
        auto self = weakSelf.strong();
        [self onRedirectTargetChanged:type call:callEvent];
    });
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void)addStateChangeDelegate:(id<CallRedirectionStateChangeDelegate>)delegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    [_stateChangeDelegates addObject:delegate];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void)addSourceChangeDelegate:(id<CallRedirectionSourceChangeDelegate>)delegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    [_sourceChangeDelegates addObject:delegate];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void)addTargetChangeDelegate:(id<CallRedirectionTargetChangeDelegate>)delegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    [_targetChangeDelegates addObject:delegate];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-(void)removeStateChangeDelegate:(id<CallRedirectionStateChangeDelegate>)delegate;
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    [_stateChangeDelegates removeObject:delegate];
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-(void)removeSourceChangeDelegate:(id<CallRedirectionSourceChangeDelegate>)delegate
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    [_sourceChangeDelegates removeObject:delegate];
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
-(void)removeTargetChangeDelegate:(id<CallRedirectionTargetChangeDelegate>)delegate
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    [_targetChangeDelegates removeObject:delegate];
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
- (void)onRedirectStateChanged:(Call::Redirection::RedirectState)state type:(Call::Redirection::RedirectType)type
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    for (id<CallRedirectionStateChangeDelegate> delegate in _stateChangeDelegates.allObjects)
    {
        if ([delegate respondsToSelector:@selector(redirectStateChanged:type:)])
        {
            [delegate redirectStateChanged:state type:type];
        }
    }
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
- (void)onRedirectSourceChanged:(Call::Redirection::RedirectType)type call:(Softphone::EventHistory::CallEvent::Pointer)callEvent
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    for (id<CallRedirectionSourceChangeDelegate> delegate in _sourceChangeDelegates.allObjects)
    {
        if ([delegate respondsToSelector:@selector(redirectSourceChanged:type:)])
        {
            [delegate redirectSourceChanged:callEvent type:type];
        }
    }
}

//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
- (void)onRedirectTargetChanged:(Call::Redirection::RedirectType)type call:(Softphone::EventHistory::CallEvent::Pointer)callEvent
//*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-
{
    for (id<CallRedirectionTargetChangeDelegate> delegate in _targetChangeDelegates.allObjects)
    {
        if ([delegate respondsToSelector:@selector(redirectTargetChanged:type:)])
        {
            [delegate redirectTargetChanged:callEvent type:type];
        }
    }
}

@end
