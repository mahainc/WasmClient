import Foundation
import PackagePlugin

@main
struct MergeFlowKitModulesPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let packageDir = context.package.directoryURL
        let script = packageDir.appending(path: "scripts/merge-flowkit-modules.sh")
        // Write to /tmp — allowed by Xcode's sandbox for build plugins.
        // The -I flag in Package.swift points here too.
        let mergedDir = "/tmp/wasmclient-flowkit-modules"

        return [
            .prebuildCommand(
                displayName: "Merge FlowKit Sub-Module Interfaces",
                executable: URL(filePath: "/bin/bash"),
                arguments: [script.path, packageDir.path, mergedDir],
                outputFilesDirectory: context.pluginWorkDirectoryURL
            ),
        ]
    }
}
