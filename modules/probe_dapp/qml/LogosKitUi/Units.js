.pragma library
// Amount formatting. The native token shows in LGO, the official Logos way
// (logos-blockchain-ui#69): 1 LGO = 10^9 lepta. Lepta stay the wire format:
// balances, fees and faucet drops arrive and leave as lepta strings, and only
// the screen says LGO. A fungible token may declare its own `decimals` (0 if
// none). Amounts stay decimal strings end to end (u128 never becomes a JS
// number, and QML's V4 has no BigInt): the point is placed and read by
// slicing strings. Nothing is rounded and trailing zeros are cut, so one
// lepta reads "0.000000001", never a "0" that claims the balance is empty.

var SYMBOL = "LGO"
var DECIMALS = 9

function isDigits(s) { return typeof s === "string" && /^[0-9]+$/.test(s) }

// "1000000000" -> "1,000,000,000"
function group(raw) {
    var s = raw === undefined || raw === null ? "" : String(raw)
    if (!isDigits(s)) return s
    s = s.replace(/^0+(?=[0-9])/, "")
    var out = ""
    while (s.length > 3) { out = "," + s.slice(s.length - 3) + out; s = s.slice(0, s.length - 3) }
    return s + out
}

// Base units with `decimals` places, ungrouped: what an input field holds
// ("1500000000", 9 -> "1.5"). Anything but digits comes back as it was.
function plain(raw, decimals) {
    var s = raw === undefined || raw === null ? "" : String(raw)
    var d = decimals || 0
    if (!isDigits(s)) return s
    s = s.replace(/^0+(?=[0-9])/, "")
    if (d === 0) return s
    while (s.length <= d) s = "0" + s
    var frac = s.slice(s.length - d).replace(/0+$/, "")
    return s.slice(0, s.length - d) + (frac ? "." + frac : "")
}

// A token amount with its declared decimals, the whole part grouped
// ("1234500", 3 -> "1,234.5"; 0 decimals: an integer).
function token(raw, decimals) {
    var p = plain(raw, decimals), i = p.indexOf(".")
    return i < 0 ? group(p) : group(p.slice(0, i)) + p.slice(i)
}

// Lepta -> LGO: "1500000000" -> "1.5", "1" -> "0.000000001"
function lgo(lepta) { return token(lepta, DECIMALS) }

// Lepta -> "1.5 LGO"
function lgoLabel(lepta) { return lgo(lepta) + " " + SYMBOL }

// Typed text -> base units, or "" if it isn't an amount: digits, at most one
// "." and at most `decimals` places after it (more is refused, not rounded).
// "," only as thousands grouping ("1,000.5"): "1,5" is refused, not guessed.
function parse(text, decimals) {
    var t = text === undefined || text === null ? "" : String(text).trim()
    var m = /^([0-9]*|[0-9]{1,3}(?:,[0-9]{3})+)(?:\.([0-9]*))?$/.exec(t)
    if (!m) return ""
    var whole = m[1].replace(/,/g, ""), frac = m[2] || "", d = decimals || 0
    if ((whole === "" && frac === "") || frac.length > d) return ""
    while (frac.length < d) frac += "0"
    return (whole + frac).replace(/^0+(?=[0-9])/, "")
}

// LGO text -> lepta: "1.5" -> "1500000000", "" if it isn't an amount.
function lepta(text) { return parse(text, DECIMALS) }

// Compare two non-negative integer strings: -1, 0, 1.
function cmp(a, b) {
    a = String(a).replace(/^0+(?=[0-9])/, ""); b = String(b).replace(/^0+(?=[0-9])/, "")
    if (a.length !== b.length) return a.length < b.length ? -1 : 1
    return a < b ? -1 : a > b ? 1 : 0
}

// a - b for integer strings with a >= b ("0" when b is larger).
function sub(a, b) {
    a = String(a); b = String(b)
    if (cmp(a, b) <= 0) return "0"
    var out = "", borrow = 0, i = a.length - 1, j = b.length - 1
    while (i >= 0) {
        var d = (a.charCodeAt(i--) - 48) - (j >= 0 ? b.charCodeAt(j--) - 48 : 0) - borrow
        borrow = d < 0 ? 1 : 0
        out = (d + (borrow ? 10 : 0)) + out
    }
    return out.replace(/^0+(?=[0-9])/, "")
}

// a + b for integer strings.
function add(a, b) {
    a = String(a); b = String(b)
    var out = "", carry = 0, i = a.length - 1, j = b.length - 1
    while (i >= 0 || j >= 0 || carry) {
        var d = (i >= 0 ? a.charCodeAt(i--) - 48 : 0) + (j >= 0 ? b.charCodeAt(j--) - 48 : 0) + carry
        out = (d % 10) + out; carry = d >= 10 ? 1 : 0
    }
    return out.replace(/^0+(?=[0-9])/, "")
}
