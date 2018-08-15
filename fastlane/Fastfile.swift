// This file contains the fastlane.tools configuration
// You can find the documentation at https://docs.fastlane.tools
//
// For a list of all available actions, check out
//
//     https://docs.fastlane.tools/actions
//

import Foundation

class Fastfile: LaneFile {
    func beforeAll() {
        setupCircleCi()
    }
	func ciLane() {
        desc("Build the app")
        runTests(workspace: "TestForCircleCi.xcworkspace", devices: ["iPhone 8"], scheme: "TestForCircleCi")
		// add actions here: https://docs.fastlane.tools/actions
//        syncCodeSigning(gitUrl: "https://github.com/elkanaoptimove/TestForCircleCi.git", appIdentifier: ["com.optimove.sdk.TestForCircleCi"], username: "optimove.develop.mobile@gmail.com")
//        buildIosApp(scheme: "TestForCircleCi")
	}
}
