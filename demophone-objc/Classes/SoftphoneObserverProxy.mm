/*
 *  SoftphoneObserverProxy.cpp
 *  demophone
 *
 *  Created by jiri on 4/1/10.
 *  Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 *
 */

#include "SoftphoneObserverProxy.h"
#include "ali/ali_mac_str_utils.h"

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
using ali::operator""_s;
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

// ******************************************************************
SoftphoneObserverProxy::SoftphoneObserverProxy(NSObject<SoftphoneDelegate> * delegate)
:_delegate(delegate)
// ******************************************************************
{
}

// ******************************************************************
SoftphoneObserverProxy::~SoftphoneObserverProxy()
// ******************************************************************
{
}

#if defined(SOFTPHONE_MULTIPLE_ACCOUNTS)
// ******************************************************************
void SoftphoneObserverProxy::onRegistrationStateChanged(ali::string const& accountId, Registrator::State::Type state)
// ******************************************************************
{
    [_delegate softphoneRegistrationStateChanged:state forAccount:accountId];
}
#else
// ******************************************************************
void SoftphoneObserverProxy::onRegistrationStateChanged(Registrator::State::Type state)
// ******************************************************************
{
    [_delegate softphoneRegistrationStateChanged:state];
}
#endif

// ******************************************************************
void SoftphoneObserverProxy::onNetworkChangeDetected(Softphone::Network::Type network)
// ******************************************************************
{
    // this may be used to reflect the change in GUI, but all reinvites and
    // re-registrations are handled internally by libsoftphone
}

// ******************************************************************
void SoftphoneObserverProxy::onNewEvent(Softphone::EventHistory::Event::Pointer event)
// ******************************************************************
{
    [_delegate softphoneHasIncomingEvent : event];
}

// ******************************************************************
void SoftphoneObserverProxy::onCallStateChanged(Softphone::EventHistory::CallEvent::Pointer call,
                                                Call::State::Type state)
// ******************************************************************
{
    [_delegate softphoneCall:call changedState:state];
}

// ******************************************************************
void SoftphoneObserverProxy::onCallRepositoryChanged()
// ******************************************************************
{
    [_delegate softphoneCallRepositoryChanged];
}

// ******************************************************************
void SoftphoneObserverProxy::onCallHoldStateChanged(Softphone::EventHistory::CallEvent::Pointer call,
                                                    Call::HoldStates const& states)
// ******************************************************************
{
    [_delegate softphoneCall:call changedHoldStates:states];
}

// ******************************************************************
void SoftphoneObserverProxy::onMediaStatusChanged(Softphone::EventHistory::CallEvent::Pointer call,
                                                  Call::MediaStatus const& media)
// ******************************************************************
{
    [_delegate softphoneCall:call mediaStatusChanged:media];
}

// ******************************************************************
void SoftphoneObserverProxy::onAudioRouteChanged(Softphone::AudioRoute::Type route)
// ******************************************************************
{
    [_delegate softphoneAudioRouteChanged:route];
}

// ******************************************************************
void SoftphoneObserverProxy::onTransferOffered(Softphone::EventHistory::CallEvent::Pointer call)
// ******************************************************************
{
	[_delegate softphoneTransferOffered:call];
}

// ******************************************************************
void SoftphoneObserverProxy::onTransferResult(Softphone::EventHistory::CallEvent::Pointer call,
                                              bool success)
// ******************************************************************
{
	[_delegate softphoneTransferResultForCall:call success:success];
}

// ******************************************************************
void SoftphoneObserverProxy::onEventsChanged(Softphone::EventHistory::ChangedEvents const& events,
                                             Softphone::EventHistory::ChangedStreams const& streams)
// ******************************************************************
{
    [_delegate softphoneHasChangedEvents:events streams:streams];
}

// ******************************************************************
ali::filesystem2::path SoftphoneObserverProxy::getRingtoneFile(Softphone::EventHistory::CallEvent::Pointer call)
// ******************************************************************
{
    static int demoCounter = 0;
    
    // cycle between the two ringtones. The real app should probably play
    // some configured ringtone or choose the ringtone based on callee
    
    // if this function returns an empty string, the default ringtone
    // (or callee-specific ringtone, registered via setCalleeCallHandle
    // will be used
    
    NSString *resourcePath  = [[NSBundle mainBundle] resourcePath];

    const ali::filesystem2::path bundlePath { ali::mac::str::from_nsstring(resourcePath)};

    if(demoCounter++ % 2)
    {
        return bundlePath / "dm.wav"_s;
    }else
    {
        return bundlePath / "dd.wav"_s;
    }
}

#if defined(SOFTPHONE_MULTIPLE_ACCOUNTS)

// ******************************************************************
void SoftphoneObserverProxy::onVoicemail(ali::string const& accountId, Voicemail::Record const& voicemail)
// ******************************************************************
{
    [_delegate voicemailAvailable:voicemail forAccount:accountId];
}
#else
// ******************************************************************
void SoftphoneObserverProxy::onVoicemail(Voicemail::Record const& voicemail)
// ******************************************************************
{
    [_delegate voicemailAvailable:voicemail];
}

#endif

// ******************************************************************
void SoftphoneObserverProxy::onSimulatedMicrophoneStopped()
// ******************************************************************
{
    [_delegate onSimulatedMicrophoneStopped];
}

// ******************************************************************
void SoftphoneObserverProxy::onMuteChanged(Softphone::Microphone::Type microphone, bool muted)
// ******************************************************************
{
    [_delegate microphone:microphone muted:muted];
}

// ******************************************************************
void SoftphoneObserverProxy::onBadgeCountChanged()
// ******************************************************************
{
    [_delegate onBadgeCountChanged];
}

#if defined(SOFTPHONE_PUSH)
// ******************************************************************
void SoftphoneObserverProxy::onMissedCalls(ali::array<Softphone::EventHistory::CallEvent::Pointer> const& calls)
// ******************************************************************
{
    [_delegate onMissedCalls:calls];
}
#endif
