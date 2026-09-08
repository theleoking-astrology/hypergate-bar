import CryptoKit
import Foundation

guard CommandLine.arguments.count == 3,
  let keyString = ProcessInfo.processInfo.environment["SPARKLE_PUBLIC_ED_KEY"],
  let keyData = Data(base64Encoded: keyString),
  let signature = Data(base64Encoded: CommandLine.arguments[2])
else {
  throw NSError(
    domain: "HypergatePublisher", code: 1,
    userInfo: [NSLocalizedDescriptionKey: "Missing public key or signature"])
}
let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
guard key.isValidSignature(signature, for: archive) else {
  throw NSError(
    domain: "HypergatePublisher", code: 2,
    userInfo: [
      NSLocalizedDescriptionKey: "Update signature does not match the configured public key"
    ])
}
print("Verified final archive EdDSA signature against configured public key.")
