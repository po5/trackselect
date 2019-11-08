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
        preferred = "jpn,japanese",
        excluded = "commentary,director",
        expected = ""
    },
    video = {
        selected = nil,
        best = {},
        preferred = "",
        excluded = "",
        expected = ""
    },
    sub = {
        selected = nil,
        best = {},
        preferred = "eng",
        excluded = "sign",
        expected = ""
    }
}

local options = {
    enabled = true
}

for _type, track in pairs(tracks) do
    options["preferred_" .. _type .. "_lang"] = track.preferred
    options["excluded_" .. _type .. "_words"] = track.excluded
    options["expected_" .. _type .. "_words"] = track.expected
end

mp.options = require "mp.options"

function contains(track, words, attr)
    for word in string.gmatch(words:lower(), "([^,]+)") do
        if string.match(track[attr]:lower(), word) then
            return true
        end
    end
    return false
end

function trackselect()
    mp.options.read_options(options, "trackselect")
    if not options.enabled then return end

    local tracklist = mp.get_property_native("track-list")
    for _, track in ipairs(tracklist) do
        if track.selected then
            tracks[track.type].selected = track.id
            if track.external then
                tracks[track.type].best = track
            end
        end
        if next(tracks[track.type].best) == nil or not tracks[track.type].best.external then
            if not track.title or options["excluded_" .. track.type .. "_words"] == "" or not contains(track, options["excluded_" .. track.type .. "_words"], "title") then
                if not track.title or options["expected_" .. track.type .. "_words"] == "" or contains(track, options["expected_" .. track.type .. "_words"], "title") then
                    if next(tracks[track.type].best) == nil or options["preferred_" .. track.type .. "_lang"] == "" or not contains(tracks[track.type].best, options["preferred_" .. track.type .. "_lang"], "lang") then
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
