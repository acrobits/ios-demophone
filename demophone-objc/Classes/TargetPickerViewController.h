//
//  CallPickerViewController.h
//  demophone
//
//  Created by Adeel Ur Rehman on 17/08/2023.
//

#import <UIKit/UIKit.h>
#import "Softphone/Softphone.h"

@protocol TargetPickerDelegate;

// ******************************************************************
@interface TargetPickerViewController : UIViewController
// ******************************************************************

@property (nonatomic, weak) id<TargetPickerDelegate> pickerDelgate;

- (void)setAttendedTransferTargets:(ali::array<Softphone::EventHistory::CallEvent::Pointer> const&)targets;

@end


// ******************************************************************
@protocol TargetPickerDelegate <NSObject>
// ******************************************************************

- (void)pickerViewController:(TargetPickerViewController *)picker didSelectTarget:(Softphone::EventHistory::CallEvent::Pointer)target;

- (void)pickerViewControllerDidCancel:(TargetPickerViewController *)picker;

@end
