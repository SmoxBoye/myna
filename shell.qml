import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

ShellRoot {
    // PanelWindow creates a surface anchored to the screen (Layer Shell)
    PanelWindow {
        id: inputWindow
        
        

        height: 60
        width: 500
        visible: true

        // TRANSPARENT background for the window itself so we can draw rounded corners
        color: "transparent" 

        // CRITICAL: This grabs keyboard focus so you can type immediately
        HyprlandFocusGrab {
            id: focusGrab
            windows: [inputWindow]
            active: true // Set to true to grab focus
        }

        // The visual container
        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e" // Dark grey background
            radius: 12
            border.color: "#89b4fa" // Blue border
            border.width: 2

            Timer {
                id: debounceTimer
                interval: 1000
                repeat: false
                onTriggered: inputField.apiCall(inputField.text)
            }
            
            // The actual input field
            TextField {
                id: inputField
                anchors.centerIn: parent
                width: parent.width - 40
                
                focus: true // Request QML focus
                placeholderText: "Type command..."
                color: "#cdd6f4" // Text color
                
                // Remove default white background from TextField
                background: Item {} 
                
                font.pixelSize: 16

                onTextChanged: debounceTimer.restart()

                function apiCall(query) {
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
                    // Example: use a real API
                    xhr.open("GET", "https://api.github.com/search/repositories?q=" + encodeURIComponent(query))
                    xhr.send()
                }
                function handleResponse(response) {
                    console.log("Found", response.total_count, "results")
                    // Do something with response.items
                }
            
            }
        }
    }
}
