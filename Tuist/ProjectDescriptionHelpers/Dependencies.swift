import ProjectDescription

public extension TargetDependency {
    static func packageDependency(name: String) -> TargetDependency {
        .package(product: name)
    }
}
