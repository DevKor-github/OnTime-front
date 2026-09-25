import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testExportRejectsMalformedContainerArgumentsWithoutClaimingSuccess() {
    let plugin = BackupExportPlugin()
    let invalid: [Any?] = [
      nil,
      ["encryptedBytes": "plaintext", "suggestedName": "OnTime.ontimebackup"],
      ["encryptedBytes": FlutterStandardTypedData(bytes: Data()), "suggestedName": "OnTime.ontimebackup"],
      ["encryptedBytes": FlutterStandardTypedData(bytes: Data([1])), "suggestedName": "../OnTime.ontimebackup"],
      ["encryptedBytes": FlutterStandardTypedData(bytes: Data([1])), "suggestedName": "OnTime.txt"],
    ]
    for arguments in invalid {
      var results: [Any?] = []
      plugin.handle(FlutterMethodCall(methodName: "export", arguments: arguments)) { results.append($0) }
      XCTAssertEqual(results.count, 1)
      XCTAssertEqual((results.first as? FlutterError)?.code, "export_failed")
    }
  }

}
