/*
 *  SoftphoneObserverProxy.h
 *  demophone
 *
 *  Created by jiri on 4/1/10.
 *  Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 *
 */
#pragma once

#include "Softphone/Softphone.h"
#include "SoftphoneDelegate.h"
#include "ali/ali_attribute.h"

/*! @class SoftphoneObserverProxy
 @brief A simple class which implements @ref Softphone::Observer and @ref Softphone::ObserverEx C++ interfaces
 and forwards their methods to @ref SoftphoneDelegate interface as Objective-C methods.
 
 The SoftphoneDelegate instance is passed to it in constructor.
 
 */

// ******************************************************************
class SoftphoneObserverProxy : public Softphone::Observer
// ******************************************************************
{
public:
	SoftphoneObserverProxy(NSObject<SoftphoneDelegate> * delegate);
	virtual ~SoftphoneObserverProxy();

    virtual void onNetworkChangeDetected(Softphone::Network::Type network) override;
#if defined(SOFTPHONE_MULTIPLE_ACCOUNTS)
    virtual void onRegistrationStateChanged(ali::string const& accountId, Registrator::State::Type state) override;
#else
	virtual void onRegistrationStateChanged(Registrator::State::Type state) override;
#endif
	virtual void onNewEvent(Softphone::EventHistory::Event::Pointer event) override;
    virtual void onCallStateChanged(Softphone::EventHistory::CallEvent::Pointer call,
                                    Call::State::Type state) override;
    virtual void onCallRepositoryChanged() override;
    
    virtual void onCallHoldStateChanged(Softphone::EventHistory::CallEvent::Pointer call,
                                        Call::HoldStates const& states) override;
    
    virtual void onMediaStatusChanged(Softphone::EventHistory::CallEvent::Pointer call,
                                      Call::MediaStatus const& media) override;
    
	virtual void onAudioRouteChanged(Softphone::AudioRoute::Type route) override;
	
    virtual ali::filesystem2::path getRingtoneFile(Softphone::EventHistory::CallEvent::Pointer call) override;
    
    virtual void onEventsChanged(Softphone::EventHistory::ChangedEvents const& events,
                                 Softphone::EventHistory::ChangedStreams const& streams) override;

	virtual void onTransferOffered(Softphone::EventHistory::CallEvent::Pointer call) override;
    
    virtual void onTransferResult(Softphone::EventHistory::CallEvent::Pointer call,
                                  bool success) override;

    virtual void onSimulatedMicrophoneStopped() override;
    virtual void onMuteChanged(Softphone::Microphone::Type microphone, bool muted) override;
    
    virtual void onBadgeCountChanged() override;
    
#if defined(SOFTPHONE_MULTIPLE_ACCOUNTS)
    virtual void onVoicemail(ali::string const& accountId, Voicemail::Record const& voicemail) override;
#else
    virtual void onVoicemail(Voicemail::Record const& voicemail) override;
#endif
    
#if defined(SOFTPHONE_PUSH)
    virtual void onMissedCalls(ali::array<Softphone::EventHistory::CallEvent::Pointer> const& calls) override;
#endif
    
private:
	NSObject<SoftphoneDelegate> * _delegate;
};
