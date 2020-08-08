-- trackselect.lua
--
-- Because --slang isn't smart enough.
--
-- This script tries to select non-dub
-- audio and subtitle tracks.
-- Idea from https://github.com/siikamiika/scripts/blob/master/mpv%20scripts/dualaudiofix.lua

local defaults = {
    audio = {
        selected = nil,
        best = {},
        score = nil,
        preferred = "jpn/japanese",
        excluded = "",
        expected = ""
    },
    video = {
        selected = nil,
        best = {},
        score = nil,
        preferred = "",
        excluded = "",
        expected = ""
    },
    sub = {
        selected = nil,
        best = {},
        score = nil,
        preferred = "eng",
        excluded = "sign",
        expected = ""
    }
}

local options = {
    enabled = true,

    -- Do track selection synchronously, plays nicer with other scripts
    hook = true,

    -- Mimic mpv's track list fingerprint to preserve user-selected tracks
    fingerprint = true
}

for _type, track in pairs(defaults) do
    options["preferred_" .. _type .. "_lang"] = track.preferred
    options["excluded_" .. _type .. "_words"] = track.excluded
    options["expected_" .. _type .. "_words"] = track.expected
end

local tracks = {}
local fingerprint = ""

mp.options = require "mp.options"

function contains(track, words, attr)
    if not track[attr] then return false end
    local i = 0
    if track.external then
        i = 1
    end
    for word in string.gmatch(words:lower(), "([^/]+)") do
        i = i - 1
        if string.match(track[attr]:lower(), word) then
            return i
        end
    end
    return false
end

function preferred(track, words, attr)
    local score = contains(track, words, attr)
    if not score then
        if tracks[track.type].score == nil then
            tracks[track.type].score = -math.huge
            return true
        end
        return false
    end
    if tracks[track.type].score == nil or score > tracks[track.type].score then
        tracks[track.type].score = score
        return true
    end
    return false
end

function copy(obj)
    if type(obj) ~= "table" then return obj end
    local res = {}
    for k, v in pairs(obj) do res[k] = copy(v) end
    return res
end

function track_layout_hash(tracklist)
    local t = {}
    for _, track in ipairs(tracklist) do
        t[#t+1] = string.format("%s-%d-%s-%s-%s-%s", track.type, track.id, tostring(track.default), tostring(track.external), track.lang or "", track.external and "" or (track.title or ""))
    end
    return table.concat(t, "\n")
end

function trackselect()
    mp.options.read_options(options, "trackselect")
    if not options.enabled then return end
    tracks = copy(defaults)
    local filename = mp.get_property("filename/no-ext")
    local tracklist = mp.get_property_native("track-list")
    if options.fingerprint then
        local new_fingerprint = track_layout_hash(tracklist)
        if new_fingerprint == fingerprint then
            return
        end
        fingerprint = new_fingerprint
    end
    for _, track in ipairs(tracklist) do
        if options["preferred_" .. track.type .. "_lang"] ~= "" or options["excluded_" .. track.type .. "_words"] ~= "" or options["expected_" .. track.type .. "_words"] ~= "" then
            if track.selected then
                tracks[track.type].selected = track.id
            end
            if track.external then
                track.title = string.gsub(string.gsub(track.title, "%W", "%%%1"), filename, "")
            end
            if next(tracks[track.type].best) == nil or not (tracks[track.type].best.external and tracks[track.type].best.lang ~= nil) then
                if options["excluded_" .. track.type .. "_words"] == "" or not contains(track, options["excluded_" .. track.type .. "_words"], "title") then
                    if options["expected_" .. track.type .. "_words"] == "" or contains(track, options["expected_" .. track.type .. "_words"], "title") then
                        if options["preferred_" .. track.type .. "_lang"] == "" or preferred(track, options["preferred_" .. track.type .. "_lang"], "lang") or (track.external and track.lang == nil and (not tracks[track.type].best.external or tracks[track.type].best.lang == nil)) then
                            tracks[track.type].best = track
                        end
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

if options.hook then
    mp.add_hook("on_preloaded", 50, trackselect)
else
    mp.register_event("file-loaded", trackselect)
end
