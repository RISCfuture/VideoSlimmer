import Foundation

extension Process {

  // Suspends until the process exits instead of blocking a thread on
  // `waitUntilExit()`. Inspect `terminationStatus` afterward for the exit code.
  func runUntilExit() async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, any Error>) in
      terminationHandler = { _ in continuation.resume() }
      do {
        try run()
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}

extension FileHandle {

  // Reads all bytes until end of file without blocking the cooperative
  // executor.
  func readAllData() async throws -> Data {
    var data = Data()
    for try await byte in bytes { data.append(byte) }
    return data
  }
}
