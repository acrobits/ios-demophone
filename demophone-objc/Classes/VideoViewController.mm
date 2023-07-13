/*
 * 
 * VideoViewController.mm
 * demophone
 * 
 * Created by jiri on 4/24/12.
 * Copyright (c) 2022 Acrobits, s.r.o. All rights reserved.
 * 
 */

#import "VideoViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "demophoneAppDelegate.h"
#import "Ali/ali_mac_str_utils.h"

@interface VideoViewController()

@property(nonatomic,weak) IBOutlet UIView *       videoContainer;
@property(nonatomic,weak) IBOutlet UIView *       videoPreviewContainer;
@property(nonatomic,weak) IBOutlet SoftphoneVideoPreview *       videoPreviewView;
@property(nonatomic,weak) IBOutlet UITableView *  cameraTable;

@end

@implementation VideoViewController

{
    ali::array_set<Softphone::Instance::Video::CameraInfo> _cameras;
    
    NSMutableDictionary *           _videoViews;
    ali::string                     _prevActiveGroup;
    BOOL                            _showing;
}

// ******************************************************************
NSNumber * keyFromEvent(Softphone::EventHistory::Event::Pointer  event)
// ******************************************************************
{
    return [NSNumber numberWithLong:reinterpret_cast<long>(event.get())];
}


// ******************************************************************
/// @brief when loaded, the device cameras are enumerated and stored in _cameras array to be used as UITableView data source.
/// Then the video preview (local image) is initialized, positioned and the video layer is set from @ref
/// Softphone::InstanceVideo interface.
- (void) viewDidLoad
// ******************************************************************
{
    [super viewDidLoad];

    if(_cameras.is_empty())
    {
        _cameras = [demophoneAppDelegate theApp].softphone->video()->enumerateCameras();
    }
    
    // make sure linker doesn't throw away the SoftphoneVideoPreview class
    __unused SoftphoneVideoPreview * svp = [[SoftphoneVideoPreview alloc] init];
                
    self.videoPreviewContainer.layer.cornerRadius = 5;
    self.videoPreviewContainer.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.5].CGColor;
    self.videoPreviewContainer.layer.borderWidth = 2;
    self.videoPreviewContainer.layer.masksToBounds = YES;
    self.videoPreviewContainer.backgroundColor = [UIColor blackColor];
    
    self.videoPreviewView.previewArea = self.videoPreviewContainer.frame;
}

// ******************************************************************
/// @brief when shown, we update the screen and start the periodic refresh timer. We also start getting notifications
/// about device orientation changes, to be able to auto-rotate the video views properly
- (void) viewWillAppear:(BOOL)animated
// ******************************************************************
{
    [super viewWillAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onOrientationChanged:) name: UIDeviceOrientationDidChangeNotification object:nil];

    [self refresh];
    
    _showing = YES;
    [self performSelector:@selector(periodicUpdate) withObject:nil afterDelay:0.0f];
}

// ******************************************************************
/// @brief stopt the refresh timer, stop getting orientation changes
- (void)viewDidDisappear:(BOOL)animated
// ******************************************************************
{
    [super viewDidDisappear: animated];
    _showing = NO;

    [[NSNotificationCenter defaultCenter] removeObserver:self name: UIDeviceOrientationDidChangeNotification object: nil];
}

// ******************************************************************
/// @brief during periodic update, we make sure that the video preview reflects exactly what is being sent to the
// remote side. This depends on the device orientation, codec capabilities and selected video resolution.
-(void) periodicUpdate
// ******************************************************************
{
    [self updateVideoPreview];

    if(_showing)
        [self performSelector:@selector(periodicUpdate) withObject:nil afterDelay:1.0f];
}

// ******************************************************************
/** @brief
 actual video frame which is encoded and sent out may be a crop of the actually selected native iOS resolution.
 The code below transforms and crops the preview view to make sure it looks exactly like the video
 displayed at the remote side. @ref Softphone::InstanceVideo supports us by providing  
 @ref Softphone#InstanceVideo#getPreviewLayerCroppingRect and @ref Softphone#InstanceVideo#getPreviewLayerFlipTransform
 */
-(void) updateVideoPreview
// ******************************************************************
{
    if(self.videoPreviewContainer == 0)
        return;     // view not loaded, too early?
    
    [self.videoPreviewView updatePositionAndOrientation];
}

// ******************************************************************
///@brief creates a mosaic of remote video views. Support for video conferencing is quite basic, server-side
///conferencing support will be needed, mixing the video locally is very bandwidth-intensive
-(void) positionVideoViews
// ******************************************************************
{
    if(_videoViews == nil)
        return;
    
    int const count = static_cast<int>([_videoViews count]);
    if(count == 0) return;
    
    int a = ceilf(sqrtf(count));
    
    float dx = self.videoContainer.bounds.size.width / a;
    float dy = self.videoContainer.bounds.size.height / a;
    
    CGRect rect = CGRectMake(0,0,dx,dy);
    
    for(int i=0;i<count;++i)
    {
        const int x = i%a;
        const int y = i/a;
        
        UIView * v = [self.videoContainer.subviews objectAtIndex:i];
        [v setFrame:CGRectOffset(rect, dx*x, dy*y)];
    }
}

