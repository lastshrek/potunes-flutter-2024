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
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
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
                    HStack(spacing: 3) {
                        ForEach(0..<5) { index in
                            AudioWaveformBar(
                                isPlaying: context.state.isPlaying,
                                delay: Double(index) * 0.2
                            )
                        }
                    }
                }
            } compactLeading: {
                AsyncImage(url: URL(string: context.state.coverUrl)) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(width: 20, height: 20)
                .clipShape(Circle())
                .padding(.leading, 4)
            } compactTrailing: {
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        AudioWaveformBar(
                            isPlaying: context.state.isPlaying,
                            delay: Double(index) * 0.2,
                            compact: true
                        )
                    }
                }
                .frame(maxWidth: 40)
                .padding(.trailing, 4)
            } minimal: {
                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
            }
        }
    }
}

struct AudioWaveformBar: View {
    let isPlaying: Bool
    let delay: Double
    var compact: Bool = false
    
    @State private var isAnimating = false
    
    var body: some View {
        let height = compact ? 12.0 : 20.0
        
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.white)
            .frame(width: 2, height: isAnimating ? height : height * 0.3)
            .animation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
            .onAppear {
                if isPlaying {
                    withAnimation {
                        isAnimating = true
                    }
                }
            }
            .onChange(of: isPlaying) { newValue in
                withAnimation {
                    isAnimating = newValue
                }
            }
    }
} 