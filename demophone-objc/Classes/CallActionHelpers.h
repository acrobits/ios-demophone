#import <Foundation/Foundation.h>
#import "Softphone/Softphone.h"

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
@protocol TransferChangedDelegate <NSObject>
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

-(void)onTransferStarted:(Softphone::EventHistory::CallEvent::Pointer)call;
-(void)onTransferCancelled:(Softphone::EventHistory::CallEvent::Pointer)call;

@end


//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
@protocol AttendedTransferChangedDelegate <NSObject>
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

-(void)onAttendedTransferStarted:(Softphone::EventHistory::CallEvent::Pointer)call;
-(void)onAttendedTransferCancelled:(Softphone::EventHistory::CallEvent::Pointer)call;

@end


//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
@protocol ForwardChangedDelegate <NSObject>
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

-(void)onForwardStarted:(Softphone::EventHistory::CallEvent::Pointer)call;
-(void)onForwardCancelled:(Softphone::EventHistory::CallEvent::Pointer)call;

@end


//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
@interface CallActionHelpers : NSObject
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

+ (instancetype)sharedInstance;

-(void)addTransferChangedDelegate:(id<TransferChangedDelegate>)delegate;
-(void)removeTransferChangedDelegate:(id<TransferChangedDelegate>)delegate;

-(void)addAttendedTransferChangedDelegate:(id<AttendedTransferChangedDelegate>)delegate;
-(void)removeAttendedTransferChangedDelegate:(id<AttendedTransferChangedDelegate>)delegate;

-(void)addForwardChangedDelegate:(id<ForwardChangedDelegate>)delegate;
-(void)removeForwardChangedDelegate:(id<ForwardChangedDelegate>)delegate;

-(void)beginTransfer:(Softphone::EventHistory::CallEvent::Pointer)call;
-(void)cancelTransfer:(Softphone::EventHistory::CallEvent::Pointer)call;
-(BOOL)isTransferring:(Softphone::EventHistory::CallEvent::Pointer)call;

-(void)beginAttendedTransfer:(Softphone::EventHistory::CallEvent::Pointer)call;
-(void)cancelAttendedTransfer:(Softphone::EventHistory::CallEvent::Pointer)call;
-(BOOL)isAttendedTransferring:(Softphone::EventHistory::CallEvent::Pointer)call;

-(void)beginForward:(Softphone::EventHistory::CallEvent::Pointer)call;
-(void)cancelForward:(Softphone::EventHistory::CallEvent::Pointer)call;
-(BOOL)isForwarding:(Softphone::EventHistory::CallEvent::Pointer)call;

@end
