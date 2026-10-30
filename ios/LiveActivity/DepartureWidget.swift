import ActivityKit
import WidgetKit
import SwiftUI

@main
struct DepartureWidgetBundle: WidgetBundle {
    var body: some Widget {
        DepartureWidget()
        BarkAnalysisWidget()
    }
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

struct BarkAnalysisWidget: Widget {
    private func label(_ state: BarkAnalysisAttributes.ContentState, stale: Bool) -> String {
        if stale { return "앱에서 분석 상태 확인" }
        switch state.signal {
        case "bark": return "짖음 소리 후보"
        case "dog": return "강아지 소리 후보"
        case "speech": return "말소리 반응"
        case "quiet": return "뚜렷한 짖음 반응 없음"
        default: return "소리를 분석하고 있어요"
        }
    }
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BarkAnalysisAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Label("Bark Note · 실시간 분석", systemImage: "pawprint.fill").font(.headline)
                Text(label(context.state, stale: context.isStale)).font(.title3.bold())
                Text("분석 \(context.state.elapsed)초 · 짖음 모델 반응 \(context.state.barkPercent)%").font(.subheadline)
                Text("반응 창 \(context.state.positive) / 분석 창 \(context.state.processed) · 겹치는 창 기준").font(.caption)
                Text("감정·정확도 아님 · 앱을 뒤로 보내면 분석 종료").font(.caption2)
            }.padding().foregroundColor(.white).activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("실시간 분석", systemImage: "pawprint.fill").font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.elapsed)초").monospacedDigit().font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        Text(label(context.state, stale: context.isStale)).font(.headline)
                        if !context.isStale {
                            Text("짖음 모델 반응 \(context.state.barkPercent)% · 감정·정확도 아님").font(.caption)
                        }
                        Text("앱이 열려 있는 동안 분석 · 최대 5분").font(.caption2)
                    }
                }
            } compactLeading: {
                Image(systemName: "pawprint.fill").foregroundColor(.mint)
            } compactTrailing: {
                Text(context.isStale ? "확인" : context.state.signal == "bark" ? "짖음" : "분석")
                    .font(.caption2).lineLimit(1)
            } minimal: {
                Image(systemName: context.isStale ? "exclamationmark.circle" : "waveform")
                    .foregroundColor(.mint)
            }
        }
    }
}
