/*
 * 
 * CallViewController.h
 * demophone
 * 
 * Created by jiri on 4/24/12.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import <UIKit/UIKit.h>
#import "CallDataSource.h"

/**
 @brief CallViewController is the GUI for manipulating calls. There is an UITableView which lists all the calls
 which exist at the moment and below are buttons to do actions on calls (or call groups) which are currently selected
 in the TableView.
 
 The main part of the ViewController is the UITableView which constains all the calls and call groups which exist. 
 @ref demophoneAppDelegate calls the @ref refresh method when the call repository changes, which keeps the table view
 up-to-date.
 
 Action buttons apply either globally (like mute/unmute, speakerphone on/off) or on the call or call group which
 is currently selected. 
 */
// ******************************************************************
@interface CallViewController : UIViewController <UITextFieldDelegate>
// ******************************************************************


@property(nonatomic,strong) CallDataSource * callDataSource;


-(void) refresh;

@end

