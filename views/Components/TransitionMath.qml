pragma Singleton
import QtQuick

QtObject {
    function clamp01(value) {
        return Math.max(0, Math.min(1, value))
    }

    function easeOutCubic(value) {
        var t = clamp01(value)
        return 1 - Math.pow(1 - t, 3)
    }

    function easeInCubic(value) {
        var t = clamp01(value)
        return t * t * t
    }
}
