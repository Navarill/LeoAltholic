local function get(tbl, k, ...)
    if tbl == nil or tbl[k] == nil then return nil end
    if select('#', ...) == 0 then return tbl[k] end
    return get(tbl[k], ...)
end

local function resolveChar(charKey)
    if not charKey then
        return LeoAltholic.globalData.CharList[LeoAltholic.CharId], LeoAltholic.CharId
    end
    local char = LeoAltholic.globalData.CharList[charKey]
    if char then
        return char, charKey
    end
    for id, c in pairs(LeoAltholic.globalData.CharList) do
        if c.bio and c.bio.name == charKey then
            return c, id
        end
    end
    return nil, charKey
end

--[[
Return the timestamp from today's reset (specifically for craft writs)
]]
function LeoAltholic.TodayReset()
    local diff = zo_floor(GetDiffBetweenTimeStamps(GetTimeStamp(), 1538190000) / 86400)
    return 1538190000 + (diff * 86400)
end

--[[
Return if the timestamp is after the today's reset.
]]
function LeoAltholic.IsAfterReset(timestamp)
    return timestamp >= LeoAltholic.TodayReset()
end

--[[
Return if the timestamp is before the today's reset.
]]
function LeoAltholic.IsBeforeReset(timestamp)
    return timestamp <= LeoAltholic.TodayReset()
end

--[[
Formats a time
]]
function LeoAltholic.FormatTime(seconds, short, colorizeCountdown)
    if short == nil then short = false end
    local formats = {
        dhm = SI_TIME_FORMAT_DDHHMM_DESC_SHORT,
        day = SI_TIME_FORMAT_DAYS,
        hm = SI_TIME_FORMAT_HHMM_DESC_SHORT,
        hms = SI_TIME_FORMAT_HHMMSS_DESC_SHORT,
        hour = SI_TIME_FORMAT_HOURS,
        ms = SI_TIME_FORMAT_MMSS_DESC_SHORT,
        m = SI_TIME_FORMAT_MINUTES
    }
    if seconds and seconds > 0 then
        local ss = seconds % 60
        local mm = math.floor(seconds / 60)
        local hh = math.floor(mm / 60)
        mm = mm % 60
        local dn = math.floor(hh / 24)
        local hhdn = hh - (dn*24)

        local ssF = string.format("%02d", ss)
        local mmF = string.format("%02d", mm)
        local hhF = string.format("%02d", hh)
        local hhdnF = string.format("%02d", hhdn)

        local result = ''
        if dn > 0 then
            if short then
                result = ZO_CachedStrFormat(GetString(formats.day), dn) .." "..ZO_CachedStrFormat(GetString(formats.hour), hhdnF)
            else
                result = ZO_CachedStrFormat(GetString(formats.dhm), dn, hhdnF, mmF)
            end
        elseif hh > 0 then
            if short then
                result = ZO_CachedStrFormat(GetString(formats.hm), hhF, mmF)
            else
                result = ZO_CachedStrFormat(GetString(formats.hms), hhF, mmF, ssF)
            end
        elseif mm >= 0 then result = ZO_CachedStrFormat(GetString(formats.ms), mmF, ssF)
        end
        if colorizeCountdown == true then
            if seconds < 3600 then result = '|c'..LeoAltholic.color.hex.red..result..'|r'
            elseif seconds < 86400 then result = '|c'..LeoAltholic.color.hex.yellow..result..'|r'
            elseif seconds < 604800 then result = '|c'..LeoAltholic.color.hex.white..result..'|r'
            else result = '|c'..LeoAltholic.color.hex.green..result..'|r' end
        end
        return result
    else return '|cFF4020'..ZO_CachedStrFormat(GetString(formats.m), 0)..'|r' end
end

function LeoAltholic.TimeAgo(timestamp)
    local diff = GetTimeStamp() - timestamp
    local ago
    if diff < 3600 then
        ago = ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_MINUTES), math.floor(diff / 60))
    elseif diff < 86400 then
        ago = ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_HOURS), math.floor(diff / 3600))
    else
        ago = ZO_CachedStrFormat(GetString(SI_TIME_FORMAT_DAYS), math.floor(diff / 86400))
    end
    return ZO_CachedStrFormat(GetString(SI_TIME_DURATION_AGO), ago)
end

--[[
Return if the craft is done for the day for the charId (if not specified, the current character is used)
]]
function LeoAltholic.IsWritDoneToday(craft, charId)
    local char = resolveChar(charId)
    if not char then return end
    for _, writ in pairs(char.quests.writs) do
        if craft == writ.craft then
            return writ.lastDone ~= nil and writ.lastStarted ~= nil and LeoAltholic.IsAfterReset(writ.lastDone) and writ.lastDone > writ.lastStarted and LeoAltholic.IsAfterReset(writ.lastStarted)
        end
    end
    return false
end

