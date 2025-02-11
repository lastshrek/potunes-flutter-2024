import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct MusicActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicAttributes.self) { context in
            MusicActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        AsyncImage(url: URL(string: context.state.coverUrl)) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading) {
                        Text(context.state.title)
                            .font(.headline)
                        Text(context.state.artist)
                            .font(.subheadline)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
            } compactLeading: {
                AsyncImage(url: URL(string: context.state.coverUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 20, height: 20)
                .cornerRadius(4)
            } compactTrailing: {
                Text(context.state.title)
                    .font(.caption)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
            }
        }
    }
}

@available(iOS 16.1, *)
struct MusicActivityView: View {
    let context: ActivityViewContext<MusicAttributes>
    
    var body: some View {
        VStack {
            HStack {
                AsyncImage(url: URL(string: context.state.coverUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 40, height: 40)
                .cornerRadius(8)
                
                VStack(alignment: .leading) {
                    Text(context.state.title)
                        .font(.headline)
                    Text(context.state.artist)
                        .font(.subheadline)
                }
                
                Spacer()
                
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .padding()
        }
    }
} 