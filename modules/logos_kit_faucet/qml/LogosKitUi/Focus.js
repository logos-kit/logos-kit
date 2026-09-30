.pragma library
// Focus trapping for sheets and dialogs: Tab and Shift+Tab stay inside the
// open overlay, the first control gets focus when it opens, and focus goes
// back where it was when it closes.

function inside(item, scope) {
    for (var p = item; p; p = p.parent) if (p === scope) return true
    return false
}

function usable(item) {
    for (var p = item; p; p = p.parent) if (!p.visible || !p.enabled) return false
    return true
}

// Move focus to the next (or previous) focusable item within `scope`.
function cycle(scope, win, forward) {
    var start = win && win.activeFocusItem ? win.activeFocusItem : scope
    var n = start
    for (var i = 0; i < 800; i++) {
        n = n.nextItemInFocusChain(forward)
        if (!n || n === start) break
        if (n !== scope && inside(n, scope) && usable(n)) {
            n.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason)
            return true
        }
    }
    return false
}

function first(scope) {
    var n = scope
    for (var i = 0; i < 800; i++) {
        n = n.nextItemInFocusChain(true)
        if (!n || n === scope) break
        if (inside(n, scope) && usable(n)) { n.forceActiveFocus(Qt.TabFocusReason); return n }
    }
    scope.forceActiveFocus()
    return null
}
