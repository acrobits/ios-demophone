import UIKit
import Softphone_Swift

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
class Entry: NSObject
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    var groupId: String?
    var call: SoftphoneCallEvent?
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    convenience init(groupId: String)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        self.init()
        
        self.groupId = groupId
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    convenience init(call: SoftphoneCallEvent)
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        self.init()
        
        self.groupId = nil
        self.call = call
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func isGroup() -> Bool
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        return self.groupId != nil
    }
    
    func getCall() -> SoftphoneCallEvent? {
        if let call = call {
            return call
        } else if let groupId = groupId {
            let calls = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: groupId)
            return calls?.first
        }
        return nil
    }
    
    func getCallSize() -> Int {
        if let groupId = groupId {
            return Int(SoftphoneBridge.instance()?.calls()?.conferences()?.getSize(groupId) ?? 0)
        } else if let _ = call {
            return 1
        }
        return 0
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? Entry else {
            return false
        }
        
        if self.isGroup() {
            return self.groupId == object.groupId
        } else {
            return self.call?.eventId == object.call?.eventId
        }
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
class CallsDataSource: NSObject
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    var entries = [Entry]()
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func updateEntries()
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        entries.removeAll()
        
        if let groups = SoftphoneBridge.instance()?.calls()?.conferences()?.list() {
            for groupId in groups {
                entries.append(Entry(groupId: groupId))
                
                if let calls = SoftphoneBridge.instance()?.calls()?.conferences()?.getCalls(conference: groupId) {
                    for call in calls {
                        entries.append(Entry(call: call));
                    }
                }
            }
        }
    }

    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func entryForIndexPath(indexPath: IndexPath) -> Entry
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        return entries[indexPath.row]
    }
}

//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
extension CallsDataSource: UITableViewDelegate, UITableViewDataSource
//-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
{
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func numberOfSections(in tableView: UITableView) -> Int
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        return 1
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        return entries.count
    }
    
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    //-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EntryCell")!
        
        cell.textLabel?.backgroundColor = .clear
        cell.detailTextLabel?.backgroundColor = .clear
        
        let entry = entries[indexPath.row]
        if entry.isGroup()
        {
            let active = (SoftphoneBridge.instance()?.calls()?.conferences()?.getActive() == entry.groupId)
            let size = SoftphoneBridge.instance()?.calls()?.conferences()?.getSize(entry.groupId)
            
            cell.textLabel?.text = "Group (\(size!) calls)"
            cell.detailTextLabel?.text = active ? "active" : ""
            
            cell.contentView.backgroundColor = active ? UIColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 0.5) : UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.5)
        }
        else
        {
            cell.textLabel?.text = "Call with \(entry.call?.getRemoteUser(index: 0)?.displayName! ?? "")"
            
            var isHeld = false
            if let holdStates = SoftphoneBridge.instance().calls().isHeld(entry.call) {
                isHeld = holdStates.local == CallHoldState_Held
            }
            
            cell.detailTextLabel?.text = "\(CallState.toString((SoftphoneBridge.instance()?.calls()?.getState(entry.call))!) ?? ""), \(isHeld ? "on hold" : "active")"
            
            cell.contentView.backgroundColor = UIColor(white: 1.0, alpha: 1.0)
        }
        
        return cell
    }
}
