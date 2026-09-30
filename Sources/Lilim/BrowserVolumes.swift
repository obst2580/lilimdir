import AppKit

extension BrowserState {
    func refreshVolumes() {
        let keys: [URLResourceKey] = [.volumeLocalizedNameKey, .volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsLocalKey]
        mountedVolumes = (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? [])
            .filter { $0.path != "/" }
            .compactMap { url in
                guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
                return MountedVolume(url: url, name: values.volumeLocalizedName ?? url.lastPathComponent,
                                     ejectable: values.volumeIsEjectable == true || values.volumeIsRemovable == true,
                                     local: values.volumeIsLocal ?? true)
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func eject(_ volume: MountedVolume) {
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
            if currentDirectory.path == volume.url.path || currentDirectory.path.hasPrefix(volume.url.path + "/") {
                navigate(to: FileManager.default.homeDirectoryForCurrentUser)
            }
            refreshVolumes()
        } catch { errorMessage = error.localizedDescription }
    }
}
