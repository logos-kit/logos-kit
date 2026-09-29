import QtQuick
import QtQuick.Layouts

// From 21st.dev cnippet-dev/toast (id 24297, a Sonner-style stack) and
// framecn/toast-notification (id 19994, the spring-in):
// https://21st.dev/@cnippet-dev/components/toast
// Put one ToastHost over the whole window (anchors.fill: parent). Toasts
// stack at the bottom: the front one full size, up to two peeking behind
// (scale −6% and 10 px up each). Hovering expands the stack into a list.
// Enter from below and exit are 500 ms on Sonner's curve; auto-dismiss
// pauses while hovered; swipe sideways to dismiss.
//
//   host.show({ title, body?, tone: ok|danger|warn|info|pending, ms?, action?, onAction? })
//   returns an id; host.update(id, {...}) and host.dismiss(id) for pending → done.
Item {
    id: host
    property int maxVisible: 3
    property int gap: 10
    property int inset: 16
    property int toastWidth: Math.min(380, width - 2 * inset)
    property bool expanded: hover.hovered
    property int _next: 1
    property var _actions: ({})
    readonly property int count: list.count
    z: 1000

    ListModel { id: list }

    function show(t) {
        var id = _next++
        var tone = t.tone || "info"
        if (t.onAction) _actions[id] = t.onAction
        list.insert(0, { tid: id, title: t.title || "", body: t.body || "", tone: tone,
                         ms: t.ms === undefined ? (tone === "pending" ? 0 : 4200) : t.ms,
                         action: t.action || "", closing: false })
        // Beyond the visible stack, retire the oldest.
        for (var i = maxVisible + 1; i < list.count; i++) list.setProperty(i, "closing", true)
        return id
    }
    function _row(id) { for (var i = 0; i < list.count; i++) if (list.get(i).tid === id) return i; return -1 }
    function update(id, patch) {
        var r = _row(id); if (r < 0) return
        for (var k in patch) if (k !== "onAction") list.setProperty(r, k, patch[k])
        if (patch.tone && patch.tone !== "pending" && patch.ms === undefined) list.setProperty(r, "ms", 4200)
        if (patch.onAction) _actions[id] = patch.onAction
    }
    function dismiss(id) { var r = _row(id); if (r >= 0) list.setProperty(r, "closing", true) }
    function _remove(id) { var r = _row(id); if (r >= 0) list.remove(r); delete _actions[id] }

    HoverHandler { id: hover; enabled: list.count > 0 }

    Repeater {
        model: list
        delegate: Toast {
            id: tst
            required property int index
            required property int tid
            required property string title
            required property string body
            required property string tone
            required property int ms
            required property string action
            required property bool closing
            data_: ({ title: title, body: body, tone: tone, action: action })
            width: host.toastWidth
            x: (host.width - width) / 2 + swipeX
            // Stacked: each card behind rises 10 px and shrinks 6%.
            readonly property real stackY: host.height - host.inset - height
                - (host.expanded ? index * (height + host.gap) : index * 10)
            y: closing ? host.height + 8 : entered ? stackY : host.height + 8
            scale: host.expanded ? 1 : Math.max(0.82, 1 - index * 0.06)
            opacity: closing || index >= host.maxVisible ? 0 : 1
            z: 100 - index
            transformOrigin: Item.Bottom
            onDismissRequested: host.dismiss(tid)
            onActionRequested: { var f = host._actions[tid]; if (f) f(); host.dismiss(tid) }
            onClosingChanged: if (closing) reaper.start()
            Timer { id: reaper; interval: Theme.dSlow; onTriggered: host._remove(tst.tid) }
            Timer {
                running: tst.ms > 0 && !host.expanded && tst.index === 0 && !tst.closing
                interval: tst.ms
                onTriggered: host.dismiss(tst.tid)
            }
        }
    }
}
