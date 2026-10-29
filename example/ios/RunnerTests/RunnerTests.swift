import Flutter
import UIKit
import XCTest

// If your plugin has been explicitly set to "type: .dynamic" in the Package.swift,
// you will need to add your plugin as a dependency of RunnerTests within Xcode.

@testable import external_storage

class RunnerTests: XCTestCase {

  func testGetAllStorageDevicesReturnsDocumentsVolume() {
    let plugin = ExternalStoragePlugin()
    let call = FlutterMethodCall(methodName: "getAllStorageDevices", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      let devices = result as? [[String: Any]]
      XCTAssertEqual(devices?.count, 1)
      XCTAssertEqual(devices?.first?["isPrimary"] as? Bool, true)
      let path = devices?.first?["path"] as? String
      XCTAssertTrue(path?.hasSuffix("/Documents") ?? false)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  func testGetStorageSpaceReportsCapacity() {
    let plugin = ExternalStoragePlugin()
    let call = FlutterMethodCall(
      methodName: "getStorageSpace", arguments: ["path": NSTemporaryDirectory()])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      let space = result as? [String: Any]
      XCTAssertGreaterThan((space?["totalSpace"] as? NSNumber)?.int64Value ?? 0, 0)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}
