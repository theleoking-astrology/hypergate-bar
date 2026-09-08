import Foundation
import HypergateCore
import HypergateAstronomyEngine

@main
struct HypergateCLI {
    static func main() async {
        do {
            let args = Array(CommandLine.arguments.dropFirst())
            guard args.first == "sky", let index = args.firstIndex(of: "--at"), args.indices.contains(index + 1) else {
                throw CoreError.invalidArgument("Usage: hypergate sky --at <ISO8601> --json")
            }
            let date = try UTCDate.parse(args[index + 1])
            let provider = AstronomyEngineProvider()
            let positions = try await provider.positions(at: date, bodies: Body.allCases)
            let document = SkySnapshot(provider: provider.metadata, at: date, calculatedAt: Date(), positions: positions)
            FileHandle.standardOutput.write(try UTCDate.encoder().encode(document))
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(2)
        }
    }
}
