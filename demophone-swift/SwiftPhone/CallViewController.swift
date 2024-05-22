import UIKit
import Softphone_Swift

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
class CallViewController: UIViewController
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    @IBOutlet weak var callsTableView: UITableView!
    
    var callDataSource = CallsDataSource()
    private var attendedTransferTargets: [SoftphoneCallEvent] = []
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    override func viewDidLoad()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        CallRedirectionManager.instance().addTargetChangeDelegate(self)
        self.callsTableView.dataSource = self.callDataSource
        refresh()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    deinit
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        CallRedirectionManager.instance().removeTargetChangeDelegate(self)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        if segue.identifier == "TARGET_PICKER" {
            let picker = segue.destination as! TargetPickerViewController
            picker.delegate = self
            picker.attendedTransferTargets = attendedTransferTargets
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func showCompleteAttTransferAlert()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let alert = UIAlertController(title: "Confirmation",
                                      message: "Do you want to complete the attended transfer?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Complete", style: .default, handler: { _ in
            CallRedirectionManager.instance().performAttendedTransfer()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            CallRedirectionManager.instance().cancelRedirect()
        }))
        alert.show()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func refresh()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        var indexPath = self.callsTableView.indexPathForSelectedRow
        
        self.callDataSource.updateEntries()
        
        self.callsTableView.reloadData()
        
        if indexPath == nil
        {
            indexPath = IndexPath(row: 0, section: 0)
        }
        
        if self.callDataSource.numberOfSections(in: self.callsTableView) > indexPath!.section
            &&
            self.callDataSource.tableView(self.callsTableView, numberOfRowsInSection: indexPath!.section) > indexPath!.row
        {
            self.callsTableView.selectRow(at: indexPath, animated: false, scrollPosition: .middle)
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    private func alertNoCallSelected()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        showAlert(title: "Error", message: "No call selected")
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    private func selectedEntry() -> Entry?
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let indexPath = self.callsTableView.indexPathForSelectedRow else {
            return nil;
        }
        
        return self.callDataSource.entryForIndexPath(indexPath: indexPath)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    private func selectedGroupId() -> String
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let entry = selectedEntry() else {
            return ""
        }
        
        if entry.isGroup() {
            return entry.groupId!
        }
        else {
            return (SoftphoneBridge.instance()?.calls()?.conferences()?.get(entry.call))!
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    private func otherCall(call: SoftphoneCallEvent) -> SoftphoneCallEvent?
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        // find another call. Pick the first call found, the proper GUI should let the
        // user choose the call to transfer to
        
        let groups = SoftphoneBridge.instance()?.calls()?.conferences()?.list() as! [String]
        
        for groupId in groups {
            let calls = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: groupId) as! [SoftphoneCallEvent]
            
            for otherCall in calls {
                if !otherCall.isEqual(to: call) {
                    return otherCall
                }
            }
        }
        
        return nil
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    private func groupNotContaining(call: SoftphoneCallEvent) -> String
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let groupId = SoftphoneBridge.instance()?.calls()?.conferences()?.get(call)
        let allGroups = SoftphoneBridge.instance()?.calls()?.conferences()?.list() as! [String]
        
        for otherGroup in allGroups {
            let otherGroupSize = SoftphoneBridge.instance()?.calls()?.conferences()?.getSize(otherGroup)
            
            if otherGroup == groupId || otherGroupSize == 0 {
                continue
            }
            return otherGroup
        }
        return String()
    }
}

