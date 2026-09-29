.pragma library
// Amount formatting for LEZ. Native LEZ has NO decimals: balances, fees and
// faucet drops are integers ("1,000,000,000 LEZ"), so nothing here ever adds
// a decimal point for native. A fungible token may declare `decimals`; only
// then is a point placed. Amounts stay decimal strings end to end (u128
// never becomes a JS number, and QML's V4 has no BigInt).

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

// A token amount with its declared decimals (0 for native LEZ).
function token(raw, decimals) {
    var s = String(raw)
    var d = decimals || 0
    if (!isDigits(s) || d === 0) return group(s)
    while (s.length <= d) s = "0" + s
    var whole = s.slice(0, s.length - d), frac = s.slice(s.length - d).replace(/0+$/, "")
    return group(whole) + (frac ? "." + frac : "")
}

// "12,480 LEZ"
function lez(raw) { return group(raw) + " LEZ" }

// Compare two non-negative integer strings: -1, 0, 1.
function cmp(a, b) {
    a = String(a).replace(/^0+(?=[0-9])/, ""); b = String(b).replace(/^0+(?=[0-9])/, "")
    if (a.length !== b.length) return a.length < b.length ? -1 : 1
    return a < b ? -1 : a > b ? 1 : 0
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
