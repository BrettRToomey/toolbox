import Console

public final class DockerInit: Command {
    public let id = "init"

    public let signature: [Argument] = []

    public let help: [String] = [
        "Prepares the application for Docker."
    ]

    public let console: ConsoleProtocol

    public init(console: ConsoleProtocol) {
        self.console = console
    }

    public func run(arguments: [String]) throws {
        do {
            let contents = try console.backgroundExecute("ls .")
            if contents.contains("Dockerfile") {
                throw ToolboxError.general("Directory already contains a Dockerfile")
            }
        } catch ConsoleError.subexecute(_) {
            throw ToolboxError.general("Could not check for Dockerfile")
        }

        let initBar = console.loadingBar(title: "Cloning Dockerfile")
        initBar.start()

        do {
            _ = try console.backgroundExecute("curl -L docker.qutheory.io -o Dockerfile")
            initBar.finish()
        } catch ConsoleError.subexecute(_, let message) {
            initBar.fail()
            throw ToolboxError.general("Could not download Dockerfile: \(message)")
        }

        if console.confirm("Would you like to build the Docker image now?") {
            console.warning("This may take a while...")
            let build = DockerBuild(console: console)
            try build.run(arguments: arguments)
        }
    }

}
