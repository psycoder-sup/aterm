import Foundation

final class PTYFileHandle: @unchecked Sendable {
    private let fd: Int32
    private let readSource: DispatchSourceRead
    private let queue: DispatchQueue
    private let bufferSize = 65536
    private let readBuffer: UnsafeMutablePointer<UInt8>
    private var onRead: (@Sendable (Data) -> Void)?

    init(fd: Int32, queue: DispatchQueue, onRead: @escaping @Sendable (Data) -> Void) {
        self.fd = fd
        self.queue = queue
        self.onRead = onRead
        self.readBuffer = .allocate(capacity: bufferSize)

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        self.readSource = source

        let buffer = self.readBuffer
        let bufferSize = self.bufferSize
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let bytesRead = read(fd, buffer, bufferSize)
            if bytesRead > 0 {
                let data = Data(bytes: buffer, count: bytesRead)
                self.onRead?(data)
            } else if bytesRead == 0 {
                Log.pty.info("PTY read EOF")
            } else {
                let err = errno
                if err != EAGAIN && err != EINTR {
                    Log.pty.error("PTY read error: \(err)")
                }
            }
        }

        source.setCancelHandler { }
        source.resume()
    }

    func write(_ data: Data) {
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            var totalWritten = 0
            while totalWritten < data.count {
                let result = Darwin.write(
                    fd,
                    baseAddress.advanced(by: totalWritten),
                    data.count - totalWritten
                )
                if result < 0 {
                    let err = errno
                    if err == EINTR { continue }
                    if err == EAGAIN { return }
                    Log.pty.error("PTY write error: \(err)")
                    return
                }
                totalWritten += result
            }
        }
    }

    func close() {
        readSource.cancel()
        onRead = nil
    }

    deinit {
        readSource.cancel()
        readBuffer.deallocate()
    }
}
