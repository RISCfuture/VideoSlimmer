extension Array where Element: Hashable {
    func removingDuplicates() -> Array {
        var seen = Set<Element>()
        return self.filter { element in
            if seen.contains(element) { return false }
            seen.insert(element)
            return true
        }
    }
    
    mutating func removeDuplicates() {
        var seen = Set<Element>()
        removeAll(where: { element in
            if seen.contains(element) { return true }
            seen.insert(element)
            return false
        })
    }
}
