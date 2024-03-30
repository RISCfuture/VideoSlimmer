import Foundation

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var uniqueElements = Set<Element>()
        return filter { uniqueElements.insert($0).inserted }
    }
}