// ******************************************************************
///@brief makes sure that video views for the currently active call (or group of calls) are created and visible
-(void) refresh
// ******************************************************************
{
    if(_videoViews == nil)
        _videoViews = [[NSMutableDictionary alloc] init];

    ali::opt_string const activeGroup = [demophoneAppDelegate theApp].softphone->calls()->conferences()->getActive();
    
    if(activeGroup != _prevActiveGroup)
    {
        [_videoViews removeAllObjects];

        for(UIView * v in [self.videoContainer subviews])
        {
            [v removeFromSuperview];
        }

        self.videoPreviewContainer.hidden = YES;
    }
    
    if(activeGroup.is_null())
        return;
    
    ali::array_set<Softphone::EventHistory::CallEvent::Pointer> calls = [demophoneAppDelegate theApp].softphone->calls()->conferences()->getCalls(*activeGroup);
    
    for(auto callEvent: calls)
    {
        const Softphone::StreamAvailability sa = [demophoneAppDelegate theApp].softphone->calls()->isVideoAvailable(callEvent);
        
        UIView * existingView = [_videoViews objectForKey:keyFromEvent(callEvent)];
        
        if(sa.incoming && !existingView)
        {
            SoftphoneVideoView * newView = [[SoftphoneVideoView alloc] initWithCall:callEvent];
            
            newView.delegate = self;
            
            [self.videoContainer addSubview:newView];
            [_videoViews setObject:newView forKey:keyFromEvent(callEvent)];
        }else
        if(!sa.incoming && existingView)
        {
            [_videoViews removeObjectForKey:keyFromEvent(callEvent)];
            [existingView removeFromSuperview];
        }
    }

    // clean up video views whose calls no long exist
    NSEnumerator * enumerator = [_videoViews objectEnumerator];
    
    while(SoftphoneVideoView * existingView = [enumerator nextObject])
    {
        Softphone::EventHistory::CallEvent::Pointer call = existingView.call;
        if(![demophoneAppDelegate theApp].softphone->calls()->isAlive(existingView.call))
        {
            [_videoViews removeObjectForKey:keyFromEvent(existingView.call)];
            [existingView removeFromSuperview];
        }
    }
    
    [self positionVideoViews];

    self.videoPreviewContainer.hidden = ([_videoViews count] == 0);
}

// ******************************************************************
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
// ******************************************************************
{
    return 28.0f;
}

// ******************************************************************
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
// ******************************************************************
{
    return _cameras.size();
}

// ******************************************************************
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
// ******************************************************************
{
	static NSString *MyIdentifier = @"CameraCell";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil)
    {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:MyIdentifier];
	}

    const int idx = static_cast<int>(indexPath.row);
    
	cell.textLabel.text = ali::mac::str::to_nsstring(_cameras.at(idx).name);
    cell.textLabel.font = [UIFont systemFontOfSize:12.0f];
	return cell;	
}

// ******************************************************************
///@brief gets the selected camera from the tableview and sets it as current active camera
-(IBAction) onSetCamera
// ******************************************************************
{
    NSIndexPath * selIndex = [self.cameraTable indexPathForSelectedRow];
    if(selIndex == nil) return;
    
    ali::string const& cameraId = _cameras.at(static_cast<int>(selIndex.row)).id;
    [demophoneAppDelegate theApp].softphone->video()->switchCamera(cameraId);
}

// ******************************************************************
///@brief gets the currently selected desired media (voice-only, voice+video) and sets it to all the calls in
/// currently active call group
-(IBAction) onUpdateDesiredMedia
// ******************************************************************
{
    ali::opt_string activeGroup = [demophoneAppDelegate theApp].softphone->calls()->conferences()->getActive();
    if(activeGroup.is_null())
        return;
    
    ali::array_set<Softphone::EventHistory::CallEvent::Pointer> calls
        = [demophoneAppDelegate theApp].softphone->calls()->conferences()->getCalls(*activeGroup);
    
    for(auto call: calls)
    {
        [demophoneAppDelegate theApp].softphone->calls()->setDesiredMedia(call,
                                                                          [demophoneAppDelegate theApp].currentDesiredMedia);
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
///@brief Make sure the remote video views rotate with the device for comfortable viewing
-(void) onOrientationChanged: (NSNotification*) notification
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];

    CGFloat angle;
    
    switch (deviceOrientation)
    {
        case UIDeviceOrientationPortrait:
            angle = 0.0f;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case UIDeviceOrientationLandscapeLeft:
            angle = M_PI_2;
            break;
        case UIDeviceOrientationLandscapeRight:
            angle = -M_PI_2;
            break;

        default:
            // keep current rotation
            return;
    }
    
    [UIView beginAnimations:nil context:nil];
    _videoContainer.transform = CGAffineTransformMakeRotation(angle);
    [UIView commitAnimations];
    
    [self positionVideoViews];
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
///@brief callbacks from @ref SoftphoneVideoViews are not handled by this example implementation. In case the
///remote side changed the video resolution, this callback would be called and we may want to adjust the videoview frame
-(void) onFrameSizeChanged: (SoftphoneVideoView *) view
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    // video dimensions have changed - we may need to re-arrange the video views
}

@end


