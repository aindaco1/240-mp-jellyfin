.pragma library

var CATEGORY_DATA = [
    { code: "c", name: "Cartoons", label: "CARTOON" },
    { code: "s", name: "Comedy", label: "COMEDY" },
    { code: "a", name: "Commercials", label: "AD" },
    { code: "d", name: "Drama", label: "DRAMA" },
    { code: "g", name: "Gameshows", label: "GAMESHOW" },
    { code: "k", name: "Kids", label: "KIDS" },
    { code: "e", name: "Movies", label: "MOVIE" },
    { code: "m", name: "Music", label: "MUSIC" },
    { code: "n", name: "News", label: "NEWS" },
    { code: "o", name: "Other", label: "OTHER" },
    { code: "z", name: "Soaps", label: "SOAP" },
    { code: "p", name: "Specials", label: "SPECIAL" },
    { code: "r", name: "Sports", label: "SPORTS" },
    { code: "t", name: "Talkshows", label: "TALKSHOW" },
    { code: "f", name: "Trailers", label: "TRAILER" }
]

function feeds() {
    return [
        { name: "50s", decadeName: "50s", startYear: 1950, origin: "https://50s.myretrotvs.com" },
        { name: "60s", decadeName: "60s", startYear: 1960, origin: "https://60s.myretrotvs.com" },
        { name: "70s", decadeName: "70s", startYear: 1970, origin: "https://70s.myretrotvs.com" },
        { name: "80s", decadeName: "80s", startYear: 1980, origin: "https://80s.myretrotvs.com" },
        { name: "90s", decadeName: "90s", startYear: 1990, origin: "https://90s.myretrotvs.com" },
        { name: "00s", decadeName: "00s", startYear: 2000, origin: "https://00s.myretrotvs.com" }
    ]
}

function menuEntries() {
    return feeds().map(function(feed) {
        return {
            type: "feed",
            name: feed.name,
            feed: feed
        }
    })
}

function controls() {
    return [
        { keys: "UP / DOWN", action: "Channel surf" },
        { keys: "LEFT / RIGHT", action: "Skip current clip" },
        { keys: "SPACE / ENTER", action: "Play or pause" },
        { keys: "0-9", action: "Jump within decade" },
        { keys: "C / H", action: "Show controls" },
        { keys: "M", action: "Video controls" },
        { keys: "F / V", action: "Filter content" },
        { keys: "N", action: "Cycle CRT noise" },
        { keys: "G", action: "Toggle glow" },
        { keys: "B", action: "Toggle black and white" },
        { keys: "O", action: "Toggle static transitions" },
        { keys: "Y", action: "Open clip on YouTube" },
        { keys: "ESC", action: "Exit video" },
        { keys: "FILTER SPACE", action: "Toggle category" },
        { keys: "FILTER A", action: "All categories" },
        { keys: "FILTER N", action: "No categories" },
        { keys: "FILTER ENTER", action: "Apply filters" }
    ]
}

function visibleCategories() {
    return CATEGORY_DATA.slice(0)
}

function defaultFilters() {
    var filters = {}
    for (var i = 0; i < CATEGORY_DATA.length; ++i) {
        var code = CATEGORY_DATA[i].code
        filters[code] = code !== "o" && code !== "f"
    }
    return filters
}

function cloneFilters(filters) {
    var copy = {}
    for (var i = 0; i < CATEGORY_DATA.length; ++i) {
        var code = CATEGORY_DATA[i].code
        copy[code] = filters && filters[code] !== undefined ? !!filters[code] : true
    }
    return copy
}

function selectedFilterCount(filters) {
    var count = 0
    for (var i = 0; i < CATEGORY_DATA.length; ++i) {
        if (filters && filters[CATEGORY_DATA[i].code])
            ++count
    }
    return count
}

function filterSummary(filters) {
    var selected = selectedFilterCount(filters)
    if (selected === CATEGORY_DATA.length)
        return "ALL CONTENT"
    if (selected === 0)
        return "NO CONTENT"

    var labels = []
    for (var i = 0; i < CATEGORY_DATA.length; ++i) {
        var category = CATEGORY_DATA[i]
        if (filters && filters[category.code])
            labels.push(category.label)
    }
    return labels.join(", ")
}

function loadFeed(feed, onReady, onError) {
    requestText(feed.origin + "/", function(html) {
        var scriptUrl = extractMainScriptUrl(feed.origin, html)
        if (!scriptUrl) {
            onError("Could not find MyRetroTVs script for " + feed.decadeName)
            return
        }

        requestText(scriptUrl, function(script) {
            var decodeMap = extractDecodeMap(script)
            if (!decodeMap) {
                onError("Could not read MyRetroTVs video decoder for " + feed.decadeName)
                return
            }

            requestText(feed.origin + "/d.json", function(text) {
                try {
                    var payload = JSON.parse(text)
                    onReady(parseChannels(feed, payload, decodeMap))
                } catch (err) {
                    onError("Could not parse MyRetroTVs feed: " + err)
                }
            }, onError)
        }, onError)
    }, onError)
}

