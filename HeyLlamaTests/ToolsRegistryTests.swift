import XCTest
@testable import HeyLlama

final class ToolsRegistryTests: XCTestCase {

    // MARK: - SkillsConfig Tests

    func testSkillsConfigDefaults() {
        let config = SkillsConfig()
        XCTAssertTrue(config.enabledSkillIds.isEmpty)
    }

    func testSkillsConfigIsSkillEnabled() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        XCTAssertTrue(config.isSkillEnabled("weather.forecast"))
        XCTAssertFalse(config.isSkillEnabled("other"))
    }

    func testSkillsConfigCodable() throws {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast", "reminders.add_item"]

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(SkillsConfig.self, from: data)

        XCTAssertEqual(decoded.enabledSkillIds, config.enabledSkillIds)
    }

    // MARK: - Skill Type Tests

    func testSkillTypes() {
        let weather = WeatherForecastSkill.self
        XCTAssertEqual(weather.id, "weather.forecast")
        XCTAssertEqual(weather.name, "Weather Forecast")
        XCTAssertFalse(weather.skillDescription.isEmpty)
        XCTAssertEqual(weather.requiredPermissions, [.location])
        XCTAssertFalse(weather.argumentsJSONSchema.isEmpty)

        let reminders = RemindersAddItemSkill.self
        XCTAssertEqual(reminders.id, "reminders.add_item")
        XCTAssertEqual(reminders.name, "Add Reminder")
        XCTAssertEqual(reminders.requiredPermissions, [.reminders])
    }

    // MARK: - SkillsRegistry Tests

    func testSkillsRegistryCreation() {
        let registry = SkillsRegistry()
        XCTAssertNotNil(registry)
    }

    func testRegistryHasBuiltInSkills() {
        let registry = SkillsRegistry()
        let allSkills = registry.allSkills
        XCTAssertEqual(allSkills.count, 9)
        XCTAssertTrue(allSkills.contains(.weatherForecast))
        XCTAssertTrue(allSkills.contains(.remindersAddItem))
        XCTAssertTrue(allSkills.contains(.remindersRemoveItem))
        XCTAssertTrue(allSkills.contains(.remindersCompleteItem))
        XCTAssertTrue(allSkills.contains(.remindersReadItems))
        XCTAssertTrue(allSkills.contains(.musicPlay))
        XCTAssertTrue(allSkills.contains(.musicAddToPlaylist))
        XCTAssertTrue(allSkills.contains(.musicNowPlaying))
        XCTAssertTrue(allSkills.contains(.musicControl))
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

    func testEnableSkill() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)

        XCTAssertEqual(registry.enabledSkills.count, 1)
        XCTAssertEqual(registry.enabledSkills.first, .weatherForecast)
    }

    func testEnableMultipleSkills() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast", "reminders.add_item"]
        let registry = SkillsRegistry(config: config)

        XCTAssertEqual(registry.enabledSkills.count, 2)
    }

    func testEnableNonexistentSkillIgnored() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast", "nonexistent.skill"]
        let registry = SkillsRegistry(config: config)

        XCTAssertEqual(registry.enabledSkills.count, 1)
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

    func testManifestForEnabledSkills() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)

        let manifest = registry.generateSkillsManifest()

        XCTAssertTrue(manifest.contains("weather.forecast"))
        XCTAssertTrue(manifest.contains("Weather Forecast"))
        XCTAssertFalse(manifest.contains("reminders.add_item"))
    }

    func testManifestIncludesArgumentSchema() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)

        let manifest = registry.generateSkillsManifest()

        XCTAssertTrue(manifest.contains("when"))
        XCTAssertTrue(manifest.contains("today"))
    }

    func testManifestIncludesJsonOnlyInstruction() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)

        let manifest = registry.generateSkillsManifest()

        XCTAssertTrue(manifest.contains("single JSON object"))
        XCTAssertTrue(manifest.contains("Do not wrap"))
    }
}
