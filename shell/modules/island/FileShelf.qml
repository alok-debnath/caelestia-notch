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
    readonly property int count: adapter.paths.length

    // Tide's own model rows, built here instead of in C++. Everything the
    // shelf draws comes from one of these, so a card never has to go and ask
    // the singleton four separate questions about the same file.
    readonly property list<var> entries: adapter.paths.map(path => {
        const probed = root.probed[path] ?? {};
        const mime = probed.mime ?? "";
        const directory = mime === "inode/directory";
        const fileName = root.name(path);
        return {
            path,
            uri: `file://${path}`,
            fileName,
            displayName: root.shorten(fileName),
            directory,
            mime,
            // An absolute path to a file in the icon theme, found by the probe
            // below rather than by QIcon: see `probeTypes`.
            iconSource: probed.icon ? `file://${probed.icon}` : ""
        };
    })

    function get(index: int): var {
        return index >= 0 && index < entries.length ? entries[index] : null;
    }

    // Tide's display name: 22 characters, and past that the middle is dropped
    // rather than the tail, so the extension survives.
    function shorten(fileName: string): string {
        return fileName.length <= 22 ? fileName : `${fileName.slice(0, 13)}\u2026${fileName.slice(-8)}`;
    }

    // What the probe found, keyed by path: `{ mime, icon }`. Not persisted --
    // it is cheap to re-derive, and a file's type can change under us.
    property var probed: ({})

    readonly property Process probe: Process {
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.length > 0);
                const next = {};
                for (let i = 0; i < root.paths.length && i < lines.length; i++) {
                    const parts = lines[i].split("\t");
                    next[root.paths[i]] = {
                        mime: parts[0] ?? "",
                        icon: parts[1] ?? ""
                    };
                }
                root.probed = next;
            }
        }
    }

    // One process for the whole shelf: the file's mime type, and the icon file
    // that goes with it.
    //
    // The icon is looked up by walking the theme directories by hand rather
    // than by asking `Quickshell.iconPath`, which is Tide's approach too (its
    // C++ has a `findIconFile` that does the same walk). The reason is that
    // Qt only ever sees whatever icon theme the platform theme hands it, and
    // in this session that is nothing: application icons resolve because they
    // live in hicolor, while every mime and folder icon comes back empty even
    // though the files are sitting in the configured theme. Searching the
    // theme ourselves is the only way the shelf gets real file icons.
    readonly property string probeScript: `
        theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
        roots="$HOME/.local/share/icons /usr/share/icons"
        themes="$theme Papirus-Dark Papirus Adwaita hicolor"
        sizes="scalable 512x512 256x256 128x128 96x96 64x64 48x48 32x32 24x24 22x22 16x16 512 256 128 64 48 32 24 22 16"
        sections="mimes mimetypes places"

        find_icon() {
            for t in $themes; do
                [ -n "$t" ] || continue
                for r in $roots; do
                    d="$r/$t"
                    [ -d "$d" ] || continue
                    for n in "$@"; do
                        for sz in $sizes; do
                            for sec in $sections; do
                                for cand in "$d/$sz/$sec/$n.svg" "$d/$sz/$sec/$n.png" "$d/$sec/$sz/$n.svg" "$d/$sec/$sz/$n.png"; do
                                    [ -f "$cand" ] && { printf '%s' "$cand"; return 0; }
                                done
                            done
                        done
                    done
                done
            done
            return 1
        }

        for p; do
            if [ -d "$p" ]; then
                mime=inode/directory
                icon=$(find_icon folder inode-directory || true)
            else
                mime=$(xdg-mime query filetype "$p" 2>/dev/null)
                [ -n "$mime" ] || mime=application/octet-stream
                dashed=$(printf '%s' "$mime" | tr '/' '-')
                generic="$(printf '%s' "$mime" | cut -d/ -f1)-x-generic"
                icon=$(find_icon "$dashed" "$generic" text-x-generic || true)
            fi
            printf '%s\t%s\n' "$mime" "$icon"
        done
    `

    function probeTypes(): void {
        if (paths.length === 0) {
            probed = ({});
            return;
        }
        probe.running = false;
        probe.command = ["sh", "-c", probeScript, "sh", ...paths];
        probe.running = true;
    }

    onPathsChanged: probeTypes()
    Component.onCompleted: probeTypes()

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

    // Raw text/uri-list or x-special/gnome-copied-files payload: one URI per
    // line, blank lines and comments (#...) skipped, a leading "copy"/"cut"
    // action line (gnome-copied-files) skipped too.
    function addUriList(data: string): void {
        for (const line of data.split(/\r?\n/)) {
            const uri = line.trim();
            if (!uri || uri.startsWith("#") || uri === "copy" || uri === "cut")
                continue;
            add(uri);
        }
    }

    // Alongside dropping: copy a file in the file manager (which puts
    // text/uri-list on the clipboard) and pull it from there. Tide has no
    // such fallback -- this is the path that carried the shelf while drag was
    // landing on the wrong surface -- and it is still the easier one when the
    // notch is at rest.
    function pasteFromClipboard(): void {
        pasteProc.running = true;
    }

    readonly property Process pasteProc: Process {
        command: ["wl-paste", "--type", "text/uri-list"]

        stdout: StdioCollector {
            onStreamFinished: root.addAll(text.split("\n").filter(l => l.length > 0))
        }
    }

    // Reordering, which is what Tide's shelf drag does while the pointer is
    // still over the tray.
    function move(from: int, to: int): void {
        if (from === to || from < 0 || to < 0 || from >= adapter.paths.length || to >= adapter.paths.length)
            return;
        const next = [...adapter.paths];
        next.splice(to, 0, ...next.splice(from, 1));
        adapter.paths = next;
    }

    function removeAt(index: int): void {
        if (index < 0 || index >= adapter.paths.length)
            return;
        adapter.paths = adapter.paths.filter((_, i) => i !== index);
    }

    // Drops whatever is no longer on disk. Tide re-runs this every time the
    // shelf is shown; so does ours.
    function refresh(): void {
        probeTypes();
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

    // As a URI, not a plain path: most apps (file managers, chat clients,
    // browser upload fields) only accept a paste as an actual file if the
    // clipboard offers text/uri-list, not text/plain.
    function copy(path: string): void {
        Quickshell.execDetached(["wl-copy", "--type", "text/uri-list", `file://${path}`]);
    }

    // For Item.Drag.mimeData on a shelf card, so dragging it onto another
    // app's window is a real Wayland drag, not just a clipboard paste.
    function mimeData(path: string): var {
        const url = `file://${path}`;
        return {
            "text/uri-list": `${url}\r\n`,
            "text/plain": path,
            "x-special/gnome-copied-files": `copy\n${url}\n`
        };
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
