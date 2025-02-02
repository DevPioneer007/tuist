import Foundation
import TSCBasic
import TuistCore
import TuistGraph
import TuistLoader
import TuistSupport

public protocol CleanCategory: ExpressibleByArgument & CaseIterable {
    func directory(rootDirectory: AbsolutePath?, cacheDirectory: AbsolutePath) throws -> AbsolutePath?
}

public enum TuistCleanCategory: CleanCategory {
    public static let allCases = CacheCategory.allCases.map { .global($0) } + [Self.dependencies]

    /// The global cache
    case global(CacheCategory)

    /// The local dependencies cache
    case dependencies

    public var defaultValueDescription: String {
        switch self {
        case let .global(cacheCategory):
            return cacheCategory.rawValue
        case .dependencies:
            return "dependencies"
        }
    }

    public init?(argument: String) {
        if let cacheCategory = CacheCategory(rawValue: argument) {
            self = .global(cacheCategory)
        } else if argument == "dependencies" {
            self = .dependencies
        } else {
            return nil
        }
    }

    public func directory(rootDirectory: AbsolutePath?, cacheDirectory: AbsolutePath) throws -> TSCBasic.AbsolutePath? {
        switch self {
        case let .global(category):
            return CacheDirectoriesProvider.tuistCacheDirectory(for: category, cacheDirectory: cacheDirectory)
        case .dependencies:
            return rootDirectory?.appending(
                component: Constants.SwiftPackageManager.packageBuildDirectoryName
            )
        }
    }
}

final class CleanService {
    private let fileHandler: FileHandling
    private let rootDirectoryLocator: RootDirectoryLocating
    private let cacheDirectoriesProvider: CacheDirectoriesProviding
    init(
        fileHandler: FileHandling,
        rootDirectoryLocator: RootDirectoryLocating,
        cacheDirectoriesProvider: CacheDirectoriesProviding
    ) {
        self.fileHandler = fileHandler
        self.rootDirectoryLocator = rootDirectoryLocator
        self.cacheDirectoriesProvider = cacheDirectoriesProvider
    }

    public convenience init() {
        self.init(
            fileHandler: FileHandler.shared,
            rootDirectoryLocator: RootDirectoryLocator(),
            cacheDirectoriesProvider: CacheDirectoriesProvider()
        )
    }

    func run(
        categories: [some CleanCategory],
        path: String?
    ) throws {
        let resolvedPath = if let path {
            try AbsolutePath(validating: path, relativeTo: FileHandler.shared.currentPath)
        } else {
            FileHandler.shared.currentPath
        }

        let rootDirectory = rootDirectoryLocator.locate(from: resolvedPath)
        let cacheDirectory = try cacheDirectoriesProvider.cacheDirectory()

        for category in categories {
            if let directory = try category.directory(rootDirectory: rootDirectory, cacheDirectory: cacheDirectory),
               fileHandler.exists(directory)
            {
                try FileHandler.shared.delete(directory)
                logger.info("Successfully cleaned artifacts at path \(directory.pathString)", metadata: .success)
            } else {
                logger.info("There's nothing to clean for \(category.defaultValueDescription)")
            }
        }
    }
}
