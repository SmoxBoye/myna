import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

ShellRoot {
    id: root 
    
    property string apiKey: ""
    property string customerId: "quickgif-user"
    property var gifResults: []

    Component.onCompleted: loadApiKey()

    function loadApiKey() {
        var xhr = new XMLHttpRequest()
        // Qt.resolvedUrl locates the file relative to this QML script
        xhr.open("GET", Qt.resolvedUrl(".apikey.txt"))
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    // Success: Trim whitespace/newlines and save
                    root.apiKey = xhr.responseText.trim()
                    console.log("API Key loaded successfully")
                } else {
                    console.log("Could not load apikey.txt - check file existence")
                    // Optional: Set a flag to show an error UI
                }
            }
        }
        xhr.send()
    }

    function doApiCall(query) {
        if (root.apiKey === "") {
            console.log("Cannot search: API Key missing")
            return
        }
        if (!query || query.trim().length === 0) {
            root.gifResults = []
            return
        }

        var url = "https://api.klipy.com/api/v1/" + root.apiKey + "/gifs/search"
            + "?customer_id=" + encodeURIComponent(root.customerId)
            + "&q=" + encodeURIComponent(query)
            + "&per_page=24"
            + "&format_filter=gif"

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var response = JSON.parse(xhr.responseText)
                        handleResponse(response)
                    } catch (e) {
                        console.log("JSON parse error:", e)
                    }
                } else {
                    console.log("Request failed:", xhr.status)
                }
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function handleResponse(response) {
        if (response.result && response.data && response.data.data) {
            var gifs = response.data.data.map(function(gif) {
                var file = gif.file || {}
                var sm = file.sm && file.sm.gif ? file.sm.gif.url : null
                var md = file.md && file.md.gif ? file.md.gif.url : null
                return sm || md || null
            }).filter(function(url) { return url !== null })
            
            root.gifResults = gifs
        } else {
            root.gifResults = []
        }
    }

    PanelWindow {
        id: inputWindow
        
        // Make window fill the screen so we can center content
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        
        // Ensure the window doesn't push other windows aside (ExclusionMode)
        exclusionMode: ExclusionMode.Ignore
        
        // Transparent background for the full-screen overlay
        color: "transparent"
        visible: true

        HyprlandFocusGrab {
            id: focusGrab
            windows: [inputWindow]
            active: inputWindow.visible // Only grab if visible
        }

        // Dimmed Background (Optional: click to close)
        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit() 
            z: -1 // Behind the content
        }

        // The actual visual container (Centered)
        Rectangle {
            id: container
            width: 500
            height: root.gifResults.length > 0  ? 500 : 80
            anchors.centerIn: parent // Center in the full-screen window

            Behavior on height {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutExpo 
                }
            }

            clip: true
            
            color: "#1e1e2e"
            radius: 12
            border.color: "#89b4fa"
            border.width: 2
            
            // Prevent clicks passing through to the background MouseArea
            MouseArea { anchors.fill: parent } 

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                TextField {
                    id: inputField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    
                    focus: true
                    placeholderText: "Search GIFs... (ESC to quit)"
                    color: "#cdd6f4"
                    
                    background: Rectangle {
                        color: "#313244"
                        radius: 8
                    }
                    
                    font.pixelSize: 16

                    onTextChanged: debounceTimer.restart()

                    // Exit on Escape
                    Keys.onEscapePressed: Qt.quit() 
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    clip: true

                    opacity: root.gifResults.length > 0 ? 1 : 0
                    visible: opacity > 0
                    
                    Behavior on opacity {
                        NumberAnimation { duration: 250 }
                    }
                    
                    // Hide scrollbar background for cleaner look
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    GridView {
                        id: gifGrid
                        model: root.gifResults
                        
                        cellWidth: 155 
                        cellHeight: 155
                        flow: GridView.LeftToRight

                        // Fade the grid in/out so it doesn't pop abruptly
                        opacity: root.gifResults.length > 0 ? 1 : 0
                        visible: opacity > 0
                        
                        delegate: Item {
                            width: 150
                            height: 150

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 5
                                color: "transparent"
                                radius: 8
                                clip: true

                                AnimatedImage {
                                    anchors.fill: parent
                                    source: modelData
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    playing: inputWindow.visible 
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: copyGifToClipboard.running = true
                                }
                                Process {
                                    id: copyGifToClipboard
                                    command: ["sh", "-c", "wl-copy " + modelData]
                                    running: false
                                    onExited: Qt.quit()
                                
                                }
                            }
                        }
                    }
                }
            }
        }

        Timer {
            id: debounceTimer
            interval: 250 // 1000ms feels too slow for typing
            repeat: false
            onTriggered: root.doApiCall(inputField.text)
        }
    }
}
