//
//  SwiftyTimer.swift
//  SwiftyTimer
//
//  Created by CodingIran on 2023/6/26.
//

import Foundation

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.5)
#error("SwiftyTimer doesn't support Swift versions below 5.5.")
#endif

/// Current SwiftyTimer version 1.0.2. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
let version = "1.0.2"

public enum Interval {
    case nanoseconds(_: Int)
    case microseconds(_: Int)
    case milliseconds(_: Int)
    case minutes(_: Int)
    case seconds(_: Double)
    case hours(_: Int)
    case days(_: Int)

    var value: DispatchTimeInterval {
        switch self {
        case .nanoseconds(let value): return .nanoseconds(value)
        case .microseconds(let value): return .microseconds(value)
        case .milliseconds(let value): return .milliseconds(value)
        case .seconds(let value): return .milliseconds(Int(Double(value) * Double(1000)))
        case .minutes(let value): return .seconds(value * 60)
        case .hours(let value): return .seconds(value * 3600)
        case .days(let value): return .seconds(value * 86400)
        }
    }
}
