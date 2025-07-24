import AVFAudio
import Combine

public enum FormatMusicResource: String {
    case wav = "wav"
    case mp3 = "mp3"
}

@MainActor
public final class AudioManagerService: ObservableObject {

    private(set) var player: AVAudioPlayer!
    private let musicResourceName: String
    private let formatMusic: FormatMusicResource
    
    public init(musicResourceName: String, formatMusic: FormatMusicResource) {
        self.musicResourceName = musicResourceName
        self.formatMusic = formatMusic
        setupSession()
        preparePlayer()
    }

    public func playbackStartet() {
        if !player.isPlaying {
            player.play()
        }
    }

    public func playbackPauseу() {
        player.pause()
    }
    
}

extension AudioManagerService {
    
    private func setupSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay, .duckOthers])
            try session.setActive(true)
        } catch {
            print("AudioSession error:", error)
        }
    }

    private func preparePlayer() {
        guard let url = Bundle.main.url(forResource: musicResourceName.self, withExtension: formatMusic.rawValue) else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 1
            p.prepareToPlay()
            player = p
        } catch {
            print("AVAudioPlayer error:", error)
        }
    }
    
}
