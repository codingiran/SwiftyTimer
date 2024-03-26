//
//  SafeTimer.swift
//  SwiftyTimer
//
//  Created by CodingIran on 2024/2/29.
//

import Foundation

/// A safe wrapper around `DispatchSourceTimer` to prevent crashes when releasing a suspended timer.
/// https://developer.apple.com/documentation/dispatch/1452801-dispatch_suspend
/// https://developer.apple.com/documentation/dispatch/1452929-dispatch_resume
/// https://developer.apple.com/documentation/dispatch/1385604-dispatch_source_cancel
open class SafeDispatchSourceTimer {
    /// The type of block to submit to a dispatch source object.
    public typealias DispatchSourceHandler = @convention(block) () -> Void

    /// The dispatch source to be managed.
    private var timer: DispatchSourceTimer

    /// The number of times the timer has been suspended.
    private var suspensionCount: Int

    fileprivate init(timer: DispatchSourceTimer, suspensionCount: Int) {
        self.timer = timer
        self.suspensionCount = suspensionCount
    }

    deinit {
        if self.suspensionCount > 0 {
            /// ⚠️ It is a programmer error to release an object that is currently suspended, because suspension implies that there is still work to be done. Therefore, always balance calls to this method with a corresponding call to `resume()` before disposing of the object. The behavior when releasing the last reference to a dispatch object while it is in a suspended state is undefined.
            self.resume()
        }
    }

    /// Schedules a timer with the specified deadline, repeat interval, and leeway values.
    public func schedule(deadline: DispatchTime, repeating interval: DispatchTimeInterval = .never, leeway: DispatchTimeInterval = .nanoseconds(0)) {
        self.timer.schedule(deadline: deadline, repeating: interval, leeway: leeway)
    }

    /// Sets the event handler work item for the dispatch source.
    public func setEventHandler(qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], handler: SafeDispatchSourceTimer.DispatchSourceHandler?) {
        self.timer.setEventHandler(qos: qos, flags: flags, handler: handler)
    }

    /// Sets the cancellation handler block for the dispatch source with the specified quality-of-service class and work item options.
    public func setCancelHandler(qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], handler: SafeDispatchSourceTimer.DispatchSourceHandler?) {
        self.timer.setCancelHandler(qos: qos, flags: flags, handler: handler)
    }

    /// Sets the registration handler work item for the dispatch source.
    public func setRegistrationHandler(qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], handler: SafeDispatchSourceTimer.DispatchSourceHandler?) {
        self.timer.setRegistrationHandler(qos: qos, flags: flags, handler: handler)
    }

    /// Activates the dispatch object.
    /// Once a dispatch object has been activated, it cannot change its target queue.
    public func activate() {
        self.timer.activate()
    }

    /// Asynchronously cancels the dispatch source, preventing any further invocation of its event handler block.
    public func cancel() {
        self.timer.cancel()
    }

    /// Resumes the invocation of block objects on a dispatch object.
    /// Calling this function decrements the suspension count of a suspended  object.
    public func resume() {
        guard self.suspensionCount > 0 else { return }
        self.timer.resume()
        self.suspensionCount -= 1
    }

    /// Suspends the invocation of block objects on a dispatch object.
    /// Calling this function increments the suspension count of the object
    public func suspend() {
        guard self.suspensionCount == 0 else { return }
        self.timer.suspend()
        self.suspensionCount += 1
    }

    /// Returns the underlying system handle associated with the specified dispatch source.
    public var handle: UInt { self.timer.handle }

    /// Returns the mask of events monitored by the dispatch source.
    public var mask: UInt { self.timer.mask }

    /// Returns pending data for the dispatch source.
    public var data: UInt { self.timer.data }

    /// Returns a Boolean indicating whether the given dispatch source has been canceled.
    public var isCancelled: Bool { self.timer.isCancelled }
}

public extension DispatchSource {
    /// Creates a new dispatch source object for monitoring timer events.
    static func makeSafeTimerSource(flags: DispatchSource.TimerFlags = [], queue: DispatchQueue? = nil) -> SafeDispatchSourceTimer {
        let safeTimer = SafeDispatchSourceTimer(timer: DispatchSource.makeTimerSource(flags: flags, queue: queue), suspensionCount: 1)
        return safeTimer
    }
}
