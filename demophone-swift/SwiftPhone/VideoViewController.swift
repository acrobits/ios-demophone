
import UIKit

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
class VideoViewController: UIViewController
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    @IBOutlet weak var videoContainer: UIView!
    @IBOutlet weak var videoPreviewContainer: UIView!
    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var cameraTable: UITableView!

    private var previousActiveGroup: String = ""
    private var showing: Bool = false
    private var cameras: [VideoCameraInfo] = []
    private var videoViews: Dictionary<String, VideoView>?
    
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// @brief when loaded, the device cameras are enumerated and stored in _cameras array to be used as UITableView data source.
    /// Then the video preview (local image) is initialized, positioned and the video layer is set from @ref
    /// Softphone::InstanceVideo interface.
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    override func viewDidLoad()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if cameras.count == 0
        {
            cameras = SoftphoneBridge.instance()?.video()?.enumerateCameras() as! [VideoCameraInfo]
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// @brief when shown, we update the screen and start the periodic refresh timer. We also start getting notifications
    /// about device orientation changes, to be able to auto-rotate the video views properly
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    override func viewWillAppear(_ animated: Bool)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onOrientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        refresh()
        showing = true
        
        self.perform(#selector(periodicUpdate), with: nil, afterDelay: 0.0)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// @brief stop the refresh timer, stop getting orientation changes
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    override func viewDidDisappear(_ animated: Bool)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        super.viewDidDisappear(animated)
        
        showing = false
        
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /// @brief during periodic update, we make sure that the video preview reflects exactly what is being sent to the
    // remote side. This depends on the device orientation, codec capabilities and selected video resolution.
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @objc private func periodicUpdate()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        updateVideoPreview()
        
        if showing
        {
            self.perform(#selector(periodicUpdate), with: nil, afterDelay: 1.0)
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    /** @brief
     actual video frame which is encoded and sent out may be a crop of the actually selected native iOS resolution.
     The code below transforms and crops the preview view to make sure it looks exactly like the video
     displayed at the remote side. @ref Softphone::InstanceVideo supports us by providing
     @ref Softphone#InstanceVideo#getPreviewLayerCroppingRect and @ref Softphone#InstanceVideo#getPreviewLayerFlipTransform
     */
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    private func updateVideoPreview()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    ///@brief creates a mosaic of remote video views. Support for video conferencing is quite basic, server-side
    ///conferencing support will be needed, mixing the video locally is very bandwidth-intensive
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    private func positionVideoViews()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let v = videoViews else {
            return;
        }
        
        if v.count == 0 {
            return;
        }
        
        let a = ceilf(sqrtf(Float(v.count)))
        
        let dx = self.videoContainer.bounds.size.width/CGFloat(a)
        let dy = self.videoContainer.bounds.size.height/CGFloat(a)
        
        let rect = CGRect(x: 0, y: 0, width: dx, height: dy)
        
        for i in 0..<v.count
        {
            let x = i%Int(a)
            let y = i/Int(a)
            
            let v = self.videoContainer.subviews[i]
            v.frame = rect.offsetBy(dx: (dx*CGFloat(x)), dy: (dy*CGFloat(y)))
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    ///@brief makes sure that video views for the currently active call (or group of calls) are created and visible
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func refresh()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if videoViews == nil
        {
            videoViews = Dictionary<String, VideoView>()
        }
        
        let activeGroup = SoftphoneBridge.instance()?.calls()?.conferences()?.getActive()
        
        if activeGroup != previousActiveGroup
        {
            for v in self.videoContainer.subviews
            {
                v.removeFromSuperview()
            }
//            self.videoPreviewView.isHidden = true
        }
        
        if activeGroup!.isEmpty
        {
            return
        }
        
        let calls = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: activeGroup) as! [SoftphoneCallEvent]
        
        for call in calls
        {
            let key = String(call.eventId)
            
            let sa = SoftphoneBridge.instance()?.calls()?.isVideoAvailable(call)
            let existingView = videoViews?[key]
            
            if sa!.incoming && existingView == nil
            {
                guard let newView = VideoView(call: call) else {
                    continue
                }
                
                self.videoContainer.addSubview(newView)
                videoViews?.updateValue(newView, forKey: key)
            }
            else if !sa!.incoming && existingView != nil
            {
                videoViews?.removeValue(forKey: key)
                existingView!.removeFromSuperview()
            }
        }
        
        for (key, view) in videoViews!
        {
            if !(SoftphoneBridge.instance()?.calls()?.isAlive(view.call) ?? true)
            {
                videoViews?.removeValue(forKey: key)
                view.removeFromSuperview()
            }
        }
        
        positionVideoViews()
        
//        self.videoPreviewContainer.isHidden = videoViews?.count == 0
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    ///@brief Make sure the remote video views rotate with the device for comfortable viewing
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @objc private func onOrientationChanged()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let deviceOrientation = UIDevice.current.orientation
        
        var angle: Float = 0.0
        
        switch deviceOrientation
        {
        case .portrait:
            angle = 0.0
            
        case .portraitUpsideDown:
            angle = Float.pi
            
        case .landscapeLeft:
            angle = Float.pi/2
            
        case .landscapeRight:
            angle = -Float.pi/2
            
        default:
            return
        }
        
        UIView.animate(withDuration: 0.5) {
            self.videoContainer.transform = CGAffineTransform(rotationAngle: CGFloat(angle))
        }

        positionVideoViews()
    }
    
    // MARK: - IBActions -

    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    ///@brief gets the selected camera from the tableview and sets it as current active camera
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onSetCamera(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let selectedIndexPath = self.cameraTable.indexPathForSelectedRow else
        {
            return
        }
        
        let cameraId = cameras[selectedIndexPath.row].id
        SoftphoneBridge.instance()?.video()?.switchCamera(id: cameraId)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    ///@brief gets the currently selected desired media (voice-only, voice+video) and sets it to all the calls in
    /// currently active call group
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onUpdateDesiredMedia(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let activeGroup = SoftphoneBridge.instance()?.calls()?.conferences()?.getActive() else
        {
            return
        }
        
        let calls = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: activeGroup) as! [SoftphoneCallEvent]
        
        for call in calls
        {
            SoftphoneBridge.instance()?.calls()?.setDesiredMedia(call, desiredMedia: AppDelegate.theApp().currentDesiredMedia())
        }
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
extension VideoViewController: UITableViewDelegate, UITableViewDataSource
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        return cameras.count
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CameraCell")!
        
        cell.textLabel?.text = cameras[indexPath.row].name
        cell.textLabel?.font = UIFont.systemFont(ofSize: 12.0)
        
        return cell
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        return 28.0
    }
}
