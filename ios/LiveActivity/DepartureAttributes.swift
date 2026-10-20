import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct DepartureAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var leaveAt: Date
        var trainAt: Date
    }
    var station: String
    var train: String
}
