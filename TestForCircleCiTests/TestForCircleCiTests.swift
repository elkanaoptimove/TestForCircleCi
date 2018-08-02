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
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        Optimove.sharedInstance.configure(for: OptimoveTenantInfo(url: "https://sdk-cdn.optimove.net", token: "internal-token", version: "dev.tid.107.all", hasFirebase: false, useFirebaseMessaging: false))
    }
    
    
    
}
