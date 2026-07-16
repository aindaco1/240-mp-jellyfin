pragma Singleton
import QtQuick

QtObject {
    function normalize(value) {
        var text = String(value || "").toLowerCase()
        try {
            if (text.normalize)
                text = text.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
        } catch (error) {
        }

        var replacements = {
            "æ": "ae", "ǽ": "ae", "œ": "oe", "ø": "o", "ð": "d",
            "đ": "d", "þ": "th", "ß": "ss", "ł": "l", "ı": "i"
        }
        var normalized = ""
        for (var index = 0; index < text.length; ++index)
            normalized += replacements[text.charAt(index)] || text.charAt(index)
        return normalized
    }

    function matchesNormalized(normalizedValue, query) {
        var normalizedQuery = normalize(query)
        return normalizedQuery === "" || String(normalizedValue || "").indexOf(normalizedQuery) >= 0
    }

    function articleInsensitiveSortKey(value) {
        var key = normalize(value).replace(/^\s+/, "")
        return key.replace(/^(?:a|an|the)\s+/, "")
    }
}
