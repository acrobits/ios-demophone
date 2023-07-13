/*
 * 
 * VideoViewController.h
 * demophone
 * 
 * Created by jiri on 4/24/12.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */
#ifdef SOFTPHONE_VIDEO

#import <UIKit/UIKit.h>
#import <Softphone/Softphone.h>
#import "Softphone/Video/SoftphoneVideoView.h"
#import "Softphone/Video/SoftphoneVideoPreview.h"
#import "Ali/ali_array_set.h"

/**
 @brief VideoViewController is the GUI for displaying video during call and for camera selection. There is an 
 UITableView which lists all the cameras available on the device with a simple "set camera" button and a view
 for remote video image, with a smaller view for local video image.

 In case the device is not video-capable, the whole view is hidden. The "Update Desired Media" button enabled/disables
 video based on the switch on the first screen, handled by @ref RegViewController.
 
 VideoViewController uses directly @ref Softphone::InstanceVideo API to get the video image, set the cameras etc.
 */

// ******************************************************************
@interface VideoViewController : UIViewController <UITextFieldDelegate
                                                    ,UITableViewDataSource
                                                    ,UITableViewDelegate
#ifdef SOFTPHONE_VIDEO
                                                    ,VideoViewDelegate
#endif
>
// ******************************************************************


-(void) refresh;

@end

#endif
