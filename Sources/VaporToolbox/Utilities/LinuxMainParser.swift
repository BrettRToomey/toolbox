import Core

extension TestParser {
    static func parse(linuxMain: LinuxMain) throws -> LinuxMain {
        var linuxMain = linuxMain
        
        var parser = TestParser(scanner: Scanner(linuxMain.rawBytes))
        (linuxMain.moduleImports, linuxMain.testCases) = try parser.extractLinuxMain()
        
        return linuxMain
    }
}

extension TestParser {
    mutating func extractLinuxMain() throws -> ([String], [String]) {
        let testableBytes = "@testable".bytes
        let xcTestBytes = "XCTMain".bytes
        
        var moduleImports: [String] = []
        var testCases: [String] = []
        
        while scanner.peek() != nil {
            skipWhitespace()
            
            let substring = consume(until: Set(whitespace).union([.leftParenthesis]))
            
            if substring == testableBytes {
                moduleImports.append(extractTestableImport().string)
            } else if substring == xcTestBytes {
                testCases = extractLinuxTestCases().map { $0.string }
            }
            
            skip(until: Set(whitespace))
            
        }
        
        return (moduleImports, testCases)
    }
}

extension TestParser {
    mutating func extractTestableImport() -> Bytes {
        skipWhitespace()
        let importKeyword = consume(until: Set(whitespace))
        guard importKeyword == "import".bytes else {
            return []
        }
        
        skipWhitespace()
        return consume(until: Set(whitespace))
    }
    
    mutating func extractLinuxTestCases() -> [Bytes] {
        skip(until: [.leftSquareBracket])
        
        var testCases: [Bytes] = []
        
        while let byte = scanner.peek(), byte != .rightSquareBracket {
            skip(until: [.leftParenthesis, .rightSquareBracket])
            
            guard scanner.peek() != .rightSquareBracket else {
                break
            }
            
            scanner.pop()
            skipWhitespace()
            testCases.append(consume(until: [.period]))
        }
        return testCases
    }
}
