/*
 * Copyright 2026 the transport
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

@objc
public enum VideoQuality: Int, Sendable {
    case low
    case medium
    case high
}

extension VideoQuality {
    static let RIDs = ["q", "h", "f"]
}

// Make convertible between protobuf type.
extension VideoQuality {
    private static let toPBTypeMap: [VideoQuality: Applooma_VideoQuality] = [
        .low: .low,
        .medium: .medium,
        .high: .high,
    ]

    func toPBType() -> Applooma_VideoQuality {
        Self.toPBTypeMap[self] ?? .low
    }
}

// Make convertible between RIDs.
extension Applooma_VideoQuality {
    static func from(rid: String?) -> Applooma_VideoQuality? {
        switch rid {
        case "q": Applooma_VideoQuality.low
        case "h": Applooma_VideoQuality.medium
        case "f": Applooma_VideoQuality.high
        default: nil
        }
    }

    var asRID: String? {
        switch self {
        case .low: "q"
        case .medium: "h"
        case .high: "f"
        default: nil
        }
    }
}

// Make comparable by the real quality index since the raw protobuf values are not in order.
// E.g. value of `.off` is `3` which is larger than `.high`.
extension Applooma_VideoQuality: Comparable {
    private var _weightIndex: Int {
        switch self {
        case .low: 1
        case .medium: 2
        case .high: 3
        default: 0
        }
    }

    static func < (lhs: Applooma_VideoQuality, rhs: Applooma_VideoQuality) -> Bool {
        lhs._weightIndex < rhs._weightIndex
    }
}
