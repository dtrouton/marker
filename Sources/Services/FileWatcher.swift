import Foundation

final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let url: URL
    private let onChange: () -> Void

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    func start() {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.onChange()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
        }

        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
