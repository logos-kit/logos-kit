// Additive-only runtime shims for the Qt V4 engine inside QML (Qt 6.9.2 / 6.11.1).
// QML's lockObject() makes every existing builtin member non-writable/non-configurable,
// so we may only ADD missing members, never replace existing ones (this is why core-js fails).
// Must be the first module in the bundle.
// Ported from the research pipeline; not formatted by Biome (biome.json excludes it:
// its fixes rewrite hasOwnProperty.call into Object.hasOwn, i.e. into recursion).
var G = Function("return this")();
function add(obj, key, value) {
  if (obj[key] === undefined) Object.defineProperty(obj, key, { value: value, writable: true, configurable: true, enumerable: false });
}
add(G, "globalThis", G);

// ---- Promise ----
add(Promise, "allSettled", function (it) {
  return Promise.all(Array.from(it, function (p) {
    return Promise.resolve(p).then(function (value) { return { status: "fulfilled", value: value }; },
      function (reason) { return { status: "rejected", reason: reason }; });
  }));
});
add(Promise, "any", function (it) {
  return new Promise(function (res, rej) {
    var errs = [], n = 0, arr = Array.from(it);
    if (!arr.length) rej(new Error("All promises were rejected"));
    arr.forEach(function (p, i) { Promise.resolve(p).then(res, function (e) { errs[i] = e; if (++n === arr.length) { var er = new Error("All promises were rejected"); er.errors = errs; rej(er); } }); });
  });
});
add(Promise.prototype, "finally", function (f) {
  var C = this.constructor || Promise;
  return this.then(function (v) { return C.resolve(f()).then(function () { return v; }); },
    function (e) { return C.resolve(f()).then(function () { throw e; }); });
});

// ---- Array / Object / String ----
function flat(arr, d) { var out = []; arr.forEach(function (x) { if (Array.isArray(x) && d > 0) out.push.apply(out, flat(x, d - 1)); else out.push(x); }); return out; }
add(Array.prototype, "flat", function (d) { return flat(this, d === undefined ? 1 : Number(d)); });
add(Array.prototype, "flatMap", function (f, t) { return flat(this.map(f, t), 1); });
function at(i) { var n = this.length; i = Math.trunc(i) || 0; if (i < 0) i += n; return i < 0 || i >= n ? undefined : this[i]; }
add(Array.prototype, "at", at); add(String.prototype, "at", at);
["Int8Array", "Uint8Array", "Uint8ClampedArray", "Int16Array", "Uint16Array", "Int32Array", "Uint32Array", "Float32Array", "Float64Array"].forEach(function (k) { if (G[k]) add(G[k].prototype, "at", at); });
add(Array.prototype, "findLast", function (f, t) { for (var i = this.length - 1; i >= 0; i--) if (f.call(t, this[i], i, this)) return this[i]; });
add(Array.prototype, "findLastIndex", function (f, t) { for (var i = this.length - 1; i >= 0; i--) if (f.call(t, this[i], i, this)) return i; return -1; });
add(Object, "fromEntries", function (it) { var o = {}; Array.from(it).forEach(function (e) { Object.defineProperty(o, e[0], { value: e[1], writable: true, enumerable: true, configurable: true }); }); return o; });
add(Object, "hasOwn", function (o, k) { return Object.prototype.hasOwnProperty.call(o, k); });
add(String.prototype, "replaceAll", function (s, r) {
  if (s instanceof RegExp) { if (!s.global) throw new TypeError("replaceAll must be called with a global RegExp"); return this.replace(s, r); }
  return this.split(String(s)).join(typeof r === "function" ? r(String(s)) : String(r).replace(/\$\$/g, "$"));
});
add(String.prototype, "trimStart", function () { return this.replace(/^\s+/, ""); });
add(String.prototype, "trimEnd", function () { return this.replace(/\s+$/, ""); });

