import Foundation

final public class MainThreadWatchDog {
    public static let DefaultThreshold = 0.0166 // 1/60
    public static let sharedInstance = MainThreadWatchDog()
    private var pingThread: PingThread?
    
    private init() {
        pingThread = PingThread()
    }
    
    public func start() {
        pingThread?.start()
    }
    
    public func stop() {
        pingThread?.cancel()
    }
    
    private func cleanup() {
        self.pingThread?.cancel()
        self.pingThread = nil
    }
    
    deinit {
        cleanup()
    }
}

private final class PingThread: Thread {
    private let semaphore = DispatchSemaphore(value: 0)
    private let pingTaskIsRunningLock = NSObject()
    private var _pingTaskIsRunning = false
    
    private var pingTaskIsRunning: Bool {
        get {
            objc_sync_enter(pingTaskIsRunningLock)
            let result = _pingTaskIsRunning;
            objc_sync_exit(pingTaskIsRunningLock)
            return result
        }
        set {
            objc_sync_enter(pingTaskIsRunningLock)
            _pingTaskIsRunning = newValue
            objc_sync_exit(pingTaskIsRunningLock)
        }
    }
    
    override init() {
        super.init()
        self.name = "MainThreadWatchDog"
    }
    
    override func main() {
        while !isCancelled {
            pingTaskIsRunning = true
            let t1 = clock()
            DispatchQueue.main.async { [weak self] in
                if let hasSelf = self {
                    hasSelf.pingTaskIsRunning = false
                    hasSelf.semaphore.signal()
                }
            }
            
            Thread.sleep(forTimeInterval: MainThreadWatchDog.DefaultThreshold)
            
            if pingTaskIsRunning {
                print("--- Main Thread Is Busy")
            }
            
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
            
            let t2 = clock()
            let dt = Double(t2 - t1) / Double(CLOCKS_PER_SEC)
            if dt > MainThreadWatchDog.DefaultThreshold {
                print(String(format: "--- Main Thread Delay Is: %.2f ms", dt*1000))
            }
        }
    }
}
