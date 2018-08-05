//
//  TestForCircleCiTests.swift
//  TestForCircleCiTests
//
//  Created by Elkana Orbach on 02/08/2018.
//  Copyright © 2018 Optimove. All rights reserved.
//

import XCTest
import OptimoveSDK

class TestForCircleCiTests: XCTestCase {
    var exp : XCTestExpectation!
    var tester: SdkStateTester!
    
    override func setUp() {
        super.setUp()
        exp = expectation(description: "sdk ready")
        tester = SdkStateTester {
            self.exp.fulfill()
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
       
        
        Optimove.sharedInstance.configure(for: OptimoveTenantInfo(url: "https://sdk-cdn.optimove.net", token: "internal-token", version: "dev.tid.107.all", hasFirebase: false, useFirebaseMessaging: false))
        Optimove.sharedInstance.registerSuccessStateListener(tester)
        wait(for: [exp], timeout: 5.0)
    }
    
    
    
}


class SdkStateTester: OptimoveSuccessStateListener {
    let callback: () -> ()
    init(_ callback:@escaping () -> ()) {
        self.callback = callback
    }
    func optimove(_ optimove: Optimove, didBecomeActiveWithMissingPermissions missingPermissions: [OptimoveDeviceRequirement]) {
        self.callback()
    }
    
    
}
