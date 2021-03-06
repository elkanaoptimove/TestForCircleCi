//
//  Optitrack.swift
//  iOS-SDK
//
//  Created by Mobile Developer Optimove on 04/09/2017.
//  Copyright © 2017 Optimove. All rights reserved.
//

import Foundation
import OptiTrackCore

protocol OptimoveAnalyticsProtocol
{
    func report(event: OptimoveEvent,withConfigs config: OptimoveEventConfig)
    func setScreenEvent(viewControllersIdentifiers:[String],url: URL?)
    func setUserId(_ event:SetUserId)
    func dispatchNow()
}

final class OptiTrack:OptimoveComponent
{
    //MARK: - Internal Variables
    var metaData: OptitrackMetaData!
    var queue = OptimoveQueue()
    var tracker: MatomoTracker!
    let evetReportingQueue      = DispatchQueue(label: "com.optimove.optitrack",
                                                qos: .userInitiated,
                                                attributes: [],
                                                autoreleaseFrequency: .inherit,
                                                target: nil)
    var openApplicationTime     : TimeInterval = Date().timeIntervalSince1970
    private var optimoveCustomizePlugins:[String:String] = [:]
    
    override init(deviceStateMonitor: OptimoveDeviceStateMonitor) {
        super.init(deviceStateMonitor: deviceStateMonitor)
        setupPluginFlags()
    }
    
    //MARK: - Internal Methods
    func injectVisitorAndUserIdToMatomo()
    {
        tracker.visitorId = OptimoveUserDefaults.shared.visitorID!
        if let customerId = CustomerID {
            guard let trackerUserId =  tracker.userId else {
                //Conversion missed
                let event = SetUserId(originalVistorId: OptimoveUserDefaults.shared.initialVisitorId!, userId: customerId, updateVisitorId: OptimoveUserDefaults.shared.visitorID!)
                setUserId(event)
                return
            }
            guard trackerUserId != customerId else {return}
            let ovid = SHA1.hexString(from:trackerUserId)!.replacingOccurrences(of: " ", with: "").prefix(16).description
            let event = SetUserId(originalVistorId: ovid, userId: trackerUserId, updateVisitorId: OptimoveUserDefaults.shared.visitorID!)
            setUserId(event)
        }
    }
    
    override func performInitializationOperations()
    {
        if RunningFlagsIndication.isComponentRunning(.optiTrack) {
            self.injectVisitorAndUserIdToMatomo()
            self.reportPendingEvents()
            self.reportIdfaIfAllowed()
            self.reportUserAgent()
            self.reportOptInOutIfNeeded()
            self.reportAppOpenedIfNeeded()
            self.trackAppOpened()
            self.observeEnterToBackgroundMode()
        }
    }
    private func observeEnterToBackgroundMode()
    {
        NotificationCenter.default.addObserver(forName: .UIApplicationDidEnterBackground,
                                               object: self,
                                               queue: .main) { (notification) in
                                                self.dispatchNow()
        }
    }
}

extension OptiTrack
{
    func report(event: OptimoveEventDecorator,withConfigs config: OptimoveEventConfig)
    {
        if event.isOptimoveCoreEvent {
            evetReportingQueue.async {
                self.handleReport(event: event, withConfigs: config)
            }
        } else {
            guard isEnable else { return }
            evetReportingQueue.async {
                self.handleReport(event: event, withConfigs: config)
            }
        }
    }
    
    private func setupPluginFlags() {
        let pluginFlags = ["fla", "java", "dir", "qt", "realp", "pdf", "wma", "gears"]
        let pluginValues = OptimoveUserDefaults.shared.initialVisitorId!.splitedBy(length: 2).map {Int($0,radix:16)!/2}.map { $0.description}
        for i in 0..<pluginFlags.count {
            let pluginFlag = pluginFlags[i]
            let pluginValue = pluginValues[i]
            self.optimoveCustomizePlugins[pluginFlag] = pluginValue
        }
    }
    
    private func handleReport(event: OptimoveEvent,withConfigs config: OptimoveEventConfig, completionHandler: (() -> Void)? = nil)
    {
        DispatchQueue.main.async {
            var dimensions:[CustomDimension] = [CustomDimension(index: self.metaData.eventIdCustomDimensionId, value: String(config.id)),
                                                CustomDimension(index: self.metaData.eventNameCustomDimensionId, value: event.name)]
            for (name,value) in event.parameters {
                if let optitrackDimensionID = config.parameters[name]?.optiTrackDimensionId {
                    dimensions.append(CustomDimension(index: optitrackDimensionID, value: String(describing: value)))
                }
            }
            let event = Event(tracker: self.tracker, action: [], url: nil, referer: nil, eventCategory: self.metaData.eventCategoryName, eventAction: event.name, eventName: nil, eventValue: nil, customTrackingParameters: self.optimoveCustomizePlugins, dimensions: dimensions, variables: [])
            self.tracker.track(event)
            
            completionHandler?()
        }
    }
    
    func setScreenEvent(viewControllersIdentifiers:[String],url: URL?)
    {
        guard let active = RunningFlagsIndication.componentsRunningStates[.optiTrack] else {return}
        if active && isEnable {
            evetReportingQueue.async {
                OptiLogger.debug("report screen event of \(viewControllersIdentifiers)")
                DispatchQueue.main.async {
                    self.tracker?.track(view: viewControllersIdentifiers, url: url)
                }
            }
        }
    }
    
