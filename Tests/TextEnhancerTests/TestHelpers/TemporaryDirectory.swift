import Foundation

class TemporaryDirectory {
    let url: URL
    
    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextEnhancerTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
    
    func configFile() -> URL {
        return url.appendingPathComponent("config.json")
    }
    
    func appSupportDirectory() -> URL {
        return url.appendingPathComponent("AppSupport")
    }
    
    func createAppSupportDirectory() throws {
        try FileManager.default.createDirectory(at: appSupportDirectory(), withIntermediateDirectories: true)
    }
    
    deinit {
        cleanup()
    }
} 