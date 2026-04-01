import Foundation
import Dispatch

/// Monitors system memory pressure and provides recommendations for concurrency adjustment.
final class MemoryPressureMonitor: @unchecked Sendable {
    enum PressureLevel: Sendable {
        case nominal
        case warning
        case critical
    }

    private let source: DispatchSourceMemoryPressure
    private let lock = NSLock()
    private var _level: PressureLevel = .nominal
    private var onChange: ((PressureLevel) -> Void)?

    var level: PressureLevel {
        lock.lock()
        defer { lock.unlock() }
        return _level
    }

    init(queue: DispatchQueue = .global(qos: .utility), onChange: ((PressureLevel) -> Void)? = nil) {
        self.onChange = onChange
        self.source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical, .normal], queue: queue)
        self.source.setEventHandler { [weak self] in
            guard let self else { return }
            let event = self.source.data
            let newLevel: PressureLevel
            if event.contains(.critical) {
                newLevel = .critical
            } else if event.contains(.warning) {
                newLevel = .warning
            } else {
                newLevel = .nominal
            }
            self.lock.lock()
            self._level = newLevel
            self.lock.unlock()
            self.onChange?(newLevel)
        }
        self.source.resume()
    }

    /// Returns a multiplier (0.0–1.0) to apply to the base concurrency.
    func concurrencyMultiplier() -> Double {
        switch level {
        case .nominal:  return 1.0
        case .warning:  return 0.5
        case .critical: return 0.25
        }
    }

    func stop() {
        source.cancel()
    }

    deinit {
        source.cancel()
    }
}
