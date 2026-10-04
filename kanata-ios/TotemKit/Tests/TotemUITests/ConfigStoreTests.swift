import Testing

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
}
