import Core

let whitespace = " \n\t".bytes

extension Byte {
    static var leftBracket: Byte = 0x7B
}

struct TestParser {
    var scanner: Scanner<Byte>
    
    init(scanner: Scanner<Byte>) {
        self.scanner = scanner
    }
}

extension TestParser {
    static func parse(_ file: TestFile) throws -> TestFile {
        var file = file
        var parser = TestParser(scanner: Scanner(file.rawBytes))
        file.testCases = try parser.findTestCases()
        return file
    }
}

extension TestParser {
    mutating func findTestCases() throws -> ([String : TestCase]) {
        let classBytes = "class".bytes
        let funcBytes = "func".bytes
        let testBytes = "test".bytes
        let staticBytes = "static".bytes
        
        var testCases: [String: TestCase] = [:]
        
        while scanner.peek() != nil {
            skipWhitespace()
            
            let substring = consume(until: Set(whitespace))

            // `class`
            if substring == classBytes {
                if let testCaseName = isTestCase() {
                    assert(scanner.peek() == .leftBracket)
                    scanner.pop() // `{`
                    
                    var allTestsList: [String] = []
                    var tests: [String] = []
                    
                    //TODO(Brett): cleanup this entire loop
                    while scanner.peek() != nil {
                        skipWhitespace()
                        let substring = consume(until: Set(whitespace))
                        
                        if substring.elementsEqual(funcBytes) {
                            let funcName = extractFuncName()
                            if funcName.hasPrefix(testBytes) {
                                tests.append(funcName.string)
                            }
                        } else if substring.elementsEqual(staticBytes) {
                            if isAllTests() {
                                allTestsList = extractAllTests().map { $0.string }
                            }
                        }
                        
                        testCases[testCaseName.string] = TestCase(
                            allTestsList: allTestsList,
                            tests: tests
                        )
                        
                        skip(until: Set(whitespace))
                    }
                }
            }
            
            skip(until: Set(whitespace))
        }
        
        return testCases
    }
    
    mutating func extractClassName() -> Bytes {
        skipWhitespace()
        return consume(until: Set(whitespace).union([.colon, .leftBracket]))
    }
    
    mutating func extractProtocols() -> [Bytes] {
        scanner.pop() // `:`
        
        var protocols: [Bytes] = []
        
        while let byte = scanner.peek(), byte != .leftBracket {
            skipWhitespace()
            let name = consume(until: Set(whitespace).union([.comma, .leftBracket]))
            
            protocols.append(name)
            
            if scanner.peek() == .comma {
                scanner.pop()
            }
        }
        
        return protocols
    }
    
    mutating func extractFuncName() -> Bytes {
        skipWhitespace()
        return consume(until: Set(whitespace).union([.leftParenthesis]))
    }
    
    mutating func extractTests() -> [Bytes] {
        assert(scanner.peek() == .leftBracket)
        scanner.pop() // `{`
        
        let funcBytes = "func".bytes
        let testBytes = "test".bytes
        
        var tests: [Bytes] = []
        
        while scanner.peek() != nil {
            skipWhitespace()
            let substring = consume(until: Set(whitespace))
            if substring.elementsEqual(funcBytes) {
                let funcName = extractFuncName()
                if funcName.hasPrefix(testBytes) {
                    tests.append(funcName)
                }
            }
            skip(until: Set(whitespace))
        }
        
        return tests
    }
    
    mutating func extractAllTests() -> [Bytes] {
        skip(until: [.equals, .leftBracket])
        
        // presently `{` style definitions aren't supported.
        guard scanner.peek() == .equals else {
            return []
        }
        
        skip(until: [.leftSquareBracket])
        scanner.pop() // `[`
        
        var entries: [Bytes] = []
        
        while let byte =  scanner.peek(), byte != .rightSquareBracket {
            skip(until: [.comma, .rightSquareBracket])
            guard scanner.peek() != .rightSquareBracket else { continue }
            
            scanner.pop() // `,`
            skipWhitespace()
            let name = consume(until: Set(whitespace).union([.rightParenthesis]))
            entries.append(name)
            
            skip(until: [.leftParenthesis, .rightSquareBracket])
        }
        
        return entries
    }
    
    mutating func isAllTests() -> Bool {
        let letBytes = "let".bytes
        let varBytes = "var".bytes
        let allTestsBytes = "allTests".bytes
        
        skipWhitespace()
        let substring = consume(until: Set(whitespace))
        guard substring == letBytes || substring == varBytes else {
            return false
        }
        
        skipWhitespace()
        let variableName = consume(until: Set(whitespace).union([.colon, .leftBracket]))
        
        return variableName == allTestsBytes
    }
}

extension TestParser {
    mutating func isTestCase() -> Bytes? {
        let name = extractClassName()
        
        guard scanner.peek() == .colon else { return nil }
        
        let protocols = extractProtocols()
        
        let xcTestBytes = "XCTestCase".bytes
        guard protocols.contains(where: { $0.elementsEqual(xcTestBytes) }) else {
            return nil
        }
        
        return name
    }
}

extension TestParser {
    mutating func skip(until terminators: Set<Byte>) {
        while let byte = scanner.peek(), !terminators.contains(byte) {
            scanner.pop()
        }
    }
    
    mutating func skip(while bytes: Bytes) {
        while let byte = scanner.peek(), bytes.contains(byte) {
            scanner.pop()
        }
    }
    
    mutating func skipWhitespace() {
        skip(while: whitespace)
    }
    
    mutating func consume(until terminator: Byte) -> Bytes {
        var bytes: Bytes = []
        
        while let byte = scanner.peek(), byte != terminator {
            bytes.append(byte)
            scanner.pop()
        }
        
        return bytes
    }
    
    mutating func consume(until terminators: Set<Byte>) -> Bytes {
        var bytes: Bytes = []
        
        while let byte = scanner.peek(), !terminators.contains(byte) {
            bytes.append(byte)
            scanner.pop()
        }
        
        return bytes
    }
}
