import Core
import Console
import Foundation

public final class TestFix: Command {
    public let id = "testfix"
    
    public var signature: [Argument] = []
    
    public let console: ConsoleProtocol
    
    public var help: [String] = [
        "Verifies and fixes XCTest modules for Linux.",
        "Gathers and generates all test cases and a LinuxMain for Linux tests."
    ]
    
    public init(console: ConsoleProtocol) {
        self.console = console
    }
    
    public func run(arguments: [String]) throws {
        let (testModules, linuxMainURL, files) = getTestFolders()
        guard files.count > 0 else {
            console.print("Couldn't find any test files.")
            console.print("Please make sure that you're in the project root or in /Tests")
            exit(3)
        }
        
        //let startTime = CFAbsoluteTimeGetCurrent()
        let tests = try files.map { try TestParser.parse(TestFile(url: $0)) }
        //let endTime = CFAbsoluteTimeGetCurrent()
        
        //print("total time: \(endTime - startTime)")
        
        guard let linuxMainURLUnwrapped = linuxMainURL else {
            console.error("Missing Tests/LinuxMain.swift")
            exit(1)
        }
        
        let linuxMain = try TestParser.parse(linuxMain: LinuxMain(url: linuxMainURLUnwrapped))
        if let (missingTestModules, missingTestCases) = verifyLinuxMain(
            linuxMain,
            testModules: testModules,
            testCases: tests.testCases
        ) {
            console.error("Invalid LinuxMain.swift")
            console.warning("Please update it to the following:\n")
            printCorrectLinuxMain(
                testModules: testModules,
                missingTestModules: missingTestModules,
                testCases: tests.testCases,
                missingTestCases: missingTestCases
            )
        }
        
        let erroneousTestcases = verifyTests(tests)
        let totalFailed = erroneousTestcases.count
        guard totalFailed == 0 else {
            console.error("\(totalFailed) XCTestCases have invalid `allTests`.")
            console.warning("Please update the following:\n")
            
            erroneousTestcases.forEach { name, tests in
                console.info("- \(name)")
                console.print(correctAllTests(for: name, given: tests))
                console.print()
            }
            
            exit(2)
        }
        
        console.success("Tests are 👌")
    }
}

extension TestFix {
    func getTestFolders() -> ([String], URL?, [URL]) {
        let fileManager = FileManager.default
        
        var baseURL = fileManager.currentDirectoryPath
        if baseURL.components(separatedBy: "/").last != "Tests" {
            baseURL += "/Tests"
        }
        
        let url = URL(fileURLWithPath: baseURL)
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: []) else {
            return ([], nil, [])
        }
        
        var testModules: [String] = []
        var linuxMainURL: URL? = nil
        var files: [URL] = []
        
        for case let file as URL in enumerator {
            let lastPathComponent = file.lastPathComponent
            if !lastPathComponent.contains(".") && lastPathComponent.contains("Tests"){
                testModules.append(lastPathComponent)
            } else if lastPathComponent == "LinuxMain.swift" {
                linuxMainURL = file
            } else if lastPathComponent.hasSuffix(".swift"){
                files.append(file)
            }
        }
        
        return (testModules, linuxMainURL, files)
    }
    
    func verifyLinuxMain(
        _ linuxMain: LinuxMain,
        testModules: [String],
        testCases: [String]
    ) -> ([String], [String])? {
        var missingTestModules: [String] = []
        var missingTestCases: [String] = []
        
        testModules.forEach {
            if !linuxMain.moduleImports.contains($0) {
                missingTestModules.append($0)
            }
        }
        
        testCases.forEach {
            if !linuxMain.testCases.contains($0) {
                missingTestCases.append($0)
            }
        }
        
        if missingTestModules.count == 0 && missingTestCases.count == 0 {
            return nil
        }
        
        return (missingTestModules, missingTestCases)
    }
    
    func verifyTests(_ tests: [TestFile]) -> [(String, [String])] {
        var erroneousTestcases: [(String, [String])] = []
        
        tests.forEach {
            $0.testCases.forEach {
                let testCaseName = $0.key
                let tests = $0.value.tests
                let allTestsList = $0.value.allTestsList
                
                for test in tests {
                    guard allTestsList.contains(test) else {
                        erroneousTestcases.append((testCaseName, tests))
                        break
                    }
                }
            }
        }
        
        return erroneousTestcases
    }
    
    func correctAllTests(for module: String, given tests: [String]) -> String {
        var result = "\n"
        
        result.append("static var allTests = [\n")
        
        tests.forEach {
            result.append("    (\"\($0)\", \($0)),\n")
        }
    
        result.append("]")
        
        return result
    }
    
    func printCorrectLinuxMain(
        testModules: [String],
        missingTestModules: [String],
        testCases: [String],
        missingTestCases: [String]
    ) {
        console.print("import XCTest\n")
        
        testModules.forEach {
            let correctModule = "@testable import \($0)"
            if missingTestModules.contains($0) {
                //for green text
                console.success(correctModule)
            } else {
                console.print(correctModule)
            }
        }
        
        console.print("\nXCTMain([")
        
        testCases.forEach {
            let correctTestCase = "    testCase(\($0).allTests),"
            if missingTestCases.contains($0) {
                //for green text
                console.success(correctTestCase)
            } else {
                console.print(correctTestCase)
            }
        }
        
        console.print("])\n")
    }
}

struct LinuxMain {
    let url: URL
    var rawBytes: Bytes
    var moduleImports: [String]
    var testCases: [String]
    
    init(url: URL) throws {
        self.url = url
        moduleImports = []
        testCases = []
        rawBytes = try DataFile().load(path: url.path)
    }
}

struct TestFile {
    let url: URL
    var rawBytes: Bytes
    var testCases: [String: TestCase]
    
    init(url: URL) throws {
        self.url = url
        testCases = [:]
        rawBytes = try DataFile().load(path: url.path)
    }
}

struct TestCase {
    var allTestsList: [String]
    var tests: [String]
}

extension Sequence where Iterator.Element == TestFile {
    var testCases: [String] {
        var _testCases: [String] = []
        
        self.forEach {
            $0.testCases.forEach {
                _testCases.append($0.key)
            }
        }
        
        return _testCases
    }
}
