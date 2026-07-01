import QtQuick
import Components
import "JellyfinMedia.js" as JellyfinMedia

FocusScope {
    id: itemListRoot

    property var navParams: ({})
    property var navListState: navParams.navListState || ({})

    signal navigateTo(string path, var params, var listState)
    signal goBack()

    property string parentId: navParams.parentId || navParams.libraryId || ""
    property string libraryId: navParams.libraryId || parentId
    property string libraryName: navParams.libraryName || ""
    property string collectionType: navParams.collectionType || ""
    property string itemType: navParams.itemType || "Movie"
    property bool recursive: navParams.recursive !== undefined ? Boolean(navParams.recursive) : true
    property string seriesName: navParams.seriesName || ""
    property string seasonName: navParams.seasonName || ""
    property var seriesItem: navParams.seriesItem || ({})
    property bool showSeriesMetadata: itemType === "Season" && seriesItem && seriesItem.id
    property var allItems: []
    property var items: []
    property string filterText: navListState.filterText || ""
    property bool isLoading: false
    property bool isLoadingMore: false
    property string errorMessage: ""

    function normalizeText(value) {
        var s = String(value || "").toLowerCase()
        try {
            if (s.normalize)
                s = s.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
        } catch (e) {
        }

        var map = {
            "æ": "ae", "ǽ": "ae", "œ": "oe", "ø": "o", "ð": "d",
            "đ": "d", "þ": "th", "ß": "ss", "ł": "l", "ı": "i"
        }
        var out = ""
        for (var i = 0; i < s.length; i++)
            out += map[s.charAt(i)] || s.charAt(i)
        return out
    }

    function applyFilter(preferredIndex) {
        var q = normalizeText(filterText)
        if (q === "") {
            items = allItems.slice()
        } else {
            var matches = []
            for (var i = 0; i < allItems.length; i++) {
                var item = allItems[i]
                if (normalizeText(JellyfinMedia.searchText(item)).indexOf(q) >= 0)
                    matches.push(item)
            }
            items = matches
        }

        if (items.length > 0) {
            var nextIndex = preferredIndex !== undefined ? preferredIndex : itemList.currentIndex
            if (nextIndex < 0) nextIndex = 0
            itemList.currentIndex = Math.min(nextIndex, items.length - 1)
            itemList.positionViewAtIndex(itemList.currentIndex, ListView.Contain)
        } else {
            itemList.currentIndex = -1
        }
    }

    function subtitleText() {
        return JellyfinMedia.breadcrumbText([libraryName, seriesName, seasonName])
    }

    function emptyLabel() {
        if (filterText !== "") return "NO MATCHES"
        if (itemType === "Series") return "NO SHOWS FOUND"
        if (itemType === "Season") return "NO SEASONS FOUND"
        if (itemType === "Episode") return "NO EPISODES FOUND"
        return "NO ITEMS FOUND"
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Up) {
            if (itemList.currentIndex > 0) itemList.currentIndex--
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Down) {
            if (itemList.currentIndex < itemList.count - 1) itemList.currentIndex++
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            selectCurrentItem()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Backspace) {
            if (filterText.length > 0) {
                filterText = filterText.slice(0, -1)
                applyFilter(0)
            } else {
                goBack()
            }
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Back) {
            if (filterText.length > 0) {
                filterText = ""
                applyFilter(0)
            } else {
                goBack()
            }
            event.accepted = true
            return
        }

        var typed = event.text || ""
        if (!(event.modifiers & Qt.ControlModifier) &&
            !(event.modifiers & Qt.MetaModifier) &&
            !(event.modifiers & Qt.AltModifier) &&
            typed.length === 1 &&
            typed.charCodeAt(0) >= 32) {
            filterText += typed
            applyFilter(0)
            event.accepted = true
        }
    }

    function selectCurrentItem() {
        var item = items[itemList.currentIndex]
        if (!item) return

        if (item.type === "series") {
            itemListRoot.navigateTo("Items.qml", {
                parentId: item.id,
                libraryId: libraryId,
                libraryName: libraryName,
                collectionType: collectionType,
                itemType: "Season",
                recursive: false,
                seriesName: JellyfinMedia.primaryTitle(item),
                seriesItem: item
            }, {
                currentIndex: itemList.currentIndex,
                filterText: filterText
            })
            return
        }

        if (item.type === "season") {
            itemListRoot.navigateTo("Items.qml", {
                parentId: item.id,
                libraryId: libraryId,
                libraryName: libraryName,
                collectionType: collectionType,
                itemType: "Episode",
                recursive: false,
                seriesName: seriesName,
                seasonName: JellyfinMedia.primaryTitle(item)
            }, {
                currentIndex: itemList.currentIndex,
                filterText: filterText
            })
            return
        }

        itemListRoot.navigateTo("Detail.qml", {
            item: item,
            libraryName: subtitleText()
        }, {
            currentIndex: itemList.currentIndex,
            filterText: filterText
        })
    }

    function appendLoadedItems(loadedItems, reset, finished) {
        var merged = reset ? [] : allItems.slice()
        for (var i = 0; i < loadedItems.length; i++)
            merged.push(loadedItems[i])
        allItems = merged

        isLoading = false
        isLoadingMore = !finished
        errorMessage = ""

        var restore = reset && navListState.currentIndex !== undefined
            ? navListState.currentIndex : itemList.currentIndex
        applyFilter(restore)
    }

    Connections {
        target: jellyfinBackend
        function onItemsPageLoaded(loadedItems, reset, finished) {
            itemListRoot.appendLoadedItems(loadedItems, reset, finished)
        }
        function onErrorOccurred(message) {
            itemListRoot.isLoading = false
            itemListRoot.isLoadingMore = false
            itemListRoot.errorMessage = message
        }
    }

    Component.onCompleted: {
        isLoading = true
        isLoadingMore = false
        errorMessage = ""
        jellyfinBackend.load_items_for_type(parentId, itemType, recursive)
    }

    focus: true
    Keys.onPressed: function(event) { itemListRoot.handleKey(event) }

    AppBar {
        iconSource: moduleRoot.moduleIcon
        title: moduleRoot.moduleName
        subtitle: subtitleText()
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.125
        anchors.leftMargin: root.sw * 0.125
    }

    Text {
        visible: isLoading
        text: "LOADING..."
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.centerIn: parent
        font.pixelSize: root.sh * 0.05
    }

    Text {
        visible: !isLoading && errorMessage !== ""
        text: errorMessage
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.centerIn: parent
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        width: root.sw * 0.76875
        font.pixelSize: root.sh * 0.05
    }

    Text {
        visible: !isLoading && !isLoadingMore && errorMessage === "" && items.length === 0
        text: emptyLabel()
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.centerIn: parent
        font.pixelSize: root.sh * 0.05
    }

    Text {
        visible: !isLoading && isLoadingMore
        text: "LOADING MORE... " + allItems.length
        color: root.tertiaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        elide: Text.ElideRight
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.sh * 0.205
        anchors.rightMargin: root.sw * 0.125
        width: root.sw * 0.35
        horizontalAlignment: Text.AlignRight
        font.pixelSize: root.sh * 0.0333333
    }

    Text {
        visible: filterText !== ""
        text: "FILTER: " + filterText + " (" + items.length + "/" + allItems.length + ")"
        color: root.secondaryColor
        font.family: root.globalFont
        font.capitalization: Font.AllUppercase
        elide: Text.ElideRight
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.205
        anchors.leftMargin: root.sw * 0.125
        width: isLoadingMore ? root.sw * 0.38 : root.sw * 0.75
        font.pixelSize: root.sh * 0.0333333
    }

    Item {
        id: seriesDetails
        visible: showSeriesMetadata
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.sh * 0.25
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        height: root.sh * 0.21875
        clip: true

        Column {
            anchors.fill: parent
            spacing: root.sh * 0.0104167

            Text {
                text: JellyfinMedia.primaryTitle(seriesItem)
                color: root.primaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                elide: Text.ElideRight
                width: parent.width
                font.pixelSize: root.sh * 0.05
            }

            Text {
                text: JellyfinMedia.seriesMetadataLine(seriesItem, allItems.length)
                color: root.secondaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                elide: Text.ElideRight
                width: parent.width
                font.pixelSize: root.sh * 0.0333333
            }

            Text {
                visible: JellyfinMedia.genreLine(seriesItem) !== ""
                text: JellyfinMedia.genreLine(seriesItem)
                color: root.tertiaryColor
                font.family: root.globalFont
                font.capitalization: Font.AllUppercase
                elide: Text.ElideRight
                width: parent.width
                font.pixelSize: root.sh * 0.0291667
            }

            Item {
                id: seriesSummaryContainer
                width: parent.width
                height: root.sh * 0.0875
                clip: true

                Text {
                    id: seriesSummaryText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: seriesItem.summary || ""
                    color: root.primaryColor
                    font.family: root.globalFont
                    wrapMode: Text.WordWrap
                    font.pixelSize: root.sh * 0.0291667
                    lineHeight: 1.3
                }

                SequentialAnimation {
                    running: showSeriesMetadata &&
                             seriesSummaryText.text !== "" &&
                             seriesSummaryText.implicitHeight > seriesSummaryContainer.height
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) seriesSummaryText.y = 0
                    PauseAnimation { duration: 3000 }
                    NumberAnimation {
                        target: seriesSummaryText
                        property: "y"
                        to: seriesSummaryContainer.height - seriesSummaryText.implicitHeight
                        duration: Math.abs(to) * 120
                    }
                    PauseAnimation { duration: 4000 }
                    PropertyAction { target: seriesSummaryText; property: "y"; value: 0 }
                }
            }
        }
    }

    ListView {
        id: itemList
        model: items
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: showSeriesMetadata ? root.sh * 0.4895833 : root.sh * 0.25
        anchors.leftMargin: root.sw * 0.115625
        width: root.sw * 0.76875
        height: showSeriesMetadata ? root.sh * 0.2854167 : root.sh * 0.525
        clip: true
        focus: true

        Keys.onPressed: function(event) { itemListRoot.handleKey(event) }

        delegate: Item {
            width: itemList.width
            height: root.sh * 0.0583333

            Item {
                id: textClip
                width: Math.min(rowText.implicitWidth, itemList.width)
                height: parent.height
                clip: true

                Rectangle {
                    color: root.accentColor
                    anchors.fill: rowText
                    visible: itemList.currentIndex === index
                }

                Text {
                    id: rowText
                    text: modelData.title || ""
                    color: itemList.currentIndex === index ? root.surfaceColor : root.primaryColor
                    font.family: root.globalFont
                    font.capitalization: Font.AllUppercase
                    anchors.verticalCenter: parent.verticalCenter
                    x: 0
                    topPadding: root.sh * 0.0041667
                    leftPadding: root.sw * 0.009375
                    rightPadding: root.sw * 0.009375
                    bottomPadding: root.sh * 0.00625
                    font.pixelSize: root.sh * 0.05
                }

                SequentialAnimation {
                    running: (itemList.currentIndex === index) &&
                             (rowText.implicitWidth > textClip.width)
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) rowText.x = 0
                    PauseAnimation { duration: 1500 }
                    NumberAnimation {
                        target: rowText
                        property: "x"
                        to: textClip.width - rowText.implicitWidth
                        duration: Math.abs(to) * 20
                    }
                    PauseAnimation { duration: 2000 }
                    PropertyAction { target: rowText; property: "x"; value: 0 }
                }
            }
        }
    }

    Text {
        text: filterText !== "" ? "[ESC]:CLEAR [BS]:DELETE [▲▼]:NAVIGATE [ENTER]:SELECT"
                                : "[TYPE]:FILTER [ESC]:BACK [▲▼]:NAVIGATE [ENTER]:SELECT"
        color: root.tertiaryColor
        font.family: root.globalFont
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: root.sh * 0.1041667
        anchors.leftMargin: root.sw * 0.125
        font.pixelSize: root.sh * 0.0333333
    }
}
