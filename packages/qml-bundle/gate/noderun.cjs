// Reference run of the same bundle in Node.
const fs = require("fs"); const vm = require("vm");
const src = fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\n/, "");
const ctx = { console, setTimeout, clearTimeout }; vm.createContext(ctx); vm.runInContext(src + "\n;this.Suite=Suite;", ctx);
const host = { log: (s) => console.log(s), setTimeout, clearTimeout, done() {} };
Promise.resolve(ctx.Suite.run(host)).then(() => console.log("DONE true"), (e) => console.log("REJECT", e, e && e.stack));
