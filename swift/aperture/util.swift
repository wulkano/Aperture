import Foundation

private final class StandardErrorOutputStream: TextOutputStream {
  func write(_ string: String) {
    FileHandle.standardError.write(string.data(using: .utf8)!)
  }
}

private var stderr = StandardErrorOutputStream()

func printErr(_ item: Any) {
  print(item, to: &stderr)
}

func toJson<T>(_ data: T) throws -> String {
  let json = try JSONSerialization.data(withJSONObject: data)
  return String(data: json, encoding: .utf8)!
}
