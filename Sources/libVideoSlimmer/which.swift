import Foundation

/**
 Locates the path for an executable by name. Uses the `which` CLI tool, which
 respects `$PATH`.

 - Parameter executable: The name of the executable.
 - Returns: The URL path to the executable.
 */
public func which(_ executable: String) throws -> URL? {
    let process = Process()
    let stdout = Pipe()
    process.executableURL = URL(filePath: "/usr/bin/which", directoryHint: .notDirectory)
    process.arguments = [executable]
    process.standardOutput = stdout

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == .zero else {
        fatalError("which exited with status \(process.terminationStatus)")
    }
    guard let data = try stdout.fileHandleForReading.readToEnd(),
          let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
        return nil
    }

    return URL(filePath: path, directoryHint: .notDirectory)
}
