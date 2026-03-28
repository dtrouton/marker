import Foundation

enum GitFileStatus {
    case modified
    case added
    case untracked
}

enum GitStatusService {
    static func status(in directory: URL) -> [URL: GitFileStatus] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["status", "--porcelain", "-uall"]
        process.currentDirectoryURL = directory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch { return [:] }

        guard process.terminationStatus == 0 else { return [:] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        var result: [URL: GitFileStatus] = [:]
        for line in output.components(separatedBy: "\n") where line.count >= 4 {
            let statusCode = String(line.prefix(2))
            let filePath = String(line.dropFirst(3))
            let fileURL = directory.appendingPathComponent(filePath)

            if statusCode == "??" {
                result[fileURL] = .untracked
            } else if statusCode.contains("A") {
                result[fileURL] = .added
            } else if statusCode.contains("M") {
                result[fileURL] = .modified
            }
        }
        return result
    }
}
