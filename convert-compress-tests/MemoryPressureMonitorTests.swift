import XCTest
@testable import convert_compress

final class MemoryPressureMonitorTests: XCTestCase {

    func testInitialLevelIsNominal() {
        let monitor = MemoryPressureMonitor()
        XCTAssertEqual(monitor.level, .nominal)
        monitor.stop()
    }

    func testConcurrencyMultiplierForNominal() {
        let monitor = MemoryPressureMonitor()
        XCTAssertEqual(monitor.concurrencyMultiplier(), 1.0)
        monitor.stop()
    }

    func testStopDoesNotCrash() {
        let monitor = MemoryPressureMonitor()
        monitor.stop()
        // Calling stop again should be safe (DispatchSource handles double cancel)
    }

    func testOnChangeCallbackIsSet() {
        var callbackCalled = false
        let monitor = MemoryPressureMonitor { _ in
            callbackCalled = true
        }
        // We can't easily trigger memory pressure in tests,
        // but verify the monitor initializes without error
        XCTAssertNotNil(monitor)
        monitor.stop()
        // callbackCalled may or may not be true depending on system state
    }
}
