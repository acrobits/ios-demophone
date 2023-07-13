/*
 * 
 * RegViewController.h
 * demophone
 * 
 * Created by jiri on 4/24/12.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import <UIKit/UIKit.h>
/**
 @brief This ViewController gives access to the very basic phone functionality.
 
 
 There are buttons to register and unregister, a label with current registration state, number field, Call and SMS
 buttons which start a call or send an example IM message to the number in the number field, a button which dumps
 the log to console (in case libsoftphone logging is enabled - see @ref Softphone::Instance::Settings, setOptionValue)
 and a switch which controls whether the calls will support video or not.
 
 The ViewController mostly receives the commands from the user and forwards them to @ref demophoneAppDelegate.
 */

// ******************************************************************
@interface RegViewController : UIViewController <UITextFieldDelegate>
// ******************************************************************

@property(nonatomic,weak,readonly) UILabel * regState;
@property(nonatomic,weak,readonly) UITextField * number;


@end

