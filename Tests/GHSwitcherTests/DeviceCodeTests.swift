import XCTest
@testable import GHSwitcher

final class DeviceCodeTests: XCTestCase {
    func testParsesCodeAndURL() {
        let output = """

        ! One-time code (AB12-CD34) copied to clipboard
        Open this URL to continue in your web browser: https://github.com/login/device
        """
        let device = DeviceCode.parse(output)
        XCTAssertEqual(device?.code, "AB12-CD34")
        XCTAssertEqual(device?.url.absoluteString, "https://github.com/login/device")
    }

    func testParsesEnterpriseURL() {
        let output = "! First copy your one-time code: WXYZ-9876\nOpen this URL: https://ghe.example.com/login/device"
        XCTAssertEqual(DeviceCode.parse(output)?.url.host, "ghe.example.com")
    }

    func testFallsBackToDefaultURL() {
        XCTAssertEqual(DeviceCode.parse("code: AAAA-BBBB")?.url, DeviceCode.defaultURL)
    }

    func testNoCode() {
        XCTAssertNil(DeviceCode.parse("Open this URL to continue in your web browser"))
    }
}
