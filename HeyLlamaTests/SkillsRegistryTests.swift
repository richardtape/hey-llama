import XCTest
@testable import HeyLlama

final class SkillsRegistryTests: XCTestCase {

    // MARK: - New Skill Type API Tests

    func testRegistryHasAllSkillTypes() {
        XCTAssertEqual(SkillsRegistry.allSkillTypes.count, 2)
    }

    func testGetSkillTypeById() {
        let skillType = SkillsRegistry.skillType(withId: "weather.forecast")
        XCTAssertNotNil(skillType)
        XCTAssertEqual(skillType?.id, "weather.forecast")
    }

    func testGetNonexistentSkillType() {
        let skillType = SkillsRegistry.skillType(withId: "nonexistent.skill")
        XCTAssertNil(skillType)
    }

    func testSkillTypesDisabledByDefault() {
        let registry = SkillsRegistry()
        XCTAssertTrue(registry.enabledSkillTypes.isEmpty)
    }

    func testEnabledSkillTypes() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)
        XCTAssertEqual(registry.enabledSkillTypes.count, 1)
        XCTAssertEqual(registry.enabledSkillTypes.first?.id, "weather.forecast")
    }

    func testSkillTypeMetadataAccessible() {
        let weatherType = SkillsRegistry.skillType(withId: "weather.forecast")!
        XCTAssertEqual(weatherType.id, "weather.forecast")
        XCTAssertEqual(weatherType.name, "Weather Forecast")
        XCTAssertEqual(weatherType.requiredPermissions, [.location])
        XCTAssertTrue(weatherType.includesInResponseAgent)
    }

    func testManifestIncludesJSONSchema() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)

        let manifest = registry.generateSkillsManifest()

        XCTAssertTrue(manifest.contains("weather.forecast"))
        XCTAssertTrue(manifest.contains("\"type\": \"object\""))
    }

    // MARK: - Common API Tests

    func testIsSkillEnabled() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)
        XCTAssertTrue(registry.isSkillEnabled("weather.forecast"))
        XCTAssertFalse(registry.isSkillEnabled("reminders.add_item"))
    }

    func testUpdateConfig() {
        var registry = SkillsRegistry()
        XCTAssertTrue(registry.enabledSkillTypes.isEmpty)

        var newConfig = SkillsConfig()
        newConfig.enabledSkillIds = ["weather.forecast"]
        registry.updateConfig(newConfig)
        XCTAssertEqual(registry.enabledSkillTypes.count, 1)
    }

    func testManifestWhenNoSkillsEnabled() {
        let registry = SkillsRegistry()
        let manifest = registry.generateSkillsManifest()
        XCTAssertTrue(manifest.contains("No skills are currently enabled"))
    }

    func testSkillsConfigCodable() throws {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast", "reminders.add_item"]

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SkillsConfig.self, from: data)

        XCTAssertEqual(decoded.enabledSkillIds, config.enabledSkillIds)
    }

    func testSkillTypesIncludeResponseAgentMetadata() {
        XCTAssertTrue(WeatherForecastSkill.includesInResponseAgent)
        XCTAssertTrue(RemindersAddItemSkill.includesInResponseAgent)
    }
}
