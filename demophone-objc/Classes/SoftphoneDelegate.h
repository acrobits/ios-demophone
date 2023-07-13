/*
 *  SoftphoneObserver.h
 *  demophone
 *
 *  Created by jiri on 4/1/10.
 *  Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 *
 */

#pragma once

#include "Softphone/Softphone.h"

@protocol SoftphoneDelegate
/**
 @protocol SoftphoneDelegate
 @brief The purpose of this protocol is to handle callbacks defined by @ref Softphone::Observer and @ref Softphone::ObserverEx
 using the Objective C protocol implementation.  The translation is done in @ref SoftphoneObserverProxy.
 
 Demophone implements this interface in @ref demophoneAppDelegate, where are libsoftphone events are received.
 */

/// Called when the registration state of the configured account has changed.
#if defined(SOFTPHONE_MULTIPLE_ACCOUNTS)
-(void) softphoneRegistrationStateChanged:(Registrator::State::Type) state forAccount:(ali::string const&)accountId;
#else
-(void) softphoneRegistrationStateChanged:(Registrator::State::Type) state;
#endif

/// Called when the state of a call identified by callId has changed.
-(void) softphoneCall:(Softphone::EventHistory::CallEvent::Pointer) call changedState:(Call::State::Type) state;

/// Called when there's a change in calls or groups of call membership in groups
-(void) softphoneCallRepositoryChanged;

/// Called when the hold state of a call changes
-(void) softphoneCall:(Softphone::EventHistory::CallEvent::Pointer) call changedHoldStates:(Call::HoldStates const& ) holdStates;

/// Called when the media status for the call has changed, for example when the video stream became available.
-(void) softphoneCall:(Softphone::EventHistory::CallEvent::Pointer) call
   mediaStatusChanged:(Call::MediaStatus const&) media;

/// @brief Called to notify the app that there is an incoming event available.
-(void) softphoneHasIncomingEvent:(Softphone::EventHistory::Event::Pointer) event;

/// @brief Called when the hardware audio route changes, for example when the headset is plugged in or when bluetooth is
/// connected. The receiver should update GUI to reflect the change, for example by updating the speaker button on/off
/// state.
-(void) softphoneAudioRouteChanged:(Softphone::AudioRoute::Type)route;

/// @brief Called to notify GUI that the call with callId received a REFER wifh an offered transfer. The transfer can be then
/// accepted or rejected by calling @ref Softphone::InstanceEx::CallsEx::acceptOfferedTransfer or @ref
/// Softphone::InstanceEx::CallsEx::rejectOfferedTransfer.
-(void) softphoneTransferOffered:(Softphone::EventHistory::CallEvent::Pointer) call;

/// Notifies the received about the result of a previous transfer.
-(void) softphoneTransferResultForCall:(Softphone::EventHistory::CallEvent::Pointer) call success:(bool)success;

/// @brief Called every time after some active events / streams are changed.
-(void) softphoneHasChangedEvents:(Softphone::EventHistory::ChangedEvents) events
                          streams:(Softphone::EventHistory::ChangedStreams) streams;

#if defined(SOFTPHONE_MULTIPLE_ACCOUNTS)
-(void) voicemailAvailable:(Voicemail::Record const&)voicemail forAccount:(ali::string const&) accountId;
#else
-(void) voicemailAvailable:(Voicemail::Record const&)voicemail;
#endif

-(void) onSimulatedMicrophoneStopped;

-(void) microphone:(Softphone::Microphone::Type) microphone muted:(BOOL) muted;

-(void) onBadgeCountChanged;

#if defined(SOFTPHONE_PUSH)
-(void) onMissedCalls:(const ali::array<Softphone::EventHistory::CallEvent::Pointer>) calls;
#endif

@end
