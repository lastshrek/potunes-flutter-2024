import ActivityKit
import SwiftUI

@available(iOS 16.1, *)
public struct MusicAttributes: ActivityAttributes {
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
} 