.pragma library
// Pure helpers for the wallet UI: amounts as decimal strings (u128 never
// becomes a JS number), short ids, times, and the error catalog
// (docs/design/ux-spec.md §11). No BigInt, no Intl (QML V4).

// Native LEZ has no decimals on chain; amounts are shown in base units.
var NATIVE_DECIMALS = 0

function isDigits(s) { return typeof s === "string" && /^[0-9]+$/.test(s) }

// "1234567" -> "1,234,567" (decimals: shift the point first).
function amount(raw, decimals) {
    if (raw === null || raw === undefined || raw === "") return "—"
    var s = String(raw)
    if (!isDigits(s)) return "—"
    s = s.replace(/^0+(?=\d)/, "")
    var d = decimals || 0
    var whole = s, frac = ""
    if (d > 0) {
        while (s.length <= d) s = "0" + s
        whole = s.substring(0, s.length - d)
        frac = s.substring(s.length - d).replace(/0+$/, "")
    }
    var out = ""
    for (var i = 0; i < whole.length; i++) {
        if (i > 0 && (whole.length - i) % 3 === 0) out += ","
        out += whole.charAt(i)
    }
    return frac ? out + "." + frac : out
}

// Keypad text ("12", "12.") -> base units, or "" if not a valid amount.
function toBase(text, decimals) {
    var t = String(text || "").replace(/,/g, "")
    if (!/^[0-9]*\.?[0-9]*$/.test(t) || t === "" || t === ".") return ""
    var parts = t.split(".")
    var whole = parts[0] || "0", frac = parts[1] || ""
    var d = decimals || 0
    if (frac.length > d) return ""
    while (frac.length < d) frac += "0"
    var v = (whole + frac).replace(/^0+(?=\d)/, "")
    return v === "0" ? "" : v
}

// Compare decimal strings: -1, 0, 1.
function cmp(a, b) {
    a = String(a).replace(/^0+(?=\d)/, ""); b = String(b).replace(/^0+(?=\d)/, "")
    if (a.length !== b.length) return a.length < b.length ? -1 : 1
    return a < b ? -1 : a > b ? 1 : 0
}

function short(id) {
    if (!id) return ""
    var s = String(id)
    return s.length > 14 ? s.substring(0, 6) + "…" + s.substring(s.length - 4) : s
}

function shortHash(h) {
    if (!h) return ""
    var s = String(h)
    return s.length > 22 ? s.substring(0, 10) + "…" + s.substring(s.length - 8) : s
}

function mmss(secs) {
    if (secs === null || secs === undefined || secs < 0) return "—"
    var m = Math.floor(secs / 60), s = Math.floor(secs % 60)
    return m + ":" + (s < 10 ? "0" : "") + s
}

function ago(ms, nowMs) {
    if (!ms) return ""
    var d = Math.max(0, Math.round(((nowMs || Date.now()) - ms) / 1000))
    if (d < 10) return "just now"
    if (d < 60) return d + " s ago"
    if (d < 3600) return Math.floor(d / 60) + " min ago"
    return Math.floor(d / 3600) + " h ago"
}

// Account display name: its label, else "Public/Private account".
function accountName(a) {
    if (!a) return ""
    return a.label || ((a.kind === "private" ? "Private" : "Public") + " " + short(a.accountId))
}

var ERRORS = {
    "4001": "Request declined",
    "4100": "This app isn't connected to that account",
    "4900": "Wallet disconnected",
    "4901": "Can't reach the network",
    "4902": "That network isn't the one this wallet is on",
    "5720": "This request was already sent",
    "5730": "That request is gone",
    "6100": "This account type can't do that",
    "6101": "Couldn't simulate this transaction",
    "6102": "Proof failed: nothing was sent. Nothing was spent.",
    "6103": "The sequencer rejected the transaction",
    "6104": "The app sent a transaction the wallet can't build",
    "6106": "Something changed since you approved. Please review again",
    "6107": "Finish or cancel the open request first",
    "6108": "The wallet is busy; try again",
    "6109": "Not available on this network yet"
}

// Copy for an error object {code, message}: the catalog line, and the
// wallet's own detail underneath when it adds something.
function errorText(e) {
    if (!e) return ""
    if (typeof e === "string") return e
    var head = ERRORS[String(e.code)] || ""
    var msg = e.message ? String(e.message) : ""
    if (!head) return msg || "Something went wrong"
    if (!msg || msg.toLowerCase() === head.toLowerCase() || e.code === 6107 || e.code === 6108) return head
    return head + ". " + msg.charAt(0).toUpperCase() + msg.substring(1)
}

var LIFECYCLE = {
    "awaiting_approval": "Awaiting approval",
    "building": "Building",
    "proving": "Proving",
    "signing": "Signing",
    "submitted": "Waiting for block",
    "included": "Included",
    "rejected": "Rejected",
    "dropped": "Not sent",
    "expired": "Expired"
}

// Row tag: [text, tone] with tone in ok|pending|unconfirmed|private|danger.
function statusTag(s) {
    if (!s) return ["", "pending"]
    if (s.lifecycle === "included") {
        if (s.outcome === "success") return ["Confirmed", "ok"]
        if (s.outcome === "failure") return ["Failed", "danger"]
        return ["Not confirmed yet", "unconfirmed"]
    }
    if (s.lifecycle === "proving") return ["Proving", "private"]
    if (s.lifecycle === "dropped") return ["Not sent", "danger"]
    if (s.lifecycle === "rejected") return ["Declined", "pending"]
    if (s.lifecycle === "expired") return ["Expired", "pending"]
    return [LIFECYCLE[s.lifecycle] || s.lifecycle, "pending"]
}

function isFinal(s) {
    return !!s && ["included", "rejected", "dropped", "expired"].indexOf(s.lifecycle) >= 0
}

// Bar that eases toward 90% over the ETA and never goes backwards.
function proofProgress(s) {
    if (!s) return 0
    if (s.lifecycle === "signing" || s.lifecycle === "submitted") return 0.95
    if (isFinal(s)) return 1
    if (s.lifecycle !== "proving") return 0.04
    var total = s.etaTotalSeconds || 330
    var elapsed = Math.max(0, ((s.nowMs || Date.now()) - s.phaseStartedMs) / 1000)
    return 0.05 + 0.85 * (1 - Math.exp(-2.2 * elapsed / total))
}

function password_ok(p) { return typeof p === "string" && p.length >= 8 }

// Rough password strength 0..4 for the meter.
function strength(p) {
    if (!p) return 0
    var score = 0
    if (p.length >= 8) score++
    if (p.length >= 12) score++
    if (/[A-Z]/.test(p) && /[a-z]/.test(p)) score++
    if (/[0-9]/.test(p) && /[^A-Za-z0-9]/.test(p)) score++
    return score
}
