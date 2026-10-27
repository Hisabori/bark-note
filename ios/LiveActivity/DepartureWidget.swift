import ActivityKit
import WidgetKit
import SwiftUI

@main
struct DepartureWidgetBundle: WidgetBundle {
    var body: some Widget { DepartureWidget() }
}

struct DepartureWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DepartureAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Label(context.attributes.station + " · 출발 마감", systemImage: context.attributes.kind == "route" ? "location.fill" : "tram.fill").font(.headline)
                Text(context.attributes.train).font(.caption).lineLimit(2)
                if let updated = context.state.updatedAt { Text("조회 " + updated.formatted(date: .omitted, time: .shortened)).font(.caption2) }
                if context.isStale { Text("출발 시각 또는 조회 기준 만료 · 앱에서 확인").foregroundColor(.orange) }
                else { DepartureCountdown(until: context.state.leaveAt).font(.title.monospacedDigit()) }
                Text((context.attributes.kind == "route" ? "도착 예상 " : "열차 ") + context.state.trainAt.formatted(date: .omitted, time: .shortened) + " · 마지막 조회 예측")
                    .font(.caption)
            }.padding().activityBackgroundTint(Color.black).activitySystemActionForegroundColor(Color.white).foregroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label(context.attributes.station, systemImage: context.attributes.kind == "route" ? "location.fill" : "tram.fill") }
                DynamicIslandExpandedRegion(.trailing) { Text(context.state.trainAt, style: .time) }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack {
                        Text(context.attributes.train).font(.caption)
                        if context.isStale { Text("출발 시각 또는 조회 기준 만료") }
                        else { HStack { Text("출발 마감"); DepartureCountdown(until: context.state.leaveAt).monospacedDigit() } }
                        Text("마지막 조회 예측 · 앱에서 운행정보 갱신").font(.caption2)
                    }
                }
            } compactLeading: { Image(systemName: context.attributes.kind == "route" ? "location.fill" : "tram.fill") }
              compactTrailing: {
                if context.isStale { Image(systemName: "arrow.clockwise") }
                else { DepartureCountdown(until: context.state.leaveAt).font(.caption2).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: 56) }
              } minimal: { Image(systemName: context.isStale ? "arrow.clockwise" : context.attributes.kind == "route" ? "location.fill" : "tram.fill") }
        }
    }
}

struct DepartureCountdown: View {
    let until: Date
    var body: some View {
        let now = Date()
        Text(timerInterval: now...max(now, until), countsDown: true, showsHours: false)
    }
}
