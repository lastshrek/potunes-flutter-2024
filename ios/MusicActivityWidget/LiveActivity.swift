import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct MusicLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicAttributes.self) { context in
            // Lock Screen/Banner UI goes here
            VStack {
                HStack {
                    Text(context.state.title)
                    Spacer()
                    Text(context.state.artist)
                }
                if let url = URL(string: context.state.coverUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.gray
                    }
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AsyncImage(url: URL(string: context.state.coverUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
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