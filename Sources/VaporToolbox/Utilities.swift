import Core

public func +=(lhs: inout [String], rhs: String) {
    lhs.append(rhs)
}

public func +=(lhs: inout ArraySlice<String>, rhs: String) {
    lhs.append(rhs)
}

extension Sequence where Iterator.Element == Byte {
    func hasPrefix(_ prefix: Bytes) -> Bool {
        let array = Array(self)
        guard array.count >= prefix.count else {
            return false
        }
        
        for (index, item) in prefix.enumerated() {
            guard array[index] == item else { return false }
        }
        
        return true
    }
}
