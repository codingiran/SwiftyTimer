//
//  Throttler.swift
//  SwiftyTimer
//
//  Created by CodingIran on 2023/6/26.
//

import Foundation

open class Throttler {
    /// Callback type
    public typealias Callback = () -> Void

    /// Behaviour mode of the throttler.
    ///
    /// - fixed: When execution is available, dispatcher will try to keep fire on a fixed rate.
    /// - deferred: When execution is provided the dispatcher will always delay invocation.
    public enum Mode {
        case fixed
        case deferred
    }

    /// In case you want the first invocation the be invoken immediately
    private(set) var immediateFire: Bool

    /// Operation mode
    private(set) var mode: Throttler.Mode = .fixed

    /// Queue in which the throotle will work.
    private var queue: DispatchQueue

    /// Callback to call
    private var callback: Callback?

    /// Last scheduled callback job
    private var callbackJob = DispatchWorkItem(block: {})

    /// Previous scheduled time
    private var previousScheduled: DispatchTime?

    /// Last executed time
    private var lastExecutionTime: DispatchTime?

    /// Need to delay before perform
    private var waitingForPerform: Bool = false

    /// Throotle interval
    public private(set) var throttle: DispatchTimeInterval

    /// Initialize a new throttler with given time interval.
    ///
    /// - Parameters:
    ///   - time: throttler interval.
    ///   - queue: execution queue; if `nil` default's background queue is used.
    ///   - mode: operation mode, if not specified `fixed` is used instead.
    ///   - fireNow: immediate fire first execution of the throttle.
    ///   - callback: callback to throttle.
    public init(time: SwiftyTimer.Interval, queue: DispatchQueue? = nil, mode: Mode = .fixed, immediateFire: Bool = false, _ callback: Callback? = nil) {
        self.throttle = time.value
        self.queue = (queue ?? DispatchQueue.global(qos: .background))
        self.mode = mode
        self.immediateFire = immediateFire
        self.callback = callback
    }

    /// Execute callback in throotle mode.
    public func call() {
        self.callbackJob.cancel()
        self.callbackJob = DispatchWorkItem { [weak self] in
            if let selfStrong = self {
                selfStrong.lastExecutionTime = .now()
                selfStrong.waitingForPerform = false
            }
            self?.callback?()
        }

        let (now, dispatchTime) = self.evaluateDispatchTime()
        self.previousScheduled = now
        self.waitingForPerform = true

        self.queue.asyncAfter(deadline: dispatchTime, execute: self.callbackJob)
    }

    /// Evaluate the dispatch time of the job since now based upon the operation mode set.
    ///
    /// - Returns: a tuple with now interval and evaluated interval based upon the current mode.
    private func evaluateDispatchTime() -> (now: DispatchTime, evaluated: DispatchTime) {
        let now: DispatchTime = .now()

        switch self.mode {
        case .fixed:

            // Case A.
            // If the time since last execution plus the throotle interval is > direct execution
            // then execute the callback at delayed interval.
            if let lastExecutionTime = self.lastExecutionTime {
                let evaluatedTime = (lastExecutionTime + self.throttle)
                if evaluatedTime > now {
                    return (now, evaluatedTime)
                }
            }

            // Case B.
            // If throotle is not waiting to perform the execution and previous scheduled time is
            // > than direct execution then execute on that delayed time else execute directly.
            guard self.waitingForPerform else {
                return self.immediateFire ? (now, now) : (now, now + self.throttle)
            }

            // Case C.
            // If passFirstDispatch == true execute directly else execute on current + throttle time*/
            if let previousScheduled = self.previousScheduled, previousScheduled > now {
                return (now, previousScheduled)
            }
            return (now, now)

        case .deferred:

            // If previous execution + throttle time is greater than direct execution
            // then execute on that delayed time.
            if let lastExecutionTime = self.lastExecutionTime {
                let evaluatedTime = (lastExecutionTime + self.throttle)
                if evaluatedTime > now {
                    return (now, evaluatedTime)
                }
            }

            // Keep delaying unless passFirstDispatch == true and not waiting on execution
            if !self.waitingForPerform, self.immediateFire {
                return (now, now)
            }
            return (now, now + self.throttle)
        }
    }
}
