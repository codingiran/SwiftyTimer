//
//  Timer.swift
//  SwiftyTimer
//
//  Created by CodingIran on 2023/6/26.
//

import Foundation
import Locking

open class Timer: Equatable {
    /// State of the timer
    ///
    /// - paused: idle (never started yet or paused)
    /// - running: timer is running
    /// - executing: the observers are being executed
    /// - finished: timer lifetime is finished
    public enum State: Equatable, CustomStringConvertible {
        case paused
        case running
        case executing
        case finished

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.paused, .paused),
                 (.running, .running),
                 (.executing, .executing),
                 (.finished, .finished):
                return true
            default:
                return false
            }
        }

        /// Return `true` if timer is currently resumed, including when the observers are being executed.
        public var isResumed: Bool {
            guard self == .running || self == .executing else { return false }
            return true
        }

        /// Return `true` if timer is currently suspended, including timer lifetime is finished.
        public var isSuspended: Bool {
            guard self == .paused || self == .finished else { return false }
            return true
        }

        /// Return `true` if the observers are being executed.
        public var isExecuting: Bool {
            guard case .executing = self else { return false }
            return true
        }

        /// Is timer finished its lifetime?
        /// It return always `false` for infinite timers.
        /// It return `true` for `.once` mode timer after the first fire,
        /// and when `.remainingIterations` is zero for `.finite` mode timers
        public var isFinished: Bool {
            guard case .finished = self else { return false }
            return true
        }

        /// State description
        public var description: String {
            switch self {
            case .paused: return "idle/paused"
            case .finished: return "finished"
            case .running: return "running"
            case .executing: return "executing"
            }
        }
    }

    /// Mode of the timer.
    ///
    /// - infinite: infinite number of repeats.
    /// - finite: finite number of repeats.
    /// - once: single repeat.
    public enum Mode {
        case infinite
        case finite(_: Int)
        case once

        /// Is timer a repeating timer?
        var isRepeating: Bool {
            switch self {
            case .once: return false
            default: return true
            }
        }

        /// Number of repeats, if applicable. Otherwise `nil`
        public var countIterations: Int? {
            switch self {
            case .finite(let counts): return counts
            default: return nil
            }
        }

        /// Is infinite timer
        public var isInfinite: Bool {
            guard case .infinite = self else {
                return false
            }
            return true
        }
    }

    /// Handler typealias
    public typealias Observer = (Timer) -> Void

    /// Token assigned to the observer
    public typealias ObserverToken = UInt64

    /// Current state of the timer
    public private(set) var state = Protected(State.paused) {
        didSet {
            self.onStateChanged?(self, self.state.value)
        }
    }

    /// Callback called to intercept state's change of the timer
    public var onStateChanged: ((_ timer: Timer, _ state: State) -> Void)?

    /// List of the observer of the timer
    private var observers = [ObserverToken: Observer]()

    /// Next token of the timer
    private var nextObserverID: UInt64 = 0

    /// Internal GCD Timer
    private var timer: DispatchSourceTimer?

    /// Is timer a repeat timer
    public private(set) var mode: Mode

    /// Number of remaining repeats count
    public private(set) var remainingIterations: Int?

    /// Interval of the timer
    private var interval: Interval

    /// Accuracy of the timer
    private var tolerance: DispatchTimeInterval

    /// Dispatch queue parent of the timer
    private var queue: DispatchQueue?

    /// Initialize a new timer.
    ///
    /// - Parameters:
    ///   - interval: interval of the timer
    ///   - mode: mode of the timer
    ///   - tolerance: tolerance of the timer, 0 is default.
    ///   - queue: queue in which the timer should be executed; if `nil` a new queue is created automatically.
    ///   - observer: observer
    public init(interval: Interval, mode: Mode = .infinite, tolerance: DispatchTimeInterval = .nanoseconds(0), queue: DispatchQueue? = nil, observer: @escaping Observer) {
        self.mode = mode
        self.interval = interval
        self.tolerance = tolerance
        self.remainingIterations = mode.countIterations
        self.queue = (queue ?? DispatchQueue(label: "com.swiftytimer.timer.queue"))
        self.timer = self.configureTimer()
        self.observe(observer)
    }

    /// Add new a listener to the timer.
    ///
    /// - Parameter callback: callback to call for fire events.
    /// - Returns: token used to remove the handler
    @discardableResult
    public func observe(_ observer: @escaping Observer) -> ObserverToken {
        var (new, overflow) = self.nextObserverID.addingReportingOverflow(1)
        if overflow { // you need to add an incredible number of offset...sure you can't
            self.nextObserverID = 0
            new = 0
        }
        self.nextObserverID = new
        self.observers[new] = observer
        return new
    }

    /// Remove an observer of the timer.
    ///
    /// - Parameter id: id of the observer to remove
    public func remove(observer identifier: ObserverToken) {
        self.observers.removeValue(forKey: identifier)
    }

    /// Remove all observers of the timer.
    ///
    /// - Parameter stopTimer: `true` to also stop timer by calling `suspend()` function.
    public func removeAllObservers(thenStop stopTimer: Bool = false) {
        self.observers.removeAll()

        if stopTimer {
            self.suspend(to: .paused)
        }
    }

    /// Configure a new timer session.
    ///
    /// - Returns: dispatch timer
    private func configureTimer() -> DispatchSourceTimer {
        let associatedQueue = (queue ?? DispatchQueue(label: "com.swiftytimer.timer.\(UUID().uuidString)"))
        let timer = DispatchSource.makeTimerSource(queue: associatedQueue)
        let repeatInterval = self.interval.value
        let deadline: DispatchTime = (DispatchTime.now() + repeatInterval)
        if self.mode.isRepeating {
            timer.schedule(deadline: deadline, repeating: repeatInterval, leeway: self.tolerance)
        } else {
            timer.schedule(deadline: deadline, leeway: self.tolerance)
        }

        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.timeFired()
        }
        return timer
    }

    /// Destroy current timer
    private func destroyTimer() {
        guard let timer = self.timer else {
            return
        }
        timer.setEventHandler {}
        timer.cancel()
        self.resume()
    }

    /// Create and schedule a timer that will call `handler` once after the specified time.
    ///
    /// - Parameters:
    ///   - interval: interval delay for single fire
    ///   - queue: destination queue, if `nil` a new `DispatchQueue` is created automatically.
    ///   - observer: handler to call when timer fires.
    /// - Returns: timer instance
    @discardableResult
    public class func once(after interval: Interval, tolerance: DispatchTimeInterval = .nanoseconds(0), queue: DispatchQueue? = nil, _ observer: @escaping Observer) -> Timer {
        let timer = Timer(interval: interval, mode: .once, tolerance: tolerance, queue: queue, observer: observer)
        timer.start()
        return timer
    }

    /// Create and schedule a timer that will fire every interval optionally by limiting the number of fires.
    ///
    /// - Parameters:
    ///   - interval: interval of fire
    ///   - count: a non `nil` and > 0  value to limit the number of fire, `nil` to set it as infinite.
    ///   - queue: destination queue, if `nil` a new `DispatchQueue` is created automatically.
    ///   - handler: handler to call on fire
    /// - Returns: timer
    @discardableResult
    public class func every(_ interval: Interval, count: Int? = nil, tolerance: DispatchTimeInterval = .nanoseconds(0), queue: DispatchQueue? = nil, _ handler: @escaping Observer) -> Timer {
        let mode: Mode = (count != nil ? .finite(count!) : .infinite)
        let timer = Timer(interval: interval, mode: mode, tolerance: tolerance, queue: queue, observer: handler)
        timer.start()
        return timer
    }

    /// Force fire.
    ///
    /// - Parameter pause: `true` to pause after fire, `false` to continue the regular firing schedule.
    public func fire(andPause pause: Bool = false) {
        self.timeFired()
        if pause {
            self.suspend(to: .paused)
        }
    }

    /// Reset the state of the timer, optionally changing the fire interval.
    ///
    /// - Parameters:
    ///   - interval: new fire interval; pass `nil` to keep the latest interval set.
    ///   - restart: `true` to automatically restart the timer, `false` to keep it stopped after configuration.
    public func reset(_ interval: Interval?, restart: Bool = true) {
        // suspend timer
        self.suspend(to: .paused)

        // For finite counter we want to also reset the repeat count
        if case .finite(let count) = self.mode {
            self.remainingIterations = count
        }

        // Create a new instance of timer configured
        if let newInterval = interval {
            self.interval = newInterval
        } // update interval
        self.destroyTimer()
        self.timer = self.configureTimer()
        self.state.value = .paused

        if restart {
            self.resume()
        }
    }

    /// Start timer. If timer is already running it does nothing.
    @discardableResult
    public func start() -> Bool {
        let state = self.state.value

        guard !state.isResumed else {
            return false
        }

        // If timer has not finished its lifetime we want simply
        // restart it from the current state.
        guard state.isFinished else {
            self.resume()
            return true
        }

        // Otherwise we need to reset the state based upon the mode
        // and start it again.
        self.reset(nil, restart: true)
        return true
    }

    /// Called when timer is fired
    private func timeFired() {
        self.state.value = .executing

        if case .finite = self.mode {
            self.remainingIterations! -= 1
        }

        // dispatch to observers
        self.observers.values.forEach { $0(self) }

        // manage lifetime
        switch self.mode {
        case .once:
            // once timer's lifetime is finished after the first fire
            // you can reset it by calling `reset()` function.
            self.suspend(to: .finished)
        case .finite:
            // for finite intervals we decrement the left iterations count...
            if self.remainingIterations! == 0 {
                // ...if left count is zero we just pause the timer and stop
                self.suspend(to: .finished)
            }
        case .infinite:
            // infinite timer does nothing special on the state machine
            break
        }
    }

    /// resume timer with lock
    private func resume() {
        self.state.sync { state in
            guard !state.isResumed else {
                return
            }
            self.timer?.resume()
            state = .running
        }
    }

    /// suspend timer with lock
    private func suspend(to newState: State) {
        self.state.sync { state in
            guard !state.isSuspended else {
                return
            }
            self.timer?.suspend()
            state = newState
        }
    }

    deinit {
        self.observers.removeAll()
        self.destroyTimer()
    }

    public static func == (lhs: Timer, rhs: Timer) -> Bool {
        return lhs === rhs
    }
}
