# **Getting Started**

This guide will walk you through the steps required to be able to place calls and receive calls in your app.

## **Adding SoftphoneSwift to your project**

The package is located at https://github.com/acrobits/SoftphoneSwiftPackage-saas.git
Go to your project's' `Package Dependencies` and add dependency on this package.
This package will automatically add the `Softphone` dependencies.

## **Initialization**

In order to initialize `SoftphoneBridge`, you need to use `initialize` method. This method takes xml string as a parameter. This xml contains the license key and the configuration of the SDK.

```swift
let license = """
        <root>
            <saas>
                <identifier>you license key</identifier>
            </saas>
        </root>
        """

// This method is used for initializing an instance of SDK
SoftphoneBridge.initialize(license)        
```

## **Reporting application states**

Correct application state is critical for proper SIP registration handling, Push calls and SDK functionality in general. In order to report application state changes to the SDK, you need to call `update` method on `SoftphoneBridge.instance().state()` instance. This method takes `InstanceStateType` enum as a parameter. This enum contains all possible application states.

```swift
func applicationDidBecomeActive(_ application: UIApplication) {
    let bg = UIApplication.shared.applicationState == .background
    SoftphoneBridge.instance().state().update(bg ? InstanceState_Background : InstanceState_Active)
}

func applicationWillResignActive(_ application: UIApplication) {
    SoftphoneBridge.instance().state().update(InstanceState_Inactive)
}

func applicationDidEnterBackground(_ application: UIApplication) {
    SoftphoneBridge.instance().state().update(InstanceState_Background)
}

func applicationWillEnterForeground(_ application: UIApplication) {
    SoftphoneBridge.instance().state().update(InstanceState_Active)
}
```

## **SIP Account Management**

In order to be able to place calls, you need to set up an account. SIP account are specified in XML format. Please refer to https://doc.acrobits.net/cloudsoftphone/account.html to see all recognized XML nodes and their possible values.

### **Create a SIP account**

To create an account with basic configuration containing username, password and host, do the following:

```swift
let xml = XmlTree(name: "account")
xml?.setAttribute(name: "id", value: "sip")
xml?.setNodeValue(value: "Sip Account", name: "title")
xml?.setNodeValue(value: "1125", name: "username")
xml?.setNodeValue(value: "misscom", name: "password")
xml?.setNodeValue(value: "pbx.acrobits.cz", name: "host")
xml?.setNodeValue(value: "udp", name: "transport")

SoftphoneBridge.instance().registration().saveAccount(xml)
SoftphoneBridge.instance().registration().updateAll()
```

Or if you have an account xml string then you can parse the xml using `XmlTree` class and pass it to `saveAccount` method.

```swift
let sipAccount = """
    <account id=\"sip\">
        <title>Sip Account</title>
        <username>1125</username>
        <password>misscom</password>
        <host>pbx.acrobits.cz</host>
        <transport>udp</transport>
    </account>
"""

let xml = XmlTree.parse(sipAccount)
SoftphoneBridge.instance().registration().saveAccount(xml)
SoftphoneBridge.instance().registration().updateAll()
```

The `id` attribute is required for identifiying an acount. If you don't specify it, the SDK will generate a unique id for the account upon calling `saveAccount` method.

Calling `SoftphoneBridge.instance().registration().saveAccount()` with an XML whose `id` matches ID of an already existing account will cause the account to be replaced.

If you save a new account or an account whose `id` matches ID of an already existing account but has different configuration, it will (re)register asynchronously.

The account settings are stored on disk, therefore you don't have to recreate the account when the application is restarted.

### **Delete a SIP account**

To delete an account, call `deleteAccount` method on `SoftphoneBridge.instance().registration()` instance. This method takes account id as a parameter.

```swift
SoftphoneBridge.instance().registration().deleteAccount("sip")
```


## **Setting up Softphone delegates**

To get the delegates from the SDK, you need to set up `SoftphoneObserverProxyBridge` instance and configuring it to act as a delegate for softphone instance. You should set an observer immediately after initializing the SDK.

```swift
let softphoneObserverProxy = SoftphoneObserverProxyBridge()
softphoneObserverProxy.delegate = self;
SoftphoneBridge.instance().setObserver(softphoneObserverProxy)
```
And implement `SoftphoneDelegateBridge` protocol in your class. This protocol contains all the methods that can be called by the SDK. Some of the methods are optional. 

```swift
// This delegate will be called when the registration state changes
func onRegistrationStateChanged(state: RegistratorStateType, accountId: String!) {

}

// This delegate will be called when a new event arrives (i.e. incoming call/message)
func onNewEvent(_ event: SoftphoneEvent!) {

}

// This delegate will be called when the state of the call changes
func onCallStateChanged(state: CallStateType, call: SoftphoneCallEvent!) {

}

// This delegate will be called when the network change is detected
func onNetworkChangeDetected(_ network: NetworkType) {

}

// This delegate will be called when the hold state of a call is changed
func onHoldStateChanged(states: CallHoldStates!, call: SoftphoneCallEvent!) {

}
```

In order to modify `CXCallUpdate` before it is reported to the system or modify SDK created `CXProviderConfiguration` or create a new one you need to set up `Softphone_Cx_Delegate`

```swift  
Softphone_Cx.instance().delegate = self
```

## **Placing a call**

To place calls, you need to create `SoftphoneCallEvent` with `accountId` and `uri`, associate it with the stream and post it using `post` method of `SoftphoneBridge.instance().events()` instance. The method returns the status of the post as `EventsPostResult` enum.

```swift
func call(number: String) {
    if number.isEmpty {
        return;
    }

    let call = SoftphoneCallEvent.create(withAccountId: "sip", uri: number)
    let stream = SoftphoneEventStream.load(SoftphoneStreamQuery.legacyCallHistoryStreamKey())
    
    call?.setStream(stream)
    call?.transients.set("voiceCall", forKey: "dialAction")

    let result = SoftphoneBridge.instance().events().post(call)

    if result != PostResult_Success {
        print("Failed to post call event")
    }
}
```

## **Manage preferences**

To manage preferences, you need to use `SoftphoneBridge.instance().settings().getPreferences()` instance. It contains read-write as well as read-only properties.

For example to check if the SIP traffic logging is enabled, you can do the following:

```swift
if SoftphoneBridge.instance().settings().getPreferences().trafficLogging {
    print("SIP traffic logging is enabled")
}
```
To enable SIP traffic logging, you can do the following:

```swift
SoftphoneBridge.instance().settings().getPreferences().trafficLogging = true
```


## **Setting up push notifications**

To receive calls, you need to set up push notifications. This is done by calling `setRegistrationId` method on `SoftphoneBridge.instance().notifications().push()` instance. This method is used to pass the token data along with the usage to the SDK.

```swift
func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    SoftphoneBridge.instance().notifications().push().setRegistrationId(pushCredentials.token, usage: PushTokenUsage_IncomingCall)
}
```

## **Handling push notifications for incoming calls**

In order to handle push notifications for incoming calls, you need to pass the push notification payload to the SDK. This is done by calling `handle` method on `SoftphoneBridge.instance().notifications().push()` instance.

```swift
func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
    let xml = Dictionary<AnyHashable, Any>.xmlFromDictionary(payload.dictionaryPayload)
    SoftphoneBridge.instance().notifications().push().handle(xml, usage: PushTokenUsage_IncomingCall, completion: nil)
}
```