function requestText(url, onReady, onError) {
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return
        if ((xhr.status >= 200 && xhr.status < 300) || xhr.status === 0) {
            onReady(xhr.responseText)
            return
        }
        onError("Request failed (" + xhr.status + "): " + url)
    }
    xhr.open("GET", url)
    xhr.send()
}

function extractMainScriptUrl(origin, html) {
    var match = html.match(/<script[^>]+type=["']module["'][^>]+src=["']([^"']+\.js)["']/i)
    if (!match)
        match = html.match(/<script[^>]+src=["']([^"']+index-[^"']+\.js)["']/i)
    if (!match)
        return ""
    return resolveUrl(origin, match[1])
}

function resolveUrl(origin, path) {
    if (path.indexOf("http://") === 0 || path.indexOf("https://") === 0)
        return path
    if (path.charAt(0) === "/")
        return origin + path
    return origin + "/" + path
}

function extractDecodeMap(script) {
    var pattern = /\[\[(?:\d+,?)+\](?:,\[(?:\d+,?)+\])+\]/g
    var match
    while ((match = pattern.exec(script)) !== null) {
        try {
            var candidate = JSON.parse(match[0])
            if (isDecodeMap(candidate))
                return candidate
        } catch (err) {
        }
    }
    return null
}

function isDecodeMap(candidate) {
    if (!candidate || candidate.length !== 32)
        return false
    for (var row = 0; row < candidate.length; ++row) {
        if (!candidate[row] || candidate[row].length !== 11)
            return false
        for (var col = 0; col < candidate[row].length; ++col) {
            if (typeof candidate[row][col] !== "number")
                return false
        }
    }
    return true
}

function parseChannels(feed, payload, decodeMap) {
    var channels = []
    var counts = {}
    for (var i = 0; i < CATEGORY_DATA.length; ++i)
        counts[CATEGORY_DATA[i].code] = 0

    var years = payload.x || []
    for (var yearIndex = 0; yearIndex < years.length; ++yearIndex) {
        var records = shuffle(splitRecords(years[yearIndex] || ""))
        var pendingByCategory = {}

        for (var recordIndex = 0; recordIndex < records.length; ++recordIndex) {
            var record = records[recordIndex]
            if (record.length < 12)
                continue

            var encodedId = record.substr(0, 11)
            var rawCode = record.slice(-1)
            var code = rawCode.toLowerCase()
            if (code === "h" || !categoryForCode(code))
                continue

            var clip = {
                videoId: decodeVideoId(encodedId, decodeMap),
                encodedId: encodedId,
                failed: false
            }

            if (rawCode === code && pendingByCategory[code] !== undefined) {
                var pending = channels[pendingByCategory[code]]
                pending.clips.push(clip)
                ++counts[code]
                if (pending.clips.length >= 5)
                    delete pendingByCategory[code]
                continue
            }

            if (rawCode === code)
                pendingByCategory[code] = channels.length

            channels.push({
                index: channels.length,
                categoryCode: code,
                categoryLabel: categoryForCode(code).label,
                yearIndex: yearIndex,
                year: feed.startYear + yearIndex,
                clips: [ clip ],
                failed: false
            })
            ++counts[code]
        }
    }

    return {
        feed: feed,
        updated: payload.d ? new Date(payload.d).toLocaleDateString() : "",
        channels: shuffle(channels),
        counts: counts
    }
}

function splitRecords(value) {
    var records = []
    for (var pos = 0; pos < value.length; pos += 12)
        records.push(value.substring(pos, pos + 12))
    return records
}

function shuffle(values) {
    var copy = values.slice(0)
    for (var i = copy.length - 1; i > 0; --i) {
        var j = Math.floor(Math.random() * (i + 1))
        var temp = copy[i]
        copy[i] = copy[j]
        copy[j] = temp
    }
    return copy
}

function decodeVideoId(encodedId, decodeMap) {
    var chars = encodedId.split("")
    var row = decodeMap[mapIndex(encodedId, decodeMap.length)]
    var decoded = []
    for (var i = 0; i < row.length; ++i)
        decoded.push(chars[row[i]])
    return decoded.join("")
}

function mapIndex(value, mapLength) {
    var total = 0
    for (var i = 0; i < value.length; ++i)
        total += value.charCodeAt(i)
    return total % mapLength
}

function categoryForCode(code) {
    for (var i = 0; i < CATEGORY_DATA.length; ++i) {
        if (CATEGORY_DATA[i].code === code)
            return CATEGORY_DATA[i]
    }
    return null
}

function buildVideoFilter(noiseLevel, blackAndWhite, glow) {
    var graph = []
    if (blackAndWhite)
        graph.push("hue=s=0")
    if (noiseLevel > 0)
        graph.push("noise=alls=" + (noiseLevel * 7) + ":allf=t")
    if (glow) {
        graph.push("gblur=sigma=0.35")
        graph.push("eq=contrast=1.08:brightness=0.02:saturation=1.12")
    }
    return graph.length === 0 ? "" : "lavfi=[" + graph.join(",") + "]"
}
