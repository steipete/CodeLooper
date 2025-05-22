import ProjectDescription

extension TargetDependency {
    public static func packageDependency(name: String) -> TargetDependency {
        return .package(product: name)
    }
}