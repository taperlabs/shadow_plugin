import Foundation

//MARK: - Timer Class for both AVAudioRecorder and ScreenCaptureKit
class TimeIndicator {
    private var timer: Timer?
    private(set) var elapsedTime: Int = 0
    private let timeUpdateQueue = DispatchQueue(label: "TimerQueue")
    
    var timeUpdateHandler: ((Int) -> Void)?
    
    func start() {
        reset()
        print("Time Indicator 시작~~")
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateTime), userInfo: nil, repeats: true)
        }
//        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func reset() {
        elapsedTime = 0
    }
    
    @objc private func updateTime() {
        timeUpdateQueue.sync {
            print("Time Indicator 시작~~2222", elapsedTime)
            elapsedTime += 1
            timeUpdateHandler?(elapsedTime)
        }
    }
}


