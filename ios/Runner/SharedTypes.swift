import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
public struct MusicAttributes: ActivityAttributes, Hashable {
    public init() {}
    
    public typealias ContentState = MusicState
    
    public struct MusicState: Codable, Hashable {
        public init(title: String, artist: String, coverUrl: String, isPlaying: Bool) {
            self.title = title
            self.artist = artist
            self.coverUrl = coverUrl
            self.isPlaying = isPlaying
        }
        
        public var title: String
        public var artist: String
        public var coverUrl: String
        public var isPlaying: Bool
    }
    
    // 实现 Hashable 协议
    public func hash(into hasher: inout Hasher) {
        // 由于 MusicAttributes 没有存储属性，我们可以使用一个固定值
        hasher.combine(0)
    }
    
    public static func == (lhs: MusicAttributes, rhs: MusicAttributes) -> Bool {
        // 由于 MusicAttributes 没有存储属性，所有实例都相等
        return true
    }
}

@available(iOS 16.2, *)
struct MusicLiveActivityView: View {
    let context: ActivityViewContext<MusicAttributes>
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面图片
            if let url = URL(string: context.state.coverUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                } placeholder: {
                    Color.gray
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                }
            }
            
            // 标题和艺术家
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(context.state.artist)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 播放/暂停按钮
            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
    }
}

@available(iOS 16.2, *)
struct MusicLiveActivityExpandedView: View {
    let context: ActivityViewContext<MusicAttributes>
    
    var body: some View {
        VStack(spacing: 16) {
            // 封面图片
            if let url = URL(string: context.state.coverUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                        .cornerRadius(16)
                } placeholder: {
                    Color.gray
                        .frame(width: 200, height: 200)
                        .cornerRadius(16)
                }
            }
            
            // 标题和艺术家
            VStack(spacing: 4) {
                Text(context.state.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(context.state.artist)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            // 播放/暂停按钮
            Image(systemName: context.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.white)
        }
        .padding(24)
        .background(Color.black.opacity(0.8))
    }
}

@available(iOS 16.1, *)
struct MusicLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicAttributes.self) { context in
            if #available(iOS 16.2, *) {
                MusicLiveActivityView(context: context)
            } else {
                // 低于 16.2 版本的回退界面
                HStack {
                    Text("需要 iOS 16.2 或更高版本")
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.8))
            }
        } dynamicIsland: { context in
            DynamicIsland(
                expanded: {
                    DynamicIslandExpandedRegion(.center) {
                        VStack {
                            if let url = URL(string: context.state.coverUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(8)
                                } placeholder: {
                                    Color.gray
                                }
                            }
                            Text(context.state.title)
                                .font(.headline)
                        }
                    }
                },
                compactLeading: {
                    // 紧凑状态左侧
                    if let url = URL(string: context.state.coverUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray
                        }
                    }
                },
                compactTrailing: {
                    // 紧凑状态右侧
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                },
                minimal: {
                    // 最小状态
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                }
            )
        }
    }
} 