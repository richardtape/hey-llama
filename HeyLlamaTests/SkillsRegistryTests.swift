import XCTest
@testable import HeyLlama

final class SkillsRegistryTests: XCTestCase {

    func testRegistryHasBuiltInSkills() {
        let registry = SkillsRegistry()
        let allSkills = registry.allSkills
        XCTAssertEqual(allSkills.count, 2)
    }

    func testGetSkillById() {
        let registry = SkillsRegistry()
        let skill = registry.skill(withId: "weather.forecast")
        XCTAssertNotNil(skill)
        XCTAssertEqual(skill?.id, "weather.forecast")
    }

    func testGetNonexistentSkill() {
        let registry = SkillsRegistry()
        let skill = registry.skill(withId: "nonexistent.skill")
        XCTAssertNil(skill)
    }

    func testSkillsDisabledByDefault() {
        let registry = SkillsRegistry()
        XCTAssertTrue(registry.enabledSkills.isEmpty)
    }

    func testIsSkillEnabled() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)
        XCTAssertTrue(registry.isSkillEnabled("weather.forecast"))
        XCTAssertFalse(registry.isSkillEnabled("reminders.add_item"))
    }

    func testUpdateConfig() {
        var registry = SkillsRegistry()
        XCTAssertTrue(registry.enabledSkills.isEmpty)

        var newConfig = SkillsConfig()
        newConfig.enabledSkillIds = ["weather.forecast"]
        registry.updateConfig(newConfig)
        XCTAssertEqual(registry.enabledSkills.count, 1)
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

    func testRegisteredSkillProperties() {
        let weather = RegisteredSkill.weatherForecast
        XCTAssertEqual(weather.id, "weather.forecast")
        XCTAssertEqual(weather.name, "Weather Forecast")
        XCTAssertEqual(weather.requiredPermissions, [.location])
    }

    func testSkillsIncludeResponseAgentMetadata() {
        XCTAssertTrue(RegisteredSkill.weatherForecast.includesInResponseAgent)
        XCTAssertTrue(RegisteredSkill.remindersAddItem.includesInResponseAgent)
    }
}
