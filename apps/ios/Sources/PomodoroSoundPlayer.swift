import AudioToolbox

struct PomodoroSoundPlayer {
    func playStart() {
        AudioServicesPlaySystemSound(1104)
    }

    func playCompletion() {
        AudioServicesPlaySystemSound(1111)
    }
}
