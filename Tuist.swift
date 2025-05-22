import ProjectDescription

let config = Config(
    plugins: [],
    generationOptions: .options(
        resolveDependenciesWithSystemScm: false,
        disablePackageVersionLocking: false,
        clonedSourcePackagesDirPath: nil,
        staticSideEffectsWarningTargets: .all, 
        enforceExplicitDependencies: false,
        defaultConfiguration: nil,
        optionalAuthentication: false
    )
)