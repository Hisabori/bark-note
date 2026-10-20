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
                Label(context.attributes.station + " · 출발 마감", systemImage: "tram.fill").font(.headline)
                Text(context.attributes.train).font(.caption)
                if context.isStale { Text("예측 만료 · 앱에서 다시 조회해주세요").foregroundColor(.orange) }
                else { DepartureCountdown(until: context.state.leaveAt).font(.title.monospacedDigit()) }
                Text("열차 " + context.state.trainAt.formatted(date: .omitted, time: .shortened) + " · 마지막 조회 예측")
                    .font(.caption)
            }.padding().activityBackgroundTint(Color.black).activitySystemActionForegroundColor(Color.white).foregroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label(context.attributes.station, systemImage: "tram.fill") }
                DynamicIslandExpandedRegion(.trailing) { Text(context.state.trainAt, style: .time) }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack {
                        Text(context.attributes.train).font(.caption)
                        if context.isStale { Text("예측 만료 · 다시 조회") }
                        else { HStack { Text("출발 마감"); DepartureCountdown(until: context.state.leaveAt).monospacedDigit() } }
                        Text("마지막 조회 예측 · 앱에서 운행정보 갱신").font(.caption2)
                    }
                }
            } compactLeading: { Image(systemName: "tram.fill") }
              compactTrailing: {
                if context.isStale { Image(systemName: "arrow.clockwise") }
                else { DepartureCountdown(until: context.state.leaveAt).monospacedDigit().frame(maxWidth: 56) }
              } minimal: { Image(systemName: context.isStale ? "arrow.clockwise" : "tram.fill") }
        }
    }
}

struct DepartureCountdown: View {
    let until: Date
    var body: some View {
        let now = Date()
        Text(timerInterval: now...max(now, until), countsDown: true)
    }
}