// MARK: - IBActions
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
extension CallViewController
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onDtmfOn(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let view = sender as! UIView
        var key: Character
        
        switch view.tag {
        case 100:
            key = "*"
        default:
            return
        }
        
        AppDelegate.theApp().dtmfOn(key: Int8(bitPattern: key.asciiValue!))
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onDtmfOff(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        AppDelegate.theApp().dtmfOff()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onHold(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let entry = selectedEntry() else {
            alertNoCallSelected()
            return
        }
        
        if entry.isGroup() {
            AppDelegate.theApp().toggleActiveGroup(groupId: entry.groupId!)
        }
        else {
            AppDelegate.theApp().toggleHoldForCall(call: entry.call!)
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onHangup(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let entry = selectedEntry() else {
            alertNoCallSelected()
            return
        }
        
        if entry.isGroup() {
            AppDelegate.theApp().hangupGroup(groupId: entry.groupId!)
        }
        else {
            AppDelegate.theApp().hangup(call: entry.call!)
        }
        
        refresh()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onMute(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        AppDelegate.theApp().toggleMute()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onSpeaker(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        AppDelegate.theApp().toggleSpeaker()
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onTransfer(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let entry = selectedEntry() else {
            alertNoCallSelected()
            return
        }
        
        if entry.isGroup() {
            showAlert(title: "Error", message: "Select a single call")
        }
        else
        {
            if CallRedirectionManager.instance().getRedirectCapabilities(entry.call).canBlindTransfer() {
                CallRedirectionManager.instance().setBlindTransferSource(entry.call)
                self.tabBarController?.selectedIndex = 0
            }
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onAnswer(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let entry = selectedEntry() else {
            alertNoCallSelected()
            return
        }
        
        if entry.isGroup() {
            showAlert(title: "Error", message: "Select a single call")
        }
        else {
            let callState = SoftphoneBridge.instance()?.calls()?.getState(entry.call)
            
            if callState == CallState_IncomingRinging || callState == CallState_IncomingIgnored {
                AppDelegate.theApp().answerIncomingCall(call: entry.call!)
            }
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onAttendedTransfer(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let entry = selectedEntry() else {
            alertNoCallSelected()
            return
        }
        
        guard let call = entry.call, !entry.isGroup() else {
            showAlert(title: "Error", message: "Select a single call")
            return
        }
        
        if let capabilities = CallRedirectionManager.instance().getRedirectCapabilities(call) {
            if capabilities.attendedTransferCapability.isDirect() {
                CallRedirectionManager.instance().performAttendedTransferBetween(source: call, target: capabilities.attendedTransferTargets.first as? SoftphoneCallEvent)
            }
            else if capabilities.attendedTransferCapability.isNewCall() {
                CallRedirectionManager.instance().setAttendedTransferSource(call)
                tabBarController?.selectedIndex = 0
            }
            else if capabilities.attendedTransferCapability.isPickAnotherCall() {
                CallRedirectionManager.instance().setAttendedTransferSource(call)
                attendedTransferTargets = capabilities.attendedTransferTargets as! [SoftphoneCallEvent]
                
                performSegue(withIdentifier: "TARGET_PICKER", sender: nil)
            }
            else {
                showAlert(title: "Invalid Call",
                          message: "You can only transfer a single established phone call")
            }
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onJoin(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let entry = selectedEntry() else {
            alertNoCallSelected()
            return
        }
        
        guard let call = entry.call, !entry.isGroup() else {
            showAlert(title: "Error", message: "Select a single call")
            return
        }
        
        let otherGroup = groupNotContaining(call: call)
        
        if otherGroup.isEmpty
        {
            showAlert(title: "Error", message: "You need two separate calls to join them together")
            return
        }
        
        AppDelegate.theApp().joinCall(call: call, group: otherGroup)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onReject(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let entry = selectedEntry() else {
            alertNoCallSelected()
            return
        }
        
        if entry.isGroup() {
            showAlert(title: "Error", message: "Select a single call")
        }
        else {
            let callState = SoftphoneBridge.instance()?.calls()?.getState(entry.call)
            
            if callState == CallState_IncomingRinging || callState == CallState_IncomingIgnored {
                AppDelegate.theApp().rejectIncomingCall(call: entry.call!)
            }
        }
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    @IBAction func onSplit(_ sender: Any)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let entry = selectedEntry() else {
            alertNoCallSelected()
            return
        }
        
        if entry.isGroup() {
            AppDelegate.theApp().splitGroup(groupId: entry.groupId!)
        }
        else {
            guard let groupId = SoftphoneBridge.instance()?.calls()?.conferences()?.get(entry.call) else {
                return
            }
            
            if (SoftphoneBridge.instance()?.calls()?.conferences()?.getSize(groupId))! > 0 {
                AppDelegate.theApp().splitCall(call: entry.call!)
            }
            else {
                showAlert(title: "Error", message: "The call is aleardy alone in its group")
            }
        }
    }
}

// MARK: - TargetPickerDelegate
extension CallViewController: TargetPickerDelegate
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func pickerViewController(_ picker: TargetPickerViewController, didSelectTarget target: SoftphoneCallEvent)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        CallRedirectionManager.instance().setAttendedTransferTarget(target)
        CallRedirectionManager.instance().performAttendedTransfer()
        
        picker.dismiss(animated: true)
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func pickerViewControllerDidCancel(_ picker: TargetPickerViewController)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        CallRedirectionManager.instance().cancelRedirect()
        picker.dismiss(animated: true)
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
extension CallViewController: CallRedirectionTargetChangeDelegate
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func redirectTargetChanged(call callEvent: SoftphoneCallEvent!, type: CallRedirectType!)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        guard let _ = callEvent else { return }
        
        if type.isAttendedTransfer() {
            showCompleteAttTransferAlert()
        }
    }
}
