// Babel plugin: work around Qt V4 engine bugs that no polyfill can fix (builtins are locked in QML).
//  1. Function.prototype.apply(thisArg, <TypedArray>) passes `undefined` for every argument
//     (Qt 6.9.2 + 6.11.1, QJSEngine and QML). Very common: String.fromCharCode.apply(null, u8).
//     Rewrite `f.apply(t, x)` -> `f.apply(t, __qmlArgs(x))` which converts array views to Arrays.
module.exports = function qmlV4({ types: t }) {
  return {
    name: 'qml-v4-fixes',
    visitor: {
      Program: {
        exit(path, state) {
          if (!state.usedArgs) return
          path.unshiftContainer(
            'body',
            t.functionDeclaration(
              t.identifier('__qmlArgs'),
              [t.identifier('a')],
              t.blockStatement([
                t.returnStatement(
                  t.conditionalExpression(
                    t.logicalExpression(
                      '&&',
                      t.identifier('a'),
                      t.callExpression(
                        t.memberExpression(t.identifier('ArrayBuffer'), t.identifier('isView')),
                        [t.identifier('a')],
                      ),
                    ),
                    t.callExpression(
                      t.memberExpression(t.identifier('Array'), t.identifier('from')),
                      [t.identifier('a')],
                    ),
                    t.identifier('a'),
                  ),
                ),
              ]),
            ),
          )
        },
      },
      CallExpression(path, state) {
        const c = path.node.callee
        if (
          !t.isMemberExpression(c) ||
          c.computed ||
          !t.isIdentifier(c.property, { name: 'apply' })
        )
          return
        const args = path.node.arguments
        if (
          args.length !== 2 ||
          t.isArrayExpression(args[1]) ||
          t.isIdentifier(args[1], { name: 'arguments' })
        )
          return
        if (t.isCallExpression(args[1]) && t.isIdentifier(args[1].callee, { name: '__qmlArgs' }))
          return
        args[1] = t.callExpression(t.identifier('__qmlArgs'), [args[1]])
        state.usedArgs = true
      },
    },
  }
}
