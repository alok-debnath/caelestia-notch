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

    // The shelf's rows, as a real ListModel rather than a JS array.
    //
    // The array was simpler and it made every change destroy and rebuild every
    // card: a probe coming back, a reorder committing, one file being taken
    // off. A ListModel is reconciled instead -- rows that are still wanted are
    // moved, not recreated -- so a card keeps its delegate, and a reorder
    // slides rather than blinking.
    readonly property ListModel model: ListModel {}

    function get(index: int): var {
        return index >= 0 && index < model.count ? model.get(index) : null;
    }

    function row(path: string): var {
        const probed = root.probed[path] ?? {};
        const mime = probed.mime ?? "";
        const fileName = root.name(path);
        return {
            path,
            uri: `file://${path}`,
            fileName,
            displayName: root.shorten(fileName),
            directory: mime === "inode/directory",
            mime,
            exists: probed.exists !== false,
            // An absolute path to a file in the icon theme, found by the probe
            // below rather than by QIcon: see `probeScript`.
            iconSource: probed.icon ? `file://${probed.icon}` : ""
        };
    }

    // Bring the model in line with `paths`, touching as little as possible:
    // drop what is gone, move what has shifted, insert only what is new.
    function syncModel(): void {
        const wanted = adapter.paths;

        for (let i = model.count - 1; i >= 0; i--)
            if (!wanted.includes(model.get(i).path))
                model.remove(i);

        for (let i = 0; i < wanted.length; i++) {
            const path = wanted[i];
            let at = -1;
            for (let j = i; j < model.count; j++)
                if (model.get(j).path === path) {
                    at = j;
                    break;
                }

            if (at === -1)
                model.insert(i, row(path));
            else if (at !== i)
                model.move(at, i, 1);
        }
    }

    // Probe results land on the rows that changed rather than rebuilding them.
    function applyProbe(): void {
        for (let i = 0; i < model.count; i++) {
            const current = model.get(i);
            const next = row(current.path);
            if (current.iconSource !== next.iconSource)
                model.setProperty(i, "iconSource", next.iconSource);
            if (current.mime !== next.mime)
                model.setProperty(i, "mime", next.mime);
            if (current.directory !== next.directory)
                model.setProperty(i, "directory", next.directory);
            if (current.exists !== next.exists)
                model.setProperty(i, "exists", next.exists);
        }
    }

    // Tide's display name: 22 characters, and past that the middle is dropped
    // rather than the tail, so the extension survives.
    function shorten(fileName: string): string {
        return fileName.length <= 22 ? fileName : `${fileName.slice(0, 13)}…${fileName.slice(-8)}`;
    }

    // What the probe found, keyed by path: `{ mime, icon, exists }`. Not
    // persisted -- it is cheap to re-derive, and a file's type can change
    // under us -- but kept across list changes, so reordering the shelf does
    // not send every file back through the probe.
    property var probed: ({})

    readonly property Process probe: Process {
        // Which paths this run was asked about, in order. Kept here rather
        // than read off `paths` when the reply lands, because the list can
        // have moved on by then.
        property var asked: []

        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.length > 0);
                const asked = root.probe.asked;
                const next = Object.assign({}, root.probed);

                for (let i = 0; i < asked.length && i < lines.length; i++) {
                    const parts = lines[i].split("\t");
                    next[asked[i]] = {
                        mime: parts[0] ?? "",
                        icon: parts[1] ?? "",
                        exists: parts[2] === "1"
                    };
                }

                root.probed = next;
                root.applyProbe();

                // Only on a probe that answered for every path it was asked
                // about. Starting a second probe aborts the first, and the
                // aborted one arrives with no lines at all -- consuming the
                // request on that reply is why nothing was ever pruned.
                if (root.pruning && lines.length === asked.length) {
                    root.pruning = false;
                    const alive = root.paths.filter(path => next[path]?.exists !== false);
                    if (alive.length !== root.paths.length)
                        adapter.paths = alive;
                }
            }
        }
    }

    // One process for the whole shelf: each file's mime type, and the icon
    // file that goes with it.
    //
    // The icon is looked up by walking the theme directories by hand rather
    // than by asking `Quickshell.iconPath`, which is Tide's approach too (its
    // C++ has a `findIconFile` that does the same walk). The reason is that
    // Qt only ever sees whatever icon theme the platform theme hands it, and
    // in this session that is nothing: application icons resolve because they
    // live in hicolor, while every mime and folder icon comes back empty even
    // though the files are sitting in the configured theme. Searching the
    // theme ourselves is the only way the shelf gets real file icons.
    //
    // Bash rather than sh, and one `file` call for the whole batch rather than
    // an `xdg-mime` per path: a shelf of twenty files used to be twenty
    // processes. `file` reports `inode/directory` for a directory too, so it
    // answers both questions at once, and the icon search is memoised by mime
    // so a shelf full of text files walks the theme exactly once.
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

        declare -A seen
        mapfile -t mimes < <(file --mime-type -b -- "$@" 2>/dev/null)

        i=0
        for p; do
            mime="\${mimes[i]}"
            i=$((i + 1))
            # A missing file makes the mime lookup print its complaint on
            # stdout, which still has a slash in it and so still looks like a
            # mime type.
            [ -e "$p" ] && exists=1 || exists=0
            case "$mime" in
                */*) [ "$exists" = 1 ] || mime=application/octet-stream ;;
                *) mime=application/octet-stream ;;
            esac

            if [ -n "\${seen[$mime]+set}" ]; then
                icon="\${seen[$mime]}"
            elif [ "$mime" = inode/directory ]; then
                icon=$(find_icon folder inode-directory || true)
                seen[$mime]=$icon
            else
                dashed=\${mime//\\//-}
                generic="\${mime%%/*}-x-generic"
                icon=$(find_icon "$dashed" "$generic" text-x-generic || true)
                seen[$mime]=$icon
            fi

            printf '%s\\t%s\\t%s\\n' "$mime" "$icon" "$exists"
        done
    `

    // Only what has not been seen before, unless a refresh asked for the lot:
    // reordering the shelf changes `paths`, and re-probing every file for a
    // move that changed nothing about any of them was pure waste.
    function probeTypes(): void {
        const wanted = pruning ? paths : paths.filter(path => !(path in probed));
        if (wanted.length === 0) {
            if (paths.length === 0)
                probed = ({});
            return;
        }

        probe.running = false;
        probe.asked = wanted;
        probe.command = ["bash", "-c", probeScript, "bash", ...wanted];
        probe.running = true;
    }

    onPathsChanged: {
        syncModel();
        probeTypes();
    }

    Component.onCompleted: {
        syncModel();
        probeTypes();
    }

    // `var`, not `string`/`list<string>`: a drop hands over QUrls, and letting
    // QML coerce those through a typed parameter quietly produced nothing at
    // all -- the drop landed, the handler ran, and no file was ever added.
    // Converting by hand is the whole fix.
    //
    // Everything goes through `addAll`, and `addAll` writes the list exactly
    // once. Adding one path at a time lost files out of a multi-file drop:
    // the store is a watched FileView, so every write comes back round as a
    // file change and a reload, and the next `[...adapter.paths, path]` in
    // the loop could be built on a list that had not caught up yet. Four
    // folders dropped together arrived as three.
    function addAll(urls: var): void {
        const next = [...adapter.paths];

        for (const url of (urls ?? [])) {
            // Trailing carriage returns are real: a text/uri-list payload is
            // CRLF-separated by spec, and one that survived into a stored
            // path made every later use of it -- opening, copying, dragging
            // the card back out -- fail with "no such file".
            const text = String(url ?? "").trim();
            if (!text)
                continue;

            const path = Paths.toLocalFile(text);
            if (!path || next.includes(path))
                continue;

            next.push(path);
        }

        if (next.length !== adapter.paths.length)
            adapter.paths = next;
    }

    function add(url: var): void {
        addAll([url]);
    }

    // Raw text/uri-list or x-special/gnome-copied-files payload: one URI per
    // line, blank lines and comments (#...) skipped, a leading "copy"/"cut"
    // action line (gnome-copied-files) skipped too.
    function addUriList(data: string): void {
        addAll(data.split(/\r?\n/).map(line => line.trim()).filter(uri => uri && !uri.startsWith("#") && uri !== "copy" && uri !== "cut"));
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
            onStreamFinished: root.addUriList(text)
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

    // Drops whatever is no longer on disk, which Tide re-runs every time the
    // shelf is shown; so does ours. The probe already stats each file, so the
    // pruning rides along with it.
    property bool pruning: false

    function refresh(): void {
        pruning = true;
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
