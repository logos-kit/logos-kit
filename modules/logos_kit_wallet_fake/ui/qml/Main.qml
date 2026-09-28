import QtQuick
import QtQuick.Layouts

// The fake wallet's provider view. Basecamp's shell delivers every wallet
// intent here; the fake core (a stand-in `logos_kit_wallet`) decides the
// answer from its scenario (`ui_fakeIntent`), and this view relays it after
// the scenario's delay. Nothing to click: it answers on its own. The page
// shows the scenario and what the dApp asked, and can switch scenarios.
Item {
    id: root
    width: 480
    height: 720

    property string scenario: ""
    property var scenarios: []
    property var log: []
    readonly property bool bridge: typeof logos !== "undefined" && logos !== null

    function call(method, params, cb) {
        if (!bridge) return
        logos.callModuleAsync("logos_kit_wallet", "ui", [method, JSON.stringify(params || {})], function (raw) {
            var r = null
            try { r = typeof raw === "string" ? JSON.parse(raw) : raw } catch (e) {}
            if (cb) cb(r && r.value !== undefined ? r.value : null, r && r.error ? r.error : null)
        }, 20000)
    }

    function refresh() {
        call("fakeState", {}, function (s) { if (s) root.scenario = s.scenario })
        call("fakeLog", {}, function (l) { if (l) root.log = l.slice(-40).reverse() })
    }

    Component.onCompleted: {
        call("fakeScenarios", {}, function (s) { if (s) root.scenarios = s })
        refresh()
    }

    Connections {
        target: root.bridge ? logos : null
        ignoreUnknownSignals: true
        function onIntentRequested(requestId, intent, params, requesterName) {
            root.call("fakeIntent", { intent: intent, params: params || {}, requester: requesterName || "" }, function (a, e) {
                var ok = !!(a && a.ok)
                var deliver = function () {
                    logos.respond(requestId, ok, ok ? (a.data || {}) : ({}), ok ? "" : ((a && a.error) || "failed"))
                    root.refresh()
                }
                var t = Qt.createQmlObject("import QtQml; Timer { repeat: false }", root)
                t.interval = Math.max(1, (a && a.delayMs) || 150)
                t.triggered.connect(function () { deliver(); t.destroy() })
                t.start()
            })
        }
        function onModuleEventReceived(moduleName, eventName, data) { root.refresh() }
    }

    Timer { interval: 2000; running: root.bridge; repeat: true; onTriggered: root.refresh() }

    Rectangle { anchors.fill: parent; color: "#101014" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10
        Text { text: "Logos Kit wallet: FAKE"; color: "#ffb020"; font.pixelSize: 20; font.weight: Font.DemiBold }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            color: "#c8c8d0"
            text: "Conformance testing only. No keys, no chain: every wallet prompt is answered by the scenario below."
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.scenarios
                Rectangle {
                    objectName: "scenario_" + modelData.name
                    width: label.implicitWidth + 20
                    height: 28
                    radius: 14
                    color: modelData.name === root.scenario ? "#ffb020" : "#26262e"
                    Text { id: label; anchors.centerIn: parent; text: modelData.name; textFormat: Text.PlainText; color: modelData.name === root.scenario ? "#101014" : "#e0e0e8" }
                    MouseArea { anchors.fill: parent; onClicked: root.call("fakeSetScenario", { scenario: modelData.name }, function () { root.refresh() }) }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            color: "#9a9aa6"
            font.pixelSize: 12
            text: { for (var i = 0; i < root.scenarios.length; i++) if (root.scenarios[i].name === root.scenario) return root.scenarios[i].description; return "" }
        }
        Text { text: "What apps asked (newest first)"; color: "#e0e0e8"; font.weight: Font.DemiBold }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.log
            delegate: Text {
                width: ListView.view.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font.family: "monospace"
                font.pixelSize: 11
                color: modelData.kind === "intent" ? "#8fd0ff" : "#c8c8d0"
                text: modelData.seq + " " + modelData.app + " " + (modelData.method || modelData.name)
                    + (modelData.answer && modelData.answer.ok === false ? "  ✗ " + (modelData.answer.code || modelData.answer.error) : "")
            }
        }
    }
}
