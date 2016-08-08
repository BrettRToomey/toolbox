import Console
import Foundation

public final class Run: Command {
    public let id = "run"

    public let help: [String] = [
        "Runs the compiled application."
    ]

    public let console: ConsoleProtocol

    public init(console: ConsoleProtocol) {
        self.console = console
    }

    public func generateCommand(arguments: [String]) throws -> String {
        let folder: String

        if arguments.flag("release") {
            folder = "release"
        } else {
            folder = "debug"
        }

        do {
            _ = try console.backgroundExecute("ls .build/\(folder)")
        } catch ConsoleError.subexecute(_) {
            throw ToolboxError.general("No .build/\(folder) folder found.")
        }

        let name: String

        if let n = arguments.options["name"]?.string {
            name = n
        } else if let n = try extractName() {
            name = n
        } else {
            if arguments.options["name"]?.string == nil {
                console.info("Use --name to manually supply the package name.")
            }

            throw ToolboxError.general("Unable to determine package name.")
        }

        console.info("Running \(name)...")

        var passThrough = arguments.values
        for (name, value) in arguments.options {
            passThrough += "--\(name)=\(value)"
        }

        passThrough.insert(".build/\(folder)/App", at: 0)
        return passThrough.joined(separator: " ")
    }

    public func run(arguments: [String]) throws {
        do {
            let command = try generateCommand(arguments: arguments)
            try console.foregroundExecute(command)
        } catch ConsoleError.execute(_) {
            throw ToolboxError.general("Run failed.")
        }
    }

    public func backgroundRun(arguments: [String]) throws -> String {
        do {
            let command = try generateCommand(arguments: arguments)
            return try console.backgroundExecute(command)
        } catch ConsoleError.subexecute(_, let message) {
            throw ToolboxError.general("Run failed: \(message)")
        }
    }

    private func extractName() throws -> String? {
        let dump = try console.backgroundExecute("swift package dump-package")

        let dumpSplit = dump.components(separatedBy: "\"name\": \"")

        guard dumpSplit.count == 2 else {
            return nil
        }

        let nameSplit = dumpSplit[1].components(separatedBy: "\"")
        return nameSplit.first
    }
}