function LeoAltholic.IsWritStartedToday(craft, charId)
    local char = resolveChar(charId)
    if not char then return end
    for _, writ in pairs(char.quests.writs) do
        if craft == writ.craft then
            return writ.lastStarted ~= nil and LeoAltholic.IsAfterReset(writ.lastStarted)
        end
    end
    return false
end

function LeoAltholic.HasStillResearchFor(craft, charId)
    local char = resolveChar(charId)
    if not char then return end
    for line = 1, GetNumSmithingResearchLines(craft) do
        local _, _, numTraits = GetSmithingResearchLineInfo(craft, line)
        for trait = 1, numTraits do
            if not char.research.done[craft][line][trait] then
                return true
            end
        end
    end
end

function LeoAltholic.GetNumMissingTraitsFor(craft, charId)
    local char, resolvedId = resolveChar(charId)
    if not char then return end
    local missing = 0
    for line = 1, GetNumSmithingResearchLines(craft) do
        local _, _, numTraits = GetSmithingResearchLineInfo(craft, line)
        for trait = 1, numTraits do
            if not LeoAltholic.CharKnowsTrait(craft, line, trait, resolvedId) then
                missing = missing + 1
            end
        end
    end
    return missing
end

function LeoAltholic.CharKnowsTrait(craftSkill, line, trait, charId)
    local char = resolveChar(charId)
    if not char then return end
    if not char.research.done then return false end
    return get(char.research.done, craftSkill, line, trait) == true
end

function LeoAltholic.ResearchStatus(craftSkill, line, trait, charId)
    local char, resolvedId = resolveChar(charId)
    if not char then return false, false end

    local isKnown = LeoAltholic.CharKnowsTrait(craftSkill, line, trait, resolvedId)
    local isResearching = false

    if char.research and char.research.doing and char.research.doing[craftSkill] then
        for _, researching in pairs(char.research.doing[craftSkill]) do
            if researching.line == line and researching.trait == trait then
                isResearching = researching.doneAt ~= nil and researching.doneAt > GetTimeStamp()
                break
            end
        end
    end

    return isKnown, isResearching
end

function LeoAltholic.GetNumTraitKnownPerLine(charId)
    local _, resolvedId = resolveChar(charId)
    local levels = {}
    for _,craft in pairs(LeoAltholic.craftResearch) do
        levels[craft] = {}
        for line = 1, GetNumSmithingResearchLines(craft) do
            levels[craft][line] = 0
            local _, _, numTraits = GetSmithingResearchLineInfo(craft, line)
            for trait = 1, numTraits do
                if LeoAltholic.CharKnowsTrait(craft, line, trait, resolvedId) then
                    levels[craft][line] = levels[craft][line] + 1
                end
            end
        end
    end
    return levels
end

--[[
Return the number of researches in progress, the total and the time of the first one to be completed (can be 0 or negative,
  indicating it's done)
]]
function LeoAltholic.GetResearchCounters(craft, charId)
    local char, resolvedId = resolveChar(charId)
    if not char then return end
    local lowest = -1
    if #char.research.doing[craft] > 0 then
        local research = char.research.doing[craft][1]
        if resolvedId == LeoAltholic.CharId then
            local _, remaining = GetSmithingResearchLineTraitTimes(craft, research.line, research.trait)
            if remaining ~= nil then
                research.doneAt = remaining + GetTimeStamp()
            end
        else
            local now = GetTimeStamp()
            local remaining = GetDiffBetweenTimeStamps(research.doneAt, now)
            research.doneAt = remaining + now
        end
        lowest = research.doneAt
    end
    return #char.research.doing[craft], char.research.done[craft].max, lowest
end

local function copy(obj, seen)
    return obj -- major performance boost ...
end

--[[
Return a copy of the complete table with all tracked chars.
]]
function LeoAltholic.ExportCharacters(forceUpdate)
    LeoAltholic.GetCharacters(forceUpdate)
    local chars = copy(LeoAltholic.charList)
    return chars
end

--[[
Return the list of character names
]]
function LeoAltholic.GetCharactersNames()
    local list = {}
    for _, char in pairs(LeoAltholic.GetCharacters()) do
        table.insert(list, char.bio.name)
    end
    return list
end

--[[
Return all info on 1 char by character ID (id64)
]]
function LeoAltholic.GetCharById(charId, forceUpdate)
    if forceUpdate then
        LeoAltholic.GetCharacters(true)
    end
    return LeoAltholic.globalData.CharList[charId]
end

--[[
Return all info on 1 char by name
]]
function LeoAltholic.GetCharByName(name, forceUpdate)
    local chars = LeoAltholic.ExportCharacters(forceUpdate)
    for k, v in pairs(chars) do
        if v.bio.name == name then return v end
    end
    return nil
end

--[[
Return all info on the current char
]]
function LeoAltholic.GetMyself()
    local myself = copy(LeoAltholic.globalData.CharList[LeoAltholic.CharId])
    return myself
end

--[[
Return if a specific tab is visible
]]
function LeoAltholic.IsTabVisible(tab)
    return LeoAltholic.hidden == false and LeoAltholic.globalData.activeTab == tab
end