    func setUserId(_ event:SetUserId)
    {
        OptiLogger.debug("Optitrack set User id for \(event.userId)")
        self.tracker.userId = event.userId
        
        if let eventConfigs = Optimove.sharedInstance.eventWarehouse?.getConfig(ofEvent: event ) {
            let dec = OptimoveEventDecorator(event: event, config: eventConfigs)
            self.report(event: dec, withConfigs: eventConfigs)
        }
    }
    
    
    func dispatchNow()
    {
        if RunningFlagsIndication.isComponentRunning(.optiTrack) {
            OptiLogger.debug("user asked to dispatch")
            tracker.dispatch()
        } else {
            OptiLogger.debug("optitrack component not running")
        }
    }
    
    private func reportIdfaIfAllowed()
    {
        guard metaData.enableAdvertisingIdReport == true else {return}
        self.deviceStateMonitor.getStatus(of: .advertisingId) { (isAllowed) in
            if isAllowed {
                let event = SetAdvertisingId()
                if let config = Optimove.sharedInstance.eventWarehouse?.getConfig(ofEvent: event)  {
                    OptiLogger.debug("report IDFA to optitrack")
                    let dec = OptimoveEventDecorator(event: event, config: config)
                    self.report(event: dec, withConfigs: config)
                } else {
                    OptiLogger.error("could not load IDFA event configs")
                }
            }
        }
    }
    
    private func reportUserAgent()
    {
        let userAgent = Device.evaluateUserAgent()
        OptimoveUserDefaults.shared.userAgent = userAgent
        let event = SetUserAgent(userAgent: userAgent)
        if let config = Optimove.sharedInstance.eventWarehouse?.getConfig(ofEvent: event) {
            OptiLogger.debug("report user agent to optitrack")
            let dec = OptimoveEventDecorator(event: event, config: config)
            report(event: dec, withConfigs: config)
        } else {
            OptiLogger.error("could not load user agent event configs")
        }
    }
    
    private func reportAppOpenedIfNeeded()
    {
        if UIApplication.shared.applicationState != .background {
            self.reportAppOpen()
        }
    }
    
    private func isOptInOutStateChanged(with newState:Bool) -> Bool
    {
        return newState != OptimoveUserDefaults.shared.isOptiTrackOptIn
    }
    
    private func reportOptInOutIfNeeded()
    {
        deviceStateMonitor.getStatus(of: .userNotification) { (granted) in
            if self.isOptInOutStateChanged(with: granted) {
                if granted {
                    let event = OptipushOptIn()
                    guard let config = Optimove.sharedInstance.eventWarehouse?.getConfig(ofEvent: event) else {
                        OptiLogger.error("could not load opt in event configs")
                        return
                    }
                    OptiLogger.debug("report opt in to optitrack")
                    let dec = OptimoveEventDecorator(event: event, config: config)
                    self.report(event: dec, withConfigs: config)
                    OptimoveUserDefaults.shared.isOptiTrackOptIn = true
                } else {
                    let event = OptipushOptOut()
                    guard let config = Optimove.sharedInstance.eventWarehouse?.getConfig(ofEvent: event) else {
                        OptiLogger.error("could not load opt out event configs")
                        return
                    }
                    OptiLogger.debug("report opt out to optitrack")
                    let dec = OptimoveEventDecorator(event: event, config: config)
                    self.report(event: dec, withConfigs: config)
                    OptimoveUserDefaults.shared.isOptiTrackOptIn = false
                }
            }
        }
    }
    
    private func trackAppOpened() {
        NotificationCenter.default.addObserver(forName: Notification.Name.UIApplicationWillEnterForeground,
                                               object: nil,
                                               queue: .main) { (notification) in
                                                if Date().timeIntervalSince1970 - self.openApplicationTime > 1800 {
                                                    self.reportAppOpen()
                                                }
        }
    }
    
    private func isNeedToReportSetUserId() -> Bool
    {
        return OptimoveUserDefaults.shared.isSetUserIdSucceed == false && OptimoveUserDefaults.shared.customerID != nil
    }
}

extension OptiTrack
{
    private func reportPendingEvents()
    {
        if RunningFlagsIndication.isComponentRunning(.optiTrack) {
            if let jsonEvents =  OptimoveFileManager.load(file: "pendingOptimoveEvents.json") {
                let decoder = JSONDecoder()
                let events = try! decoder.decode([Event].self, from: jsonEvents)
                
                //Since all stored events are already matomo events type, no need to do the entire process
                events.forEach { (event) in
                    DispatchQueue.main.async {
                        self.tracker.track(event)
                    }
                }
            }
        }
    }
    
    private func reportAppOpen()
    {
         let event = AppOpenEvent()
        guard let config = Optimove.sharedInstance.eventWarehouse?.getConfig(ofEvent: event) else {
            OptiLogger.error("could not load open app event configs")
            return
        }
        OptiLogger.debug("report app open to optitrack")
        let dec = OptimoveEventDecorator(event: event, config: config)
        report(event: dec, withConfigs: config)
        openApplicationTime = Date().timeIntervalSince1970
    }
}
