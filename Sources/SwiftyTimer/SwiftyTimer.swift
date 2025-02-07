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

/// Current SwiftyTimer version 2.0.5. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
let version = "2.0.5"

public enum Interval: Sendable {
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

extension Interval: Equatable {
    public static func == (lhs: Interval, rhs: Interval) -> Bool {
        lhs.value == rhs.value
    }
}

extension Interval: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension DispatchTimeInterval: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .nanoseconds(let value):
            hasher.combine("nanoseconds\(value)")
        case .microseconds(let value):
            hasher.combine("microseconds\(value)")
        case .milliseconds(let value):
            hasher.combine("milliseconds\(value)")
        case .seconds(let value):
            hasher.combine("seconds\(value)")
        case .never:
            hasher.combine("never")
        @unknown default:
            hasher.combine("unknown")
        }
    }
}
