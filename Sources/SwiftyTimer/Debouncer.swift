//
//  Debouncer.swift
//  SwiftyTimer
//
//  Created by CodingIran on 2023/6/26.
//

import Foundation

/// The Debouncer will delay a function call, and every time it's getting called it will
/// delay the preceding call until the delay time is over.
open class Debouncer {
    /// Typealias for callback type
    public typealias Callback = () -> Void

    /// Delay interval
    public private(set) var delay: SwiftyTimer.Interval

    /// Callback to activate
    public var callback: Callback?

    /// Internal timer to fire callback event.
    private var timer: Timer?

    /// Initialize a new debouncer with given delay and callback.
    /// Debouncer class to delay functions that only get delay each other until the timer fires.
    ///
    /// - Parameters:
    ///   - delay: delay interval
    ///   - callback: callback to activate
    public init(_ delay: SwiftyTimer.Interval, callback: Callback? = nil) {
        self.delay = delay
        self.callback = callback
    }

    /// Call debouncer to start the callback after the delayed time.
    /// Multiple calls will ignore the older calls and overwrite the firing time.
    ///
    /// - Parameters:
    ///   - newDelay: New delay interval
    public func call(newDelay: SwiftyTimer.Interval? = nil) {
        if let newDelay = newDelay {
            self.delay = newDelay
        }

        if self.timer == nil {
            self.timer = Timer.once(after: self.delay) { [weak self] _ in
                guard let callback = self?.callback else {
                    debugPrint("Debouncer fired but callback not set.")
                    return
                }
                callback()
            }
        } else {
            self.timer?.reset(self.delay, restart: true)
        }
    }
}
