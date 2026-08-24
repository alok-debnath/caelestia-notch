pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Files parked on the notch.
//
// Tide's shelf is a C++ singleton with its own store; this is the same idea in
// QML -- a list of paths written to the shell's state directory, so what you
// dropped is still there after a restart. The shelf holds paths, never copies:
// removing something here never touches the file.
Singleton {
    id: root

    readonly property list<string> paths: adapter.paths

    function add(url: string): void {
        const path = Paths.toLocalFile(url);
        if (!path || adapter.paths.includes(path))
            return;
        adapter.paths = [...adapter.paths, path];
    }

    function addAll(urls: list<string>): void {
        for (const url of urls)
            add(url);
    }

    function remove(path: string): void {
        adapter.paths = adapter.paths.filter(p => p !== path);
    }

    function clear(): void {
        adapter.paths = [];
    }

    function open(path: string): void {
        Quickshell.execDetached(["xdg-open", path]);
    }

    function copy(path: string): void {
        Quickshell.execDetached(["wl-copy", path]);
    }

    function name(path: string): string {
        return path.slice(path.lastIndexOf("/") + 1);
    }

    // Enough of a guess to pick an icon; the shelf does not care what the file
    // actually is beyond that.
    function icon(path: string): string {
        const ext = path.slice(path.lastIndexOf(".") + 1).toLowerCase();
        if (["png", "jpg", "jpeg", "webp", "gif", "avif", "bmp", "svg"].includes(ext))
            return "image";
        if (["mp4", "mkv", "webm", "mov", "avi"].includes(ext))
            return "movie";
        if (["mp3", "flac", "ogg", "opus", "wav", "m4a"].includes(ext))
            return "music_note";
        if (["pdf", "epub"].includes(ext))
            return "picture_as_pdf";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar"].includes(ext))
            return "folder_zip";
        if (["txt", "md", "org", "log"].includes(ext))
            return "description";
        if (["sh", "py", "js", "ts", "qml", "cpp", "c", "h", "rs", "go", "json", "toml", "yaml", "yml"].includes(ext))
            return "code";
        return "draft";
    }

    function isImage(path: string): bool {
        return icon(path) === "image";
    }

    readonly property FileView storage: FileView {
        path: `${Paths.state}/shelf.json`

        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property list<string> paths: []
        }
    }
}
