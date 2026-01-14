import AppKit
import ArgumentParser
import Foundation

@main
struct FolderIcon: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Set folder icons from embedded icon files",
        usage: """
            foldericon <folders>...
            foldericon --all <parent-folder>
            """,
        examples: [
            "foldericon ~/Projects/MyApp",
            "foldericon ~/Projects/Pkg1 ~/Projects/Pkg2",
            "foldericon --all ~/Projects/Packages"
        ]
    )

    @Flag(name: .long, help: "Process all subdirectories in the given folder")
    var all = false

    @Flag(name: .long, help: "Skip adding Icon? to .gitignore")
    var skipGitignore = false

    @Flag(name: .shortAndLong, help: "Remove folder icon instead of setting it")
    var remove = false

    @Option(name: .shortAndLong, help: "Custom icon file path (overrides auto-detection)")
    var icon: String?

    @Argument(help: "Folder path(s) to process")
    var folders: [String]

    func run() throws {
        let foldersToProcess: [URL]

        if all {
            guard folders.count == 1 else {
                throw ValidationError("--all requires exactly one parent folder")
            }
            let parent = URL(fileURLWithPath: folders[0]).standardizedFileURL
            let contents = try FileManager.default.contentsOfDirectory(
                at: parent,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            foldersToProcess = contents.filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            }
        } else {
            foldersToProcess = folders.map { URL(fileURLWithPath: $0).standardizedFileURL }
        }

        for folder in foldersToProcess {
            processFolder(folder)
        }
    }

    private func processFolder(_ folder: URL) {
        let name = folder.lastPathComponent

        guard FileManager.default.fileExists(atPath: folder.path) else {
            print("✗ \(name) (not found)")
            return
        }

        if remove {
            if NSWorkspace.shared.setIcon(nil, forFile: folder.path, options: []) {
                print("✓ \(name) (icon removed)")
            } else {
                print("✗ \(name) (failed to remove icon)")
            }
            return
        }

        let iconURL: URL?
        if let customIcon = icon {
            iconURL = URL(fileURLWithPath: customIcon)
        } else {
            iconURL = findIcon(in: folder)
        }

        guard let iconURL, FileManager.default.fileExists(atPath: iconURL.path) else {
            print("~ \(name) (no icon found)")
            return
        }

        guard let image = NSImage(contentsOf: iconURL) else {
            print("✗ \(name) (couldn't load icon)")
            return
        }

        if NSWorkspace.shared.setIcon(image, forFile: folder.path, options: []) {
            if !skipGitignore {
                addToGitignore(folder)
            }
            print("✓ \(name)")
        } else {
            print("✗ \(name) (failed to set icon)")
        }
    }

    private func findIcon(in folder: URL) -> URL? {
        let locations = [
            "assets/icon.png",
            "resources/icon.png",
            "resources/icon/icon.png",
            "resources/icons/icon.png",
            "Resources/icon.png",
            "Resources/icon/icon.png",
            "Resources/Icon.png",
            "icon.png"
        ]

        for location in locations {
            let url = folder.appendingPathComponent(location)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // Fallback: search for icon.png
        if let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let path = fileURL.path
                if path.contains(".build") || path.contains("node_modules") || path.contains("checkouts") {
                    continue
                }
                if fileURL.lastPathComponent == "icon.png" {
                    return fileURL
                }
            }
        }

        return nil
    }

    private func addToGitignore(_ folder: URL) {
        let gitignore = folder.appendingPathComponent(".gitignore")
        let entry = "Icon?"
        let content = "\n# macOS folder icon\n\(entry)\n"

        if FileManager.default.fileExists(atPath: gitignore.path) {
            guard let existing = try? String(contentsOf: gitignore, encoding: .utf8) else { return }
            if existing.contains("Icon") { return }
            try? content.append(to: gitignore)
        } else {
            try? content.write(to: gitignore, atomically: true, encoding: .utf8)
        }
    }
}

extension String {
    func append(to url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        handle.seekToEndOfFile()
        handle.write(self.data(using: .utf8)!)
        handle.closeFile()
    }
}

extension CommandConfiguration {
    init(abstract: String, usage: String, examples: [String]) {
        self.init(
            abstract: abstract,
            usage: usage,
            discussion: "Examples:\n  " + examples.joined(separator: "\n  ")
        )
    }
}
