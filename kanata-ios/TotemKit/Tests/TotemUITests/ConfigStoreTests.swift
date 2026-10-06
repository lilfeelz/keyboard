import Testing
import TotemCore

@testable import TotemUI

@Suite struct ConfigStoreTests {
  @Test(arguments: [
    ("dev.feelz.totem", "group.dev.feelz.totem"),
    ("dev.feelz.totem.keyboard", "group.dev.feelz.totem"),
    ("dev.feelz.totem.JY4PD9Q24B", "group.dev.feelz.totem.JY4PD9Q24B"),
    ("dev.feelz.totem.JY4PD9Q24B.keyboard", "group.dev.feelz.totem.JY4PD9Q24B"),
  ])
  func groupFollowsAppBundleID(bundleID: String, group: String) {
    #expect(ConfigStore.group(for: bundleID) == group)
  }

  @Test func failedSaveStaysUnsaved() {
    var s = ConfigStore.Saved("old")
    s.save("new") { _ in throw ConfigError("disk full") }
    #expect(s.text == "old")
    #expect(s.error == "disk full")
    s.save("new") { _ in }
    #expect(s.text == "new")
    #expect(s.error == nil)
  }
}
