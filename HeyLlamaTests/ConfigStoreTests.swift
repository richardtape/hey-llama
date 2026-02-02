import XCTest
@testable import HeyLlama

final class ConfigStoreTests: XCTestCase {

    var tempDirectory: URL!
    var configStore: ConfigStore!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        configStore = ConfigStore(baseDirectory: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testLoadConfigReturnsDefaultWhenNoFile() {
        let config = configStore.loadConfig()
        XCTAssertEqual(config.wakePhrase, "hey llama")
        XCTAssertEqual(config.llm.provider, .appleIntelligence)
    }

    func testSaveAndLoadConfig() throws {
        var config = AssistantConfig.default
        config.wakePhrase = "ok computer"
        config.llm.provider = .openAICompatible
        config.llm.openAICompatible.model = "llama3.2"
        config.llm.openAICompatible.baseURL = "http://localhost:11434/v1"

        try configStore.saveConfig(config)
        let loaded = configStore.loadConfig()

        XCTAssertEqual(loaded.wakePhrase, "ok computer")
        XCTAssertEqual(loaded.llm.provider, .openAICompatible)
        XCTAssertEqual(loaded.llm.openAICompatible.model, "llama3.2")
    }

    func testConfigFileLocation() {
        let expectedPath = tempDirectory.appendingPathComponent("config.json")
        XCTAssertEqual(configStore.configFileURL, expectedPath)
    }

    func testSaveCreatesFile() throws {
        let config = AssistantConfig.default
        try configStore.saveConfig(config)

        XCTAssertTrue(FileManager.default.fileExists(atPath: configStore.configFileURL.path))
    }

    func testLoadConfigHandlesCorruptFile() throws {
        // Write invalid JSON
        let invalidData = "not valid json".data(using: .utf8)!
        try invalidData.write(to: configStore.configFileURL)

        // Should return default config
        let config = configStore.loadConfig()
        XCTAssertEqual(config.wakePhrase, "hey llama")
    }
}
