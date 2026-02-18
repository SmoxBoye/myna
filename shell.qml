import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml

ShellRoot {
    id: root 
    
    // --- Configuration ---
    readonly property int maxHistoryPerGif: 50
    readonly property int maxFavoritesTotal: 100
    
    readonly property string apiKey: {
        try {
            var txt = apiFile.text();
            if (!txt || txt.trim() === "") return "";
            return JSON.parse(txt)["key"] || "";
        } catch (e) {
            return "";
        }
    }
    property string customerId: "myna-user"

    readonly property string homeDir: Quickshell.env("HOME")
    
    // --- Data Models ---
    property var searchResults: []
    property var favoriteGifs: [] 
    property var displayGifs: []  
    
    property string currentPanel: "search"

    Component.onCompleted: {
    // Ensure directories exist so FileView doesn't explode
    dirMaker.command = ["mkdir", "-p", 
        root.homeDir + "/.config/myna", 
        root.homeDir + "/.local/share/myna"
    ];
    dirMaker.running = true;
    }

    Process {
        id: dirMaker
        running: false
        onExited: {
            // Only load favorites AFTER we know the folders are ready
            root.loadFavorites();
        }
    }

    FileView {
        id: apiFile
        path: "file://" + root.homeDir + "/.config/myna/config.json"
        blockLoading: true
    }

    FileView {
        id: favoritesFile
        path: "file://" + root.homeDir + "/.local/share/myna/favorites.json"
        blockLoading: true
        // blockWrites: true
    }

    function loadFavorites() {
        try {
            var txt = favoritesFile.text();
            if (txt) {
                var json = JSON.parse(txt);
                if (json.favorites) root.favoriteGifs = json.favorites;
            }
        } catch(e) { root.favoriteGifs = []; }
    }
    
    function saveFavorites() {
        favoritesFile.setText(JSON.stringify({ "favorites": root.favoriteGifs }));
    }


    function copyUrl(url, name) {
        addUrlToFavorites(url, name);
        clipboardProc.command = ["wl-copy", url];
        clipboardProc.running = true;
        
    }
    
    Process {
        id: clipboardProc
        running: false
        onExited: Qt.quit()
    }

    function addUrlToFavorites(url, name) {
        var now = Date.now();
        var favs = root.favoriteGifs.slice();
        var idx = favs.findIndex(item => item.url === url);

        if (idx !== -1) {
            favs[idx].uses.push(now);
            if (favs[idx].uses.length > root.maxHistoryPerGif) {
                favs[idx].uses = favs[idx].uses.slice(-root.maxHistoryPerGif);
            }
            // Update name if it was missing or changed
            favs[idx].name = name;
        } else {
            favs.push({ "url": url, "name": name, "uses": [now] });
        }

        favs = sortFavorites(favs);
        if (favs.length > root.maxFavoritesTotal) {
            favs = favs.slice(0, root.maxFavoritesTotal);
        }

        root.favoriteGifs = favs;
        saveFavorites();
    }

    function sortFavorites(list) {
        var now = Date.now();
        var dayInMs = 86400000;

        return list.map(item => {
            var score = item.uses.reduce((acc, ts) => {
                var daysSince = (now - ts) / dayInMs;
                return acc + (1.0 / (daysSince + 1.0));
            }, 0);
            return { "item": item, "score": score };
        })
        .sort((a, b) => b.score - a.score)
        .map(wrapper => wrapper.item);
    }

    function updateSortedDisplay() {
        var sorted = sortFavorites(root.favoriteGifs);
        var filterTxt = mainInput.text.toLowerCase().trim();

        if (filterTxt === "") {
            root.displayGifs = sorted;
        } else {
            // Search by name in favorites
            root.displayGifs = sorted.filter(item => 
                (item.name && item.name.toLowerCase().includes(filterTxt)) || 
                item.url.toLowerCase().includes(filterTxt)
            );
        }
    }

    function handleInput(text) {
        if (root.currentPanel === "search") {
            doApiCall(text);
        } else {
            updateSortedDisplay();
        }
    }

    function doApiCall(query) {
        if (root.apiKey === "" || !query || query.trim().length === 0) {
            root.displayGifs = [];
            return;
        }

        var url = "https://api.klipy.com/api/v1/" + root.apiKey + "/gifs/search"
            + "?customer_id=" + encodeURIComponent(root.customerId)
            + "&q=" + encodeURIComponent(query)
            + "&per_page=24"
            + "&format_filter=gif";

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    handleResponse(JSON.parse(xhr.responseText));
                } catch (e) { console.log("JSON error", e); }
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function handleResponse(response) {
        if (response.data && response.data.data) {
            // Store as objects so we have the name/title immediately
            root.searchResults = response.data.data.map(function(gif) {
                var file = gif.file || {};
                var gifUrl = (file.sm && file.sm.gif ? file.sm.gif.url : null) || 
                             (file.md && file.md.gif ? file.md.gif.url : null);
                
                return {
                    "url": gifUrl,
                    "name": gif.title || gif.slug || "Untitled GIF"
                };
            }).filter(item => item.url !== null);
            
            if (mainInput.text.trim().length > 0) {
                root.displayGifs = root.searchResults;
            }
        }
    }

    function switchPanel() {
        root.currentPanel = root.currentPanel === "search" ? "favorites" : "search";
        mainInput.text = "";
        root.displayGifs = []; // Clear grid on switch
        if (root.currentPanel === "favorites") updateSortedDisplay();
        else root.displayGifs = root.searchResults;
    }

    // --- UI ---

    PanelWindow {
        id: inputWindow
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: true

        HyprlandFocusGrab {
            windows: [inputWindow]
            active: inputWindow.visible
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit() 
            z: -1 
        }

        Rectangle {
            id: container
            width: 500
            height: (gifGrid.count > 0) ? 500 : 80 
            anchors.centerIn: parent
            color: "#1e1e2e"
            radius: 12
            border.color: "#89b4fa"
            border.width: 2
            clip: true

            Behavior on height {
                NumberAnimation { duration: 400; easing.type: Easing.OutExpo }
            }
            
            MouseArea { anchors.fill: parent } 

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                TextField {
                    id: mainInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    focus: true
                    placeholderText: root.currentPanel === "search" ? "Search GIFs..." : "Search Favorites..."
                    color: root.currentPanel === "search" ? "#cdd6f4" : "#f5c2e7"

                    leftPadding: 15

                    rightPadding: clearButton.visible ? 30 : 10

                    background: Rectangle {
                        color: "#313244"
                        radius: 8
                        border.width: 1
                        border.color: root.currentPanel === "search" ? "transparent" : "#cba6f7"
                    }

                    // Clear Button
                    Text {
                        id: clearButton
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"
                        color: "#6e738d"
                        font.pixelSize: 16
                        visible: mainInput.text.length > 0
        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                mainInput.text = "";
                                mainInput.forceActiveFocus();
                            }
                        }
                    }
                    
                    font.pixelSize: 16
                    onTextChanged: debounceTimer.restart()
                    Keys.onEscapePressed: Qt.quit()
                    Keys.onTabPressed: root.switchPanel()
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    opacity: gifGrid.count > 0 ? 1 : 0
                    visible: root.displayGifs.length > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 200}
                    }

                    GridView {
                        id: gifGrid
                        model: root.displayGifs
                        cellWidth: 155 
                        cellHeight: 155
                        
                        delegate: Item {
                            width: 150
                            height: 150

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 5
                                color: "#313244"

                                AnimatedImage {
                                    anchors.fill: parent
                                    source: modelData.url
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    playing: inputWindow.visible 
                                }
                                

                                // Optional Tooltip to show the name on hover
                                ToolTip.visible: mArea.containsMouse
                                ToolTip.text: modelData.name
                                ToolTip.delay: 500

                                MouseArea {
                                    id: mArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.copyUrl(modelData.url, modelData.name)
                                }
                            }
                        }
                    }
                }
            }
        }

        Timer {
            id: debounceTimer
            interval: 250
            repeat: false
            onTriggered: root.handleInput(mainInput.text)
        }
    }
}