// ---- Timers (QML has no setTimeout in JS; host injects a Timer-backed impl) ----
var host = null;
add(G, "queueMicrotask", function (f) { Promise.resolve().then(f); });
add(G, "setTimeout", function (f, ms) {
  if (!host) throw new Error("setTimeout: call installQmlHost({setTimeout, clearTimeout}) from QML first");
  var args = Array.prototype.slice.call(arguments, 2);
  return host.setTimeout(function () { f.apply(null, args); }, ms || 0);
});
add(G, "clearTimeout", function (id) { if (host) host.clearTimeout(id); });

// ---- UTF-8 TextEncoder / TextDecoder ----
function TextEncoderP() {}
TextEncoderP.prototype.encoding = "utf-8";
TextEncoderP.prototype.encode = function (s) {
  s = s === undefined ? "" : String(s);
  var out = [], i = 0;
  while (i < s.length) {
    var c = s.codePointAt(i); i += c > 0xffff ? 2 : 1;
    if (c < 0x80) out.push(c);
    else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63));
    else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
    else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
  }
  return new Uint8Array(out);
};
function TextDecoderP(label) { this.encoding = (label || "utf-8").toLowerCase(); }
TextDecoderP.prototype.decode = function (buf) {
  if (!buf) return "";
  var b = buf instanceof Uint8Array ? buf : new Uint8Array(buf.buffer || buf, buf.byteOffset || 0, buf.byteLength);
  var s = "", i = 0;
  while (i < b.length) {
    var c = b[i++], cp;
    if (c < 0x80) cp = c;
    else if (c < 0xe0) cp = ((c & 31) << 6) | (b[i++] & 63);
    else if (c < 0xf0) cp = ((c & 15) << 12) | ((b[i++] & 63) << 6) | (b[i++] & 63);
    else cp = ((c & 7) << 18) | ((b[i++] & 63) << 12) | ((b[i++] & 63) << 6) | (b[i++] & 63);
    s += String.fromCodePoint(cp);
  }
  return s;
};
add(G, "TextEncoder", TextEncoderP);
add(G, "TextDecoder", TextDecoderP);

// ---- base64 ----
var B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
add(G, "btoa", function (s) {
  s = String(s); var o = "";
  for (var i = 0; i < s.length; i += 3) {
    var a = s.charCodeAt(i), b = s.charCodeAt(i + 1), c = s.charCodeAt(i + 2);
    if (a > 255 || b > 255 || c > 255) throw new Error("btoa: invalid character");
    o += B64[a >> 2] + B64[((a & 3) << 4) | (b >> 4 || 0)] + (i + 1 < s.length ? B64[((b & 15) << 2) | (c >> 6 || 0)] : "=") + (i + 2 < s.length ? B64[c & 63] : "=");
  }
  return o;
});
add(G, "atob", function (s) {
  s = String(s).replace(/[\s=]/g, ""); var o = "", buf = 0, bits = 0;
  for (var i = 0; i < s.length; i++) { var v = B64.indexOf(s[i]); if (v < 0) throw new Error("atob: invalid character"); buf = (buf << 6) | v; bits += 6; if (bits >= 8) { bits -= 8; o += String.fromCharCode((buf >> bits) & 255); } }
  return o;
});

// ---- crypto.getRandomValues: there is NO CSPRNG in QML JS. Only the host (native module) can provide entropy. ----
if (G.crypto === undefined) add(G, "crypto", {});
add(G.crypto, "getRandomValues", function (arr) {
  if (!host || !host.randomBytes) throw new Error("crypto.getRandomValues: no secure RNG in QML; inject host.randomBytes(n) from the native module");
  var r = host.randomBytes(arr.byteLength), u = new Uint8Array(arr.buffer, arr.byteOffset, arr.byteLength);
  // Fail closed: a short or non-byte answer must never leave predictable zeros.
  if (!r || r.length !== u.length) throw new Error("crypto.getRandomValues: host.randomBytes returned the wrong length");
  for (var i = 0; i < u.length; i++) {
    var x = r[i];
    if (typeof x !== "number" || x !== (x & 255)) throw new Error("crypto.getRandomValues: host.randomBytes returned a non-byte");
    u[i] = x;
  }
  return arr;
});

export function installQmlHost(h) { host = h; }
