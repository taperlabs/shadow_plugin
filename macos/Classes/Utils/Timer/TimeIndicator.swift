import Foundation

//MARK: - Timer Class for both AVAudioRecorder and ScreenCaptureKit 1
class TimeIndicator {
    private var timer: Timer?
    private var startTime: Date?
    private let timeUpdateQueue = DispatchQueue(label: "TimerQueue")
    private(set) var elapsedTime: Int = 0

    var timeUpdateHandler: ((Int) -> Void)?

    func start() {
        stop()
        startTime = Date() // Set the start time to now
        print("Time Indicator 시작~~")
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateTime), userInfo: nil, repeats: true)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        startTime = nil // Clear the start time
    }

    @objc private func updateTime() {
        timeUpdateQueue.sync {
            guard let start = startTime else { return }
            let currentElapsedTime = Int(Date().timeIntervalSince(start))
            if elapsedTime != currentElapsedTime {
                elapsedTime = currentElapsedTime
                timeUpdateHandler?(elapsedTime)
            }
        }
    }
}


//MARK: - Timer Class for both AVAudioRecorder and ScreenCaptureKit 2
//class TimeIndicator {
//    private var timer: Timer?
//    private(set) var elapsedTime: Int = 0
//    private let timeUpdateQueue = DispatchQueue(label: "TimerQueue")
//
//    var timeUpdateHandler: ((Int) -> Void)?
//
//    func start() {
////        stop()
//        reset()
//        print("Time Indicator 시작~~")
//        DispatchQueue.main.async {
//            self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateTime), userInfo: nil, repeats: true)
//        }
////        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
//    }
//
//    func stop() {
//        timer?.invalidate()
//        timer = nil
//    }
//
//    private func reset() {
//        elapsedTime = 0
//    }
//
//    @objc private func updateTime() {
//        timeUpdateQueue.sync {
////            print("Time Indicator 시작~~2222", elapsedTime)
//            elapsedTime += 1
//            timeUpdateHandler?(elapsedTime)
//        }
//    }
//}


