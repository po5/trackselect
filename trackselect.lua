-- trackselect.lua
--
-- Because --slang isn't smart enough.
--
-- This script tries to select non-dub
-- audio and subtitle tracks.
-- Idea from https://github.com/siikamiika/scripts/blob/master/mpv%20scripts/dualaudiofix.lua

local tracks = {
    audio = {
        selected = nil,
        best = {},
        expected = "jpn",
        excluded = "commentary,director",
        preferred = ""
    },
    video = {
        selected = nil,
        best = {},
        expected = "",
        excluded = "",
        preferred = ""
    },
    sub = {
        selected = nil,
        best = {},
        expected = "eng",
        excluded = "sign",
        preferred = ""
    }
}

local options = {}

for _type, track in pairs(tracks) do
    options["expected_" .. _type .. "_lang"] = track.expected
    options["excluded_" .. _type .. "_words"] = track.excluded
    options["preferred_" .. _type .. "_words"] = track.preferred
end

mp.options = require "mp.options"
mp.options.read_options(options, "trackselect")

function contains(track, words, attr)
    for word in string.gmatch(words:lower(), "([^,]+)") do
        if string.match(track[attr]:lower(), word) then
            return true
        end
    end
    return false
end

function trackselect()
    local tracklist = mp.get_property_native("track-list")
    for _, track in ipairs(tracklist) do
        if track.selected then
            tracks[track.type].selected = track.id
            if track.external then
                tracks[track.type].best = track
            end
        end
        if next(tracks[track.type].best) == nil or tracks[track.type].selected ~= tracks[track.type].best.id then
            if not track.title or options["excluded_" .. track.type .. "_words"] == "" or not contains(track, options["excluded_" .. track.type .. "_words"], "title") then
                if not track.title or options["preferred_" .. track.type .. "_words"] == "" or contains(track, options["preferred_" .. track.type .. "_words"], "title") then
                    if next(tracks[track.type].best) == nil or options["expected_" .. track.type .. "_lang"] == "" or not contains(tracks[track.type].best, options["expected_" .. track.type .. "_lang"], "lang") then
                        tracks[track.type].best = track
                    end
                end
            end
        end
    end
    for _type, track in pairs(tracks) do
        if next(track.best) ~= nil and track.best.id ~= track.selected then
            mp.set_property(_type:sub(1, 1) .. "id", track.best.id)
        end
    end
end

mp.register_event("file-loaded", trackselect)
