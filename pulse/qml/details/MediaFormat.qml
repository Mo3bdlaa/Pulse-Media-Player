pragma Singleton
import QtQuick
import Pulse.Core

// Plain-language labels for technical facts (07, 12).
QtObject {
    function channels(n) {
        return n === 1 ? qsTr("Mono") : n === 2 ? qsTr("Stereo") : n === 6 ? "5.1" : n === 8 ? "7.1" : n > 0 ? qsTr("%1 channels").arg(n) : ""
    }
    function aspect(a) {
        if (!a) return ""
        const known = [[16 / 9, "16:9"], [4 / 3, "4:3"], [21 / 9, "21:9"], [1.85, "1.85:1"], [2.39, "2.39:1"], [2.35, "2.35:1"], [1, "1:1"], [9 / 16, "9:16"]]
        for (const k of known) if (Math.abs(a - k[0]) < 0.02) return k[1]
        return a.toFixed(2) + ":1"
    }
    function quality(w, h) {
        if (!w || !h) return ""
        return w >= 3200 || h >= 2000 ? "4K UHD" : w >= 1800 || h >= 1000 ? "Full HD" : w >= 1200 || h >= 700 ? "HD" : "SD"
    }
    function shortQuality(w, h) {
        if (!w || !h) return ""
        return w >= 3200 || h >= 2000 ? "4K" : w >= 1800 || h >= 1000 ? "1080p" : w >= 1200 || h >= 700 ? "720p" : "SD"
    }
    function codec(t) {
        if (!t) return ""
        const names = { h264: "H.264 (AVC)", hevc: "HEVC (H.265)", av01: "AV1", vp90: "VP9", vp80: "VP8", mp4a: "AAC", mpga: "MP3",
                        "a52 ": "AC-3", a52: "AC-3", eac3: "E-AC-3", dts: "DTS", flac: "FLAC", opus: "Opus", vorb: "Vorbis",
                        subt: "Text", tx3g: "Text (MP4)", ssa: "SSA/ASS", pgs: "PGS", dvbs: "DVB", spu: "DVD", webv: "WebVTT", araw: "PCM", s16l: "PCM" }
        return names[t.codec] || t.codecName || t.codec
    }
    function profile(t) {
        if (!t || t.profile < 0) return ""
        if (t.codec === "h264") {
            const p = { 66: "Baseline", 77: "Main", 88: "Extended", 100: "High", 110: "High 10", 122: "High 4:2:2", 244: "High 4:4:4" }[t.profile]
            return p ? (t.level > 0 ? p + " @ L" + (t.level / 10).toFixed(1) : p) : ""
        }
        if (t.codec === "hevc") {
            const p = { 1: "Main", 2: "Main 10", 3: "Main Still Picture", 4: "Range Extensions" }[t.profile]
            return p ? (t.level > 0 ? p + " @ L" + (t.level / 30).toFixed(1) : p) : ""
        }
        return ""
    }
    function bitrate(bps) {
        if (!bps) return ""
        return bps >= 1e6 ? (bps / 1e6).toFixed(1) + " Mbps" : Math.round(bps / 1000) + " kbps"
    }
    function language(code) {
        if (!code) return ""
        if (code.length === 2) {
            const name = Qt.locale(code).nativeLanguageName
            if (name) return name.charAt(0).toUpperCase() + name.slice(1)
        }
        return code.toUpperCase()
    }
    function year(date) {
        const m = /(\d{4})/.exec(date || "")
        return m ? Number(m[1]) : 0
    }
    function runtime(ms) {
        if (!ms) return ""
        const mins = Math.round(ms / 60000)
        return mins >= 60 ? qsTr("%1h %2m").arg(Math.floor(mins / 60)).arg(mins % 60) : qsTr("%1m").arg(Math.max(1, mins))
    }
    function bytes(n) {
        return n > 0 ? qsTr("%1 (%2 bytes)").arg(MediaInput.formatSize(n)).arg(Number(n).toLocaleString(Qt.locale(), "f", 0)) : ""
    }
}
