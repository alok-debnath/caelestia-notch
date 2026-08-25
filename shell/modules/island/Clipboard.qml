pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Clipboard history, backed by cliphist -- same store the old `caelestia
// clipboard` CLI command used (fuzzel + cliphist under the hood), just
// surfaced as a real panel instead of a popup: image entries render instead
// of showing as an opaque "[[ binary data ... ]]" line, and delete/clear are
// buttons instead of a separate keybind into delete-mode.
Singleton {
    id: root

    readonly property list<var> entries: listProc.entries
    readonly property string thumbDir: `${Paths.state}/clipboard-thumbs`

    function refresh(): void {
        listProc.running = true;
    }

    function copy(entry: var): void {
        copyProc.line = entry.line;
        copyProc.running = true;
    }

    function remove(entry: var): void {
        removeProc.line = entry.line;
        removeProc.running = true;
    }

    function clear(): void {
        wipeProc.running = true;
    }

    function thumbPath(entry: var): string {
        return `${root.thumbDir}/${entry.id}.png`;
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.thumbDir]);
        refresh();
    }

    readonly property Process listProc: Process {
        id: listProc

        command: ["cliphist", "list"]

        property list<var> entries: []

        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = text.split("\n").filter(l => l.length > 0).map(line => {
                    const tab = line.indexOf("\t");
                    const id = line.slice(0, tab);
                    const preview = line.slice(tab + 1);
                    const image = preview.match(/^\[\[ binary data .* (png|jpe?g|gif|bmp|webp) (\d+)x(\d+) \]\]$/i);
                    return {
                        line,
                        id,
                        preview,
                        isImage: !!image,
                        width: image ? parseInt(image[2]) : 0,
                        height: image ? parseInt(image[3]) : 0
                    };
                });
                listProc.entries = parsed;
                for (const entry of parsed)
                    if (entry.isImage)
                        thumbProc.decode(entry);
            }
        }
    }

    // Decodes image entries to disk once, keyed by cliphist id, so re-opening
    // the panel doesn't re-decode everything that was already rendered.
    //
    // Queued one at a time rather than kicked off in parallel: reassigning
    // `command` on a Process that is still `running` restarts it with the
    // new command, killing the previous decode mid-write. With one shared
    // Process and a whole entry list to decode, that meant only the last
    // image in the list ever finished -- every earlier one was left as a
    // truncated (often empty) file, and `test -f` then saw that file and
    // skipped it forever.
    readonly property Process thumbProc: Process {
        id: thumbProc

        property list<var> queue: []

        function decode(entry: var): void {
            if (thumbProc.queue.some(e => e.id === entry.id))
                return;
            thumbProc.queue = [...thumbProc.queue, entry];
            if (!thumbProc.running)
                thumbProc.next();
        }

        function next(): void {
            if (thumbProc.queue.length === 0)
                return;
            const entry = thumbProc.queue[0];
            thumbProc.queue = thumbProc.queue.slice(1);
            command = ["bash", "-c", 'test -f "$2" || cliphist decode <<< "$1" > "$2"', "_", entry.line, root.thumbPath(entry)];
            running = true;
        }

        onExited: next()
    }

    readonly property Process copyProc: Process {
        id: copyProc

        property string line: ""

        command: ["bash", "-c", 'cliphist decode <<< "$1" | wl-copy', "_", line]
    }

    readonly property Process removeProc: Process {
        id: removeProc

        property string line: ""

        command: ["bash", "-c", 'cliphist delete <<< "$1"', "_", line]
        onExited: root.refresh()
    }

    readonly property Process wipeProc: Process {
        id: wipeProc

        command: ["bash", "-c", "cliphist wipe && rm -rf \"$1\" && mkdir -p \"$1\"", "_", root.thumbDir]
        onExited: root.refresh()
    }
}
