LeoAltholic.timerQueue = {}
LeoAltholic.charList = {}
LeoAltholic.lastUpdatedCharList = nil
LeoAltholic.initialized = false
LeoAltholic.numUpdates = 0

LeoAltholic.maxTraits = select(3,GetSmithingResearchLineInfo(CRAFTING_TYPE_BLACKSMITHING,1))
LeoAltholic.jewelryMaxTraits = select(3,GetSmithingResearchLineInfo(CRAFTING_TYPE_JEWELRYCRAFTING,1))

local DARK_BROTHERHOOD = 118
local THIEVES_GUILD = 117
local LEGERDEMAIN = 111
local SOUL_MAGIC = 72

function LeoAltholic.GetMaxRank(skillType, skillLine)
    if skillType == SKILL_TYPE_AVA or
        skillType == SKILL_TYPE_GUILD or
        skillType == SKILL_TYPE_WORLD then
        local _, _, _, skillLineId = GetSkillLineInfo(skillType, skillLine)
        if skillLineId == THIEVES_GUILD then
            return 12
        end
        if skillLineId == DARK_BROTHERHOOD then
            return 12
        end
        if skillLineId == LEGERDEMAIN then
            return 20
        end
        if skillLineId == SOUL_MAGIC then
            return 6
        end
        return 10
    end
    return 50
end

local function loadPlayerDataPart(skillType, baseElem)
    if skillType == nil then
        return
    end
    local numSkillLines = GetNumSkillLines(skillType)
    for i = 1, numSkillLines do
        local name, rank, discovered, lineId, advised, unlockText = GetSkillLineInfo(skillType,i)
        if name == nil then
            name = i;
        end
        if discovered then
            baseElem[i] = {}
            local baseElemTable = baseElem[i]
            local qty = GetNumSkillAbilities(skillType, i)
            baseElemTable.name = name
            baseElemTable.id = i
            baseElemTable.qty = qty
            baseElemTable.rank = rank
            baseElemTable.lineId = lineId

            baseElemTable.list = {}

            for aj = 1, qty do
                local name2, icon, earnedRank, passive, ultimate, purchased, progressionIndex = GetSkillAbilityInfo(skillType, i, aj)
                local currentUpgradeLevel, maxUpgradeLevel = GetSkillAbilityUpgradeInfo(skillType, i, aj)
                if rank >= earnedRank then
                    local _, _, nextUpgradeEarnedRank = GetSkillAbilityNextUpgradeInfo(skillType, i, aj)
                    local plainName = ZO_CachedStrFormat(SI_ABILITY_NAME, name2)
                    name2 = ZO_Skills_GenerateAbilityName(SI_ABILITY_NAME_AND_UPGRADE_LEVELS, name2, currentUpgradeLevel, maxUpgradeLevel, progressionIndex)
                    baseElemTable.list[aj] = {}
                    local selL = baseElemTable.list[aj]
                    selL.plainName = plainName
                    selL.name = name2
                    selL.earnedRank = earnedRank or 0
                    selL.level = currentUpgradeLevel
                    selL.maxLevel = maxUpgradeLevel
                    selL.nextUpgradeEarnedRank = nextUpgradeEarnedRank
                    if passive then
                        selL.passive = passive
                    end
                    if ultimate then
                        selL.ultimate = ultimate
                    end
                end
            end
        end
    end
end

function LeoAltholic.GetCraftFromQuest(questName)
    if not string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_WRIT))) then return nil end

    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_ALCHEMIST))) then return CRAFTING_TYPE_ALCHEMY end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_BLACKSMITH))) then return CRAFTING_TYPE_BLACKSMITHING end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_CLOTHIER))) then return CRAFTING_TYPE_CLOTHIER end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_ENCHANTER))) then return CRAFTING_TYPE_ENCHANTING end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_JEWELRY))) then return CRAFTING_TYPE_JEWELRYCRAFTING end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_PROVISIONER))) then return CRAFTING_TYPE_PROVISIONING end
    if string.find(ZO_CachedStrFormat("<<z:1>>",questName), ZO_CachedStrFormat("<<z:1>>",GetString(LEOALT_WOODWORKER))) then return CRAFTING_TYPE_WOODWORKING end

    return nil
end

local function createQuestEntry(questId)
    local questName,backgroundText,activeStepText,activeStepType, activeStepTrackerOverrideText, completed, tracked, questLevel,pushed,questType,instanceDisplayType = GetJournalQuestInfo(questId)
    local repeatType = GetJournalQuestRepeatType(questId)
    local locationInfo
    if questType == QUEST_TYPE_GUILD then
        locationInfo = GetString(SI_QUESTTYPE3)
    elseif questType == QUEST_TYPE_MAIN_STORY then
        locationInfo = GetString(SI_QUESTTYPE2)
    else
        locationInfo = GetJournalQuestLocationInfo(questId)
    end
    local quest = {
        name = questName,
        backgroundText = backgroundText,
        activeStepText = activeStepText,
        activeStepType = activeStepType,
        activeStepTrackerOverrideText = activeStepTrackerOverrideText,
        questLevel = questLevel,
        questType = questType,
        instanceDisplayType = instanceDisplayType,
        location = locationInfo,
        repeatType = repeatType,
        isDaily = repeatType == QUEST_REPEAT_DAILY,
        isCrafting = questType == QUEST_TYPE_CRAFTING,
        questIndex = questId
    }
    if quest.isCrafting then
        quest.craft = LeoAltholic.GetCraftFromQuest(quest.name)
    end
    return quest
end

local function checkQuestForWrits(questName)
    local myChar = LeoAltholic.globalData.CharList[LeoAltholic.CharId]
    if not myChar then return end
    for i,trackedQuest in pairs(myChar.quests.writs) do
        if (trackedQuest.name == questName) then
            myChar.quests.writs[i].lastStarted = GetTimeStamp()
            myChar.quests.writs[i].lastPreDeliver = nil
            myChar.quests.writs[i].lastUpdated = nil
            LeoAltholic.ChecklistUI.startedWrit(trackedQuest.craft)
            local numConditions = GetJournalQuestNumConditions(trackedQuest.questIndex, QUEST_MAIN_STEP_INDEX)
            local hasUpdated = false
            for condition = 1, numConditions do
                local current, max = GetJournalQuestConditionValues(trackedQuest.questIndex, QUEST_MAIN_STEP_INDEX, condition)
                if hasUpdated == false and current > 0 then
                    hasUpdated = true
                end
                local condText = GetJournalQuestConditionInfo(trackedQuest.questIndex, QUEST_MAIN_STEP_INDEX, condition)
                if string.find(condText, GetString(LEOALT_DELIVER)) then
                    myChar.quests.writs[i].lastPreDeliver = GetTimeStamp()
                    LeoAltholic.ChecklistUI.preDeliverWrit(trackedQuest.craft)
                    hasUpdated = false
                    break
                end
            end
            if hasUpdated then
                myChar.quests.writs[i].lastUpdated = GetTimeStamp()
                LeoAltholic.ChecklistUI.updateWrit(trackedQuest.craft)
            end
            LeoAltholic.UI.writsList:RefreshData()
            return
        end
    end
end

local function initAccountData()
    if LeoAltholic.globalData.AccountData == nil then LeoAltholic.globalData.AccountData = {} end

    if LeoAltholic.globalData.AccountData.inventory == nil then
        LeoAltholic.globalData.AccountData.inventory = {}
        LeoAltholic.globalData.AccountData.inventory[BAG_BANK] = {
            size = GetBagSize(BAG_BANK),
            used = GetNumBagUsedSlots(BAG_BANK),
            free = GetNumBagFreeSlots(BAG_BANK),
            list = {}
        }
        LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK] = {
            size = GetBagSize(BAG_SUBSCRIBER_BANK),
            used = GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK),
            free = GetNumBagFreeSlots(BAG_SUBSCRIBER_BANK),
            list = {}
        }
    end
    if LeoAltholic.globalData.AccountData.inventory[BAG_BANK].list == nil then
        LeoAltholic.globalData.AccountData.inventory[BAG_BANK].list = {}
        LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].list = {}
    end

    LeoAltholic.globalData.AccountData.inventory[BAG_BANK].size = GetBagSize(BAG_BANK)
    LeoAltholic.globalData.AccountData.inventory[BAG_BANK].used = GetNumBagUsedSlots(BAG_BANK)
    LeoAltholic.globalData.AccountData.inventory[BAG_BANK].free = GetNumBagFreeSlots(BAG_BANK)

    LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].size = GetBagSize(BAG_SUBSCRIBER_BANK)
    LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].used = GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
    LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].free = GetNumBagFreeSlots(BAG_SUBSCRIBER_BANK)

    LeoAltholic.globalData.AccountData.inventory.money = GetBankedMoney()
    LeoAltholic.globalData.AccountData.inventory.ap = GetCurrencyAmount(CURT_ALLIANCE_POINTS, CURRENCY_LOCATION_BANK)
    LeoAltholic.globalData.AccountData.inventory.telvar = GetCurrencyAmount(CURT_TELVAR_STONES, CURRENCY_LOCATION_BANK)
    LeoAltholic.globalData.AccountData.inventory.writVoucher = GetCurrencyAmount(CURT_WRIT_VOUCHERS, CURRENCY_LOCATION_BANK)
    LeoAltholic.globalData.AccountData.inventory.soulGemFilled = LeoAltholic.globalData.AccountData.inventory.soulGemFilled or 0
    LeoAltholic.globalData.AccountData.inventory.soulGemEmpty = LeoAltholic.globalData.AccountData.inventory.soulGemEmpty or 0
end

local function initCharsData()
    if LeoAltholic.globalData.CharList == nil then LeoAltholic.globalData.CharList = {} end

    LeoAltholic.CharName = GetUnitName("player")
    LeoAltholic.CharId = GetCurrentCharacterId()

    local function getStat(stat) return GetPlayerStat(stat, STAT_BONUS_OPTION_APPLY_BONUS) end

    local validIds = {}
    local numChars = GetNumCharacters()
    for i = 1, numChars do
        local _, _, _, _, _, _, id = GetCharacterInfo(i)
        if id then
            validIds[id] = true
        end
    end
    for k, _ in pairs(LeoAltholic.globalData.CharList) do
        if not validIds[k] then
            LeoAltholic.globalData.CharList[k] = nil
        end
    end

    LeoAltholic.CharNum = 0
    local char = LeoAltholic.globalData.CharList[LeoAltholic.CharId] or {
        bio = {},
        quests = {
            actives = {},
            tracked = {},
            writs = {}
        }
    }

    char.bio.id = LeoAltholic.CharId
    char.bio.name = LeoAltholic.CharName
    char.bio.gender = GetUnitGender("player")
    if char.bio.gender == 1 then
        char.bio.genderName = GetString(SI_GENDER1)
    else
        char.bio.genderName = GetString(SI_GENDER2)
    end
    char.bio.level = GetUnitLevel("player")
    char.bio.effectiveLevel = GetUnitEffectiveLevel("player")
    char.bio.isChampion = IsUnitChampion("player")
    char.bio.canChampion = CanUnitGainChampionPoints("player")
    char.bio.championPoints = GetPlayerChampionPointsEarned()
    char.bio.race = GetUnitRace("player")
    char.bio.raceId = GetUnitRaceId("player")
    char.bio.class = GetUnitClass("player")
    char.bio.classId = GetUnitClassId("player")
    char.bio.alliance = {
        id = GetUnitAlliance("player"),
        name = GetAllianceName(GetUnitAlliance("player")),
        rank = GetUnitAvARank("player"),
        points = GetCarriedCurrencyAmount(CURT_ALLIANCE_POINTS)
    }
    char.secondsPlayed = GetSecondsPlayed()
    char.bounty = GetBounty()

    local riding = {GetRidingStats()}
    local ridetime = GetTimeUntilCanBeTrained()/1000 or 0
    if ridetime > 1 then ridetime = ridetime + GetTimeStamp() end

    if char.attributes and char.attributes.riding and char.attributes.riding.time and char.attributes.riding.time > 0 and
            GetDiffBetweenTimeStamps(char.attributes.riding.time, GetTimeStamp()) < 0 then
        local data = {
            id = '$M' .. LeoAltholic.CharId,
            charId = LeoAltholic.CharId,
            charName = char.bio.name,
            info = ZO_CachedStrFormat(GetString(LEOALT_MOUNT_FINISHED), char.bio.name),
            time = char.attributes.riding.time
        }
        LeoAltholic.AddToQueue(data)
    end

    char.attributes = {
        unspent = GetAttributeUnspentPoints(),
        health = {
            points = GetAttributeSpentPoints(ATTRIBUTE_HEALTH),
            max = getStat(STAT_HEALTH_MAX),
            recovery = getStat(STAT_HEALTH_REGEN_COMBAT)
        },
        magicka = {
            points = GetAttributeSpentPoints(ATTRIBUTE_MAGICKA),
            max = getStat(STAT_MAGICKA_MAX),
            recovery = getStat(STAT_MAGICKA_REGEN_COMBAT)
        },
        stamina = {
            points = GetAttributeSpentPoints(ATTRIBUTE_STAMINA),
            max = getStat(STAT_STAMINA_MAX),
            recovery = getStat(STAT_STAMINA_REGEN_COMBAT)
        },
        riding = {
            capacity = riding[1],
            capacityMax = riding[2],
            stamina = riding[3],
            staminaMax = riding[4],
            speed = riding[5],
            speedMax = riding[6],
            time = ridetime
        },
        weapon = {
            damage = getStat(STAT_WEAPON_POWER),
            critical = getStat(STAT_CRITICAL_STRIKE),
            criticalChance = GetCriticalStrikeChance(getStat(STAT_CRITICAL_STRIKE))
        },
        spell = {
            damage = getStat(STAT_SPELL_POWER),
            critical = getStat(STAT_SPELL_CRITICAL),
            criticalChance = GetCriticalStrikeChance(getStat(STAT_SPELL_CRITICAL))
        }
    }
    char.attributes.total = char.attributes.unspent + char.attributes.health.points + char.attributes.magicka.points + char.attributes.stamina.points

    char.resistances = {
        armor            = getStat(STAT_ARMOR_RATING),
        spell            = getStat(STAT_SPELL_RESIST),
        crit             = getStat(STAT_CRITICAL_RESISTANCE),
        cold             = getStat(STAT_DAMAGE_RESIST_COLD),
        disease          = getStat(STAT_DAMAGE_RESIST_DISEASE),
        drown            = getStat(STAT_DAMAGE_RESIST_DROWN),
        earth            = getStat(STAT_DAMAGE_RESIST_EARTH),
        fire             = getStat(STAT_DAMAGE_RESIST_FIRE),
        generic          = getStat(STAT_DAMAGE_RESIST_GENERIC),
        magic            = getStat(STAT_DAMAGE_RESIST_MAGIC),
        oblivion         = getStat(STAT_DAMAGE_RESIST_OBLIVION),
        resistPhysical   = getStat(STAT_DAMAGE_RESIST_PHYSICAL),
        poison           = getStat(STAT_DAMAGE_RESIST_POISON),
        shock            = getStat(STAT_DAMAGE_RESIST_SHOCK),
        start            = getStat(STAT_DAMAGE_RESIST_START),
        mitigation       = getStat(STAT_MITIGATION),
        physical         = getStat(STAT_PHYSICAL_RESIST),
        spell_mitigation = getStat(STAT_SPELL_MITIGATION),
        miss             = getStat(STAT_MISS),
        block            = getStat(STAT_BLOCK),
        dodge            = getStat(STAT_DODGE)
    }

    char.skills = {}
    char.skills.unspent = GetAvailableSkillPoints()
    char.skills.skyShards = GetNumSkyShards()

    char.skills.armor = {}
    loadPlayerDataPart(SKILL_TYPE_ARMOR, char.skills.armor)

    char.skills.world = {}
    loadPlayerDataPart(SKILL_TYPE_WORLD, char.skills.world)

    char.skills.class = {}
    loadPlayerDataPart(SKILL_TYPE_CLASS, char.skills.class)

    char.skills.guild = {}
    loadPlayerDataPart(SKILL_TYPE_GUILD, char.skills.guild)

    char.skills.racial = {}
    loadPlayerDataPart(SKILL_TYPE_RACIAL, char.skills.racial)

    char.skills.weapon = {}
    loadPlayerDataPart(SKILL_TYPE_WEAPON, char.skills.weapon)

    char.skills.ava = {}
    loadPlayerDataPart(SKILL_TYPE_AVA, char.skills.ava)

    char.skills.craft = {}
    loadPlayerDataPart(SKILL_TYPE_TRADESKILL, char.skills.craft)

    local function GetCraftBonus(craft)
        local skillType0, skillId = GetCraftingSkillLineIndices(craft)
        local _, rank = GetSkillLineInfo(skillType0,skillId)
        return {rank = rank, max = GetMaxSimultaneousSmithingResearch(craft) or 1}
    end

    char.research = {}
    char.research.done = {}
    char.research.doing = {}
    for _,craft in pairs(LeoAltholic.craftResearch) do
        char.research.done[craft] = GetCraftBonus(craft)
        char.research.doing[craft] = {}
        for line = 1, GetNumSmithingResearchLines(craft) do
            char.research.done[craft][line] = {}
            local lineName, lineIcon = GetSmithingResearchLineInfo(craft, line)
            for trait = 1, LeoAltholic.maxTraits do
                local traitType, _, known = GetSmithingResearchLineTraitInfo(craft, line, trait)
                if known then
                    char.research.done[craft][line][trait] = true
                else
                    local _,remaining = GetSmithingResearchLineTraitTimes(craft,line,trait)
                    if remaining and remaining > 0 then
                        table.insert(char.research.doing[craft], {
                            craft = craft,
                            line = line,
                            trait = trait,
                            remaining = remaining,
                            doneAt = remaining + GetTimeStamp()
                        })
                        local data = {
                            id = '$R' .. LeoAltholic.CharId .. craft .. line .. trait,
                            charId = LeoAltholic.CharId,
                            charName = char.bio.name,
                            info = ZO_CachedStrFormat(
                                    GetString(LEOALT_RESEARCH_FINISHED) .. ': |c00FF00<<C:2>> <<C:3>>|r.',
                                    char.bio.name,
                                    GetString('SI_ITEMTRAITTYPE',traitType),
                                    lineName
                            ),
                            time = remaining + GetTimeStamp()
                        }
                        LeoAltholic.AddToQueue(data)
                    end
                end
            end
        end
        table.sort(char.research.doing[craft], function(a, b)
            return a.remaining < b.remaining
        end)
    end

    char.champion = {}
    for disciplineIndex = 1, GetNumChampionDisciplines() do
        local disciplineId = GetChampionDisciplineId(disciplineIndex)
        char.champion[disciplineIndex] = {
            spent = GetNumSpentChampionPoints(disciplineId),
            unspent = GetNumUnspentChampionPoints(disciplineId),
            skills = {}
        }
        for skill = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
            local id = GetChampionSkillId(disciplineIndex, skill)
            char.champion[disciplineIndex].skills[skill] = GetNumPointsSpentOnChampionSkill(id)
        end
    end

    char.inventory = {}
    char.inventory.size = GetBagSize(BAG_BACKPACK)
    char.inventory.used = GetNumBagUsedSlots(BAG_BACKPACK)
    char.inventory.free = GetNumBagFreeSlots(BAG_BACKPACK)

    local _, _, soulGemEmpty = GetSoulGemInfo(SOUL_GEM_TYPE_EMPTY, char.bio.level, true)
    local _, _, soulGemFilled = GetSoulGemInfo(SOUL_GEM_TYPE_FILLED, char.bio.level, true)
    char.inventory.soulGemEmpty = soulGemEmpty
    char.inventory.soulGemFilled = soulGemFilled

    char.inventory.ap = GetAlliancePoints()
    char.inventory.gold = GetCurrentMoney()
    char.inventory.telvar = GetCarriedCurrencyAmount(CURT_TELVAR_STONES)
    char.inventory.writVoucher = GetCarriedCurrencyAmount(CURT_WRIT_VOUCHERS)

    char.inventory[BAG_WORN] = {}
    char.inventory[BAG_BACKPACK] = {}
    if LeoAltholic.globalData.settings.inventory.enabled then
        local bag = SHARED_INVENTORY:GenerateFullSlotData(nil,BAG_WORN,BAG_BACKPACK)
        for _, data in pairs(bag) do
            char.inventory[data.bagId][data.slotIndex] = {
                link = GetItemLink(data.bagId, data.slotIndex),
                name = data.name,
                count = data.stackCount
            }
        end
    end

    if char.stats == nil then char.stats = {} end

    if char.quests == nil then
        char.quests = {
            actives = {},
            tracked = {},
            writs = {}
        }
    end

    if char.quests.writs == nil then char.quests.writs = {} end
    if char.quests.tracked == nil then char.quests.tracked = {} end

    char.quests.actives = {}
    for i = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(i) then
            local quest = createQuestEntry(i)
            table.insert(char.quests.actives, quest)
        end
    end

    LeoAltholic.globalData.CharList[LeoAltholic.CharId] = char
end

local function copy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[copy(k, s)] = copy(v, s) end
    return res
end

function LeoAltholic.GetCharacters(forceUpdate)
    if #LeoAltholic.charList == 0 or forceUpdate == true or GetTimeStamp() - LeoAltholic.lastUpdatedCharList > 10 then
        LeoAltholic.charList = {}
        local i = 1
        for k, v in pairs(LeoAltholic.globalData.CharList) do
            if k == nil then return end
            v.bio.id = v.bio.id or k
            LeoAltholic.charList[i] = copy(v)
            i = i + 1
        end
        table.sort(LeoAltholic.charList, function(a, b)
            return a.bio.name < b.bio.name
        end)
        LeoAltholic.lastUpdatedCharList = GetTimeStamp()
    end
    return LeoAltholic.charList
end

function LeoAltholic.GetItems(char, bagId)
    local itemLines = {}
    local i = 1
    local list
    if char ~= nil and bagId >= 0 then
        list = char.inventory[bagId]
    else
        list = {}
        local n = 0
        for _,v in ipairs(LeoAltholic.globalData.AccountData.inventory[BAG_BANK].list) do n=n+1; list[n]=v end
        for _,v in ipairs(LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].list) do n=n+1; list[n]=v end
    end
    for k, v in pairs(list) do
        if k == nil then return end
        itemLines[i] = copy(v)
        i = i + 1
    end
    table.sort(itemLines, function(a, b)
        return a.name < b.name
    end)

    return itemLines
end

local function formatMessage(message)
    return LeoAltholic.chatPrefix .. message
end

function LeoAltholic.log(message)
    d(formatMessage(message))
end

local function onResearchStarted(eventCode, craft, line, trait)
    local _,remaining = GetSmithingResearchLineTraitTimes(craft,line,trait)
    if not remaining then return end
    table.insert(LeoAltholic.globalData.CharList[LeoAltholic.CharId].research.doing[craft], {
        craft = craft,
        line = line,
        trait = trait,
        remaining = remaining,
        doneAt = remaining + GetTimeStamp()
    })
    if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
        LeoAltholic.UI.researchList:RefreshData()
    end
end

local function onResearchCanceled(eventCode, craft, line, trait)
    for i, research in pairs(LeoAltholic.globalData.CharList[LeoAltholic.CharId].research.doing[craft]) do
        if research.line == line and research.trait == trait then
            table.remove(LeoAltholic.globalData.CharList[LeoAltholic.CharId].research.doing[craft], i)
            if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
                LeoAltholic.UI.researchList:RefreshData()
            end
            return
        end
    end
end

local function onResearchCompleted(eventCode, craft, line, trait)
    LeoAltholic.globalData.CharList[LeoAltholic.CharId].research.done[craft][line][trait] = true
    for i, research in pairs(LeoAltholic.globalData.CharList[LeoAltholic.CharId].research.doing[craft]) do
        if research.line == line and research.trait == trait then
            table.remove(LeoAltholic.globalData.CharList[LeoAltholic.CharId].research.doing[craft], i)
            break
        end
    end

    local lineName = GetSmithingResearchLineInfo(craft, line)
    local traitType = GetSmithingResearchLineTraitInfo(craft, line, trait)

    local name = GetUnitName("player")
    local msg = ZO_CachedStrFormat(
            GetString(LEOALT_RESEARCH_FINISHED) .. ': |c00FF00<<C:2>> <<C:3>>|r.',
            name,
            GetString('SI_ITEMTRAITTYPE',traitType),
            lineName
    )
    if LeoAltholic.globalData.settings.completedResearch.screen == true then
        local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, SOUNDS.SMITHING_FINISH_RESEARCH)
        messageParams:SetText(formatMessage(msg))
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
    end
    if LeoAltholic.globalData.settings.completedResearch.chat == true then
        LeoAltholic.log(msg)
    end
    if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
        LeoAltholic.UI.researchList:RefreshData()
    end
end

function LeoAltholic.AddToQueue(data)
    for x,queue in pairs(LeoAltholic.timerQueue) do
        if queue.id == data.id then
            return
        end
    end
    table.insert(LeoAltholic.timerQueue, data)
end

local function charStillExists(charId)
    return LeoAltholic.globalData.CharList[charId] ~= nil
end

local function processQueue()
    for i, data in pairs(LeoAltholic.timerQueue) do
        if charStillExists(data.charId) and not data.announced and GetDiffBetweenTimeStamps(data.time, GetTimeStamp()) <= 0 then
            if data.charId ~= LeoAltholic.CharId and LeoAltholic.globalData.settings.completedResearch.chat == true then
                LeoAltholic.log(data.info)
            end
            if data.charId == LeoAltholic.CharId and LeoAltholic.globalData.settings.completedResearch.screen == true then
                local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT, SOUNDS.SMITHING_FINISH_RESEARCH)
                messageParams:SetText(formatMessage(data.info))
                CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
            end
            LeoAltholic.timerQueue[i].announced = true
        end
    end
end

local function createMessageQueue()
    for _, char in pairs(LeoAltholic.GetCharacters()) do
        if char.bio.id ~= LeoAltholic.CharId then
            if char.attributes.riding.time and char.attributes.riding.time > 0 and GetDiffBetweenTimeStamps(char.attributes.riding.time, GetTimeStamp()) < 0 then
                local data = {
                    id = '$M' .. char.bio.id,
                    charId = char.bio.id,
                    charName = char.bio.name,
                    info = ZO_CachedStrFormat(GetString(LEOALT_MOUNT_FINISHED), char.bio.name),
                    time = char.attributes.riding.time
                }
                LeoAltholic.AddToQueue(data)
            end
            for _, craft in pairs(LeoAltholic.craftResearch) do
                if char.research.doing[craft] then
                    for _, research in pairs(char.research.doing[craft]) do
                        local lineName, lineIcon = GetSmithingResearchLineInfo(research.craft, research.line)
                        local traitType = GetSmithingResearchLineTraitInfo(research.craft, research.line, research.trait)
                        if research.doneAt ~= nil then
                            local data = {
                                id = '$R' .. char.bio.id .. research.craft .. research.line .. research.trait,
                                charId = char.bio.id,
                                charName = char.bio.name,
                                info = ZO_CachedStrFormat(
                                        GetString(LEOALT_RESEARCH_FINISHED) .. ': |c00FF00<<C:2>> <<C:3>>|r.',
                                        char.bio.name,
                                        GetString('SI_ITEMTRAITTYPE',traitType),
                                        lineName
                                ),
                                time = research.doneAt
                            }
                            LeoAltholic.AddToQueue(data)
                        end
                    end
                end
            end
        end
    end
end

local function updateMyself()
    local myChar = LeoAltholic.globalData.CharList[LeoAltholic.CharId]
    if not myChar then return end
    myChar.inventory.size = GetBagSize(BAG_BACKPACK)
    myChar.inventory.used = GetNumBagUsedSlots(BAG_BACKPACK)
    myChar.inventory.free = GetNumBagFreeSlots(BAG_BACKPACK)
end

local function onUpdate()
    processQueue()

    updateMyself()
    LeoAltholic.ChecklistUI.checkReset()
    LeoAltholic.ToolbarUI:update()

    LeoAltholic.numUpdates = LeoAltholic.numUpdates + 1

    if LeoAltholic.numUpdates >= 1800 then -- 3600 seconds = 1h, forces update every hour
        LeoAltholic.numUpdates = 1
        if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
            LeoAltholic.UI.researchList:RefreshData()
        end
    end

    if LeoAltholic.isHidden() then return end

    if LeoAltholic.IsTabVisible(LeoAltholic.TAB_BIO) then
        LeoAltholic.UI:updateBio()
    end
    if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
        LeoAltholic.UI:updateResearch()
    end
    if LeoAltholic.IsTabVisible(LeoAltholic.TAB_INVENTORY) then
        LeoAltholic.UI.UpdateInventory()
    end
end

local function trackQuest(questId, automatically)
    local type = GetJournalQuestRepeatType(questId)
    if type ~= QUEST_REPEAT_DAILY then
        if automatically ~= true then
            LeoAltholic.log(GetString(LEOALT_TRACK_ONLY_DAILY))
        end
        return
    end
    local myChar = LeoAltholic.globalData.CharList[LeoAltholic.CharId]
    local lookInto
    local quest = createQuestEntry(questId)
    if quest.isCrafting then
        lookInto = myChar.quests.writs
    else
        lookInto = myChar.quests.tracked
    end
    for trackedIndex,trackedQuest in pairs(lookInto) do
        if (trackedQuest.name == quest.name) then
            if quest.isCrafting then
                myChar.quests.writs[trackedIndex].questIndex = questId
            else
                myChar.quests.tracked[trackedIndex].questIndex = questId
            end
            if automatically ~= true then
                LeoAltholic.log(ZO_CachedStrFormat(GetString(LEOALT_QUEST_ALREADY_TRACKED), quest.name))
            end
            return
        end
    end
    quest.lastDone = nil
    if quest.isCrafting then
        table.insert(myChar.quests.writs, quest)
    else
        table.insert(myChar.quests.tracked, quest)
    end
    LeoAltholic.log(GetString(LEOALT_TRACKING) .. " " .. quest.name .. "...")
    if quest.isCrafting then
        LeoAltholic.UI.writsList:RefreshData()
    end
end

function LeoAltholic.trackQuest(questId)
    trackQuest(questId)
end

local function onQuestAdded(eventCode, journalQuestIndex, questName, objectiveName)
    local quest = createQuestEntry(journalQuestIndex)
    if quest.isDaily == false then return end
    if LeoAltholic.globalData.settings.tracked.allDaily == true or
            (quest.questType == QUEST_TYPE_CRAFTING and LeoAltholic.globalData.settings.tracked.dailyWrits == true) then
        trackQuest(journalQuestIndex, true)
    end

    checkQuestForWrits(questName)
end

local function onQuestCounterChanged(eventCode, journalQuestIndex, questName, conditionText, conditionType, currConditionVal, newConditionVal, conditionMax, isFailCondition, stepOverrideText, isPushed, isComplete, isConditionComplete, isStepHidden)
    local myChar = LeoAltholic.globalData.CharList[LeoAltholic.CharId]
    if not myChar then return end
    for i,trackedQuest in pairs(myChar.quests.writs) do
        if (trackedQuest.name == questName) then
            myChar.quests.writs[i].lastUpdated = GetTimeStamp()
            LeoAltholic.ChecklistUI.updateWrit(trackedQuest.craft)

            local numConditions = GetJournalQuestNumConditions(journalQuestIndex, QUEST_MAIN_STEP_INDEX)
            for condition = 1, numConditions do
                local cur, max = GetJournalQuestConditionValues(journalQuestIndex, QUEST_MAIN_STEP_INDEX, condition)
                local condText = GetJournalQuestConditionInfo(journalQuestIndex, QUEST_MAIN_STEP_INDEX, condition)
                if string.find(condText, GetString(LEOALT_DELIVER)) then
                    myChar.quests.writs[i].lastPreDeliver = GetTimeStamp()
                    LeoAltholic.ChecklistUI.preDeliverWrit(trackedQuest.craft)
                    break
                end
            end
            LeoAltholic.UI.writsList:RefreshData()

            return
        end
    end
end

local function onQuestRemoved(eventCode, isCompleted, journalQuestIndex, questName, zoneIndex, poiIndex)
    if not isCompleted then
        local myChar = LeoAltholic.globalData.CharList[LeoAltholic.CharId]
        if not myChar then return end
        for i,trackedQuest in pairs(myChar.quests.writs) do
            if (trackedQuest.name == questName) then
                myChar.quests.writs[i].lastStarted = nil
                myChar.quests.writs[i].lastPreDeliver = nil
                myChar.quests.writs[i].lastUpdated = nil
                LeoAltholic.ChecklistUI.stoppedWrit(trackedQuest.craft)
                LeoAltholic.UI.writsList:RefreshData()
                return
            end
        end
    end
end

local function onQuestComplete(eventCode, questName, level, previousExperience, currentExperience, rank, previousPoints, currentPoints)
    local myChar = LeoAltholic.globalData.CharList[LeoAltholic.CharId]
    if not myChar then return end
    for i,trackedQuest in pairs(myChar.quests.writs) do
        if (trackedQuest.name == questName) then
            myChar.quests.writs[i].lastDone = GetTimeStamp()
            LeoAltholic.log(ZO_CachedStrFormat(GetString(LEOALT_QUEST_DONE_TODAY), questName))
            LeoAltholic.UI.writsList:RefreshData()
            LeoAltholic.ChecklistUI.doneWrit(trackedQuest.craft)
            return
        end
    end
    for i,trackedQuest in pairs(myChar.quests.tracked) do
        if (trackedQuest.name == questName) then
            myChar.quests.tracked[i].lastDone = GetTimeStamp()
            LeoAltholic.log(ZO_CachedStrFormat(GetString(LEOALT_QUEST_DONE_TODAY), questName))
            return
        end
    end
end

local function addToBank(bagId, slotIndex, itemLink, name, stackCount)
    if name == nil then name = GetItemName(bagId, slotIndex) end

    table.insert(LeoAltholic.globalData.AccountData.inventory[bagId].list, {
        slotIndex = slotIndex,
        link = itemLink,
        name = name,
        count = stackCount
    })
end

local function removeFromBank(bagId, slotIndex)
    for i, item in pairs(LeoAltholic.globalData.AccountData.inventory[bagId].list) do
        if item.slotIndex == slotIndex then
            table.remove(LeoAltholic.globalData.AccountData.inventory[bagId].list, i)
            return
        end
    end
end

local function updateBank(bagId, slotIndex, stackCount)
    for i, item in pairs(LeoAltholic.globalData.AccountData.inventory[bagId].list) do
        if item.slotIndex == slotIndex then
            LeoAltholic.globalData.AccountData.inventory[bagId].list[i].count =
                LeoAltholic.globalData.AccountData.inventory[bagId].list[i].count + stackCount
            return
        end
    end
end

local function scanBank()
    LeoAltholic.globalData.AccountData.inventory[BAG_BANK].list = {}
    LeoAltholic.globalData.AccountData.inventory[BAG_SUBSCRIBER_BANK].list = {}
    local numEmptySoulGems = 0
    local numFilledSoulGems = 0

    local bagCache = SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BANK, BAG_SUBSCRIBER_BANK)
    for _, data in pairs(bagCache) do
        local itemLink = GetItemLink(data.bagId, data.slotIndex)
        if IsItemSoulGem(SOUL_GEM_TYPE_FILLED, data.bagId, data.slotIndex) then
            numFilledSoulGems = numFilledSoulGems + data.stackCount
        elseif IsItemSoulGem(SOUL_GEM_TYPE_EMPTY, data.bagId, data.slotIndex) then
            numEmptySoulGems = numEmptySoulGems + data.stackCount
        end
        addToBank(data.bagId, data.slotIndex, itemLink, data.name, data.stackCount)
    end

    LeoAltholic.globalData.AccountData.inventory.soulGemEmpty = numEmptySoulGems
    LeoAltholic.globalData.AccountData.inventory.soulGemFilled = numFilledSoulGems
end

local function findIteminBank(bagId, slotIndex)
    for _, item in pairs(LeoAltholic.globalData.AccountData.inventory[bagId].list) do
        if item.slotIndex == slotIndex then return item.link end
    end
end

local function onUpdateBank(eventCode, bagId, slotId, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
    local itemLink = GetItemLink(bagId, slotId)
    local removed = false
    local found = findIteminBank(bagId, slotId)

    if itemLink == nil or itemLink == "" then
        removed = true
        itemLink = findIteminBank(bagId, slotId)
    end

    if not found and stackCountChange > 0 then
        addToBank(bagId, slotId, itemLink, nil, stackCountChange)
    elseif found and not removed then
        updateBank(bagId, slotId, stackCountChange)
    elseif found and removed then
        removeFromBank(bagId, slotId)
    end
end

local function onCloseBank(eventCode, bagId)
    EVENT_MANAGER:UnregisterForEvent(LeoAltholic.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(LeoAltholic.name .. "_SubBank", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
end

local function onOpenBank(eventCode, bagId)
    if (bagId ~= BAG_BANK and bagId ~= BAG_SUBSCRIBER_BANK) or not LeoAltholic.globalData.settings.inventory.enabled then return end
    onCloseBank()

    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onUpdateBank)
    EVENT_MANAGER:AddFilterForEvent(LeoAltholic.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BANK)
    EVENT_MANAGER:AddFilterForEvent(LeoAltholic.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name .. "_SubBank", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, onUpdateBank)
    EVENT_MANAGER:AddFilterForEvent(LeoAltholic.name .. "_SubBank", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_SUBSCRIBER_BANK)
    EVENT_MANAGER:AddFilterForEvent(LeoAltholic.name .. "_SubBank", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)

    scanBank()
end

local function migrateDataToV2()
    LeoAltholic.globalData.settings.toolbar = {
        enabled = false
    }
    if LeoAltholic.globalData.CharList == nil then return end -- fresh install?
    for charKey, char in pairs(LeoAltholic.globalData.CharList) do
        local oldResearch = char.research
        LeoAltholic.globalData.CharList[charKey].research = {}
        LeoAltholic.globalData.CharList[charKey].research.done = {}
        LeoAltholic.globalData.CharList[charKey].research.doing = {}
        for _,craft in pairs(LeoAltholic.craftResearch) do
            LeoAltholic.globalData.CharList[charKey].research.done[craft] = {
                max = oldResearch[craft].max or 0
            }
            LeoAltholic.globalData.CharList[charKey].research.doing[craft] = {}
            for line = 1, GetNumSmithingResearchLines(craft) do
                LeoAltholic.globalData.CharList[charKey].research.done[craft][line] = {}
                local lineName, _, numTraits = GetSmithingResearchLineInfo(craft, line)
                for trait = 1, numTraits do
                    if oldResearch[craft][line][trait] == true then
                        LeoAltholic.globalData.CharList[charKey].research.done[craft][line][trait] = true
                    end
                end
            end
        end
    end
end

local function migrateDataToV3()
    if LeoAltholic.globalData.CharList == nil then return end -- fresh install?
    for charKey, char in pairs(LeoAltholic.globalData.CharList) do
        for i = 1, GetNumChampionDisciplines() do
            if LeoAltholic.globalData.CharList[charKey].champion[i].disciplines or not LeoAltholic.globalData.CharList[charKey].champion[i].spent then
                LeoAltholic.globalData.CharList[charKey].champion[i] = {
                    spent = 0,
                    unspent = 0,
                    skills = {}
                }
            end
        end
    end
end

local function migrateDataToV4()
    if LeoAltholic.globalData.CharList == nil then return end
    local nameToId = {}
    local validIds = {}
    for i = 1, GetNumCharacters() do
        local charName, _, _, _, _, _, charId = GetCharacterInfo(i)
        if charName and charId then
            charName = charName:gsub("%^.+", "")
            nameToId[charName] = charId
            validIds[charId] = true
        end
    end

    local newCharList = {}
    for k, v in pairs(LeoAltholic.globalData.CharList) do
        if validIds[k] then
            v.bio = v.bio or {}
            v.bio.id = k
            newCharList[k] = v
        elseif nameToId[k] then
            local charId = nameToId[k]
            v.bio = v.bio or {}
            v.bio.id = charId
            newCharList[charId] = v
        end
    end
    LeoAltholic.globalData.CharList = newCharList
end

local function initializeVars()
    local charDefault = {
        settings = {
            checklist = {
                enabled = true,
                hidden = false,
                craft = {},
                riding = true
            },
            inventory = {
                enabled = true
            }
        }
    }
    charDefault.settings.checklist.craft[CRAFTING_TYPE_ALCHEMY] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_BLACKSMITHING] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_CLOTHIER] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_ENCHANTING] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_JEWELRYCRAFTING] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_PROVISIONING] = true
    charDefault.settings.checklist.craft[CRAFTING_TYPE_WOODWORKING] = true

    LeoAltholic.charData = ZO_SavedVars:NewCharacterIdSettings("LeoAltholicCharVariables", 2, nil, charDefault)
    LeoAltholic.globalData = ZO_SavedVars:NewAccountWide("LeoAltholicSavedVariables", 2, nil, nil, GetWorldName())
    if not LeoAltholic.globalData.settings or LeoAltholic.globalData.settings == nil then
        LeoAltholic.globalData.settings = {
            tracked = {
                dailyWrits = true,
                allDaily = false
            },
            completedResearch = {
                chat = true,
                screen = true
            },
            toolbar = {
                enabled = false
            },
            checklist = {
                fontScale = 100,
                upwards = false
            },
            inventory = {
                enabled = true
            }
        }
    end

    LeoAltholic.ChecklistUI.normalizeSettings()
    LeoAltholic.ToolbarUI.normalizeSettings()

    if not LeoAltholic.globalData.dataVersion or LeoAltholic.globalData.dataVersion < 2 then
        migrateDataToV2()
        LeoAltholic.globalData.dataVersion = 2
    end
    if LeoAltholic.globalData.dataVersion < 3 then
        migrateDataToV3()
        LeoAltholic.globalData.dataVersion = 3
    end
    if LeoAltholic.globalData.dataVersion < 4 then
        migrateDataToV4()
        LeoAltholic.globalData.dataVersion = 4
    end
    if LeoAltholic.globalData.settings.inventory == nil then
        LeoAltholic.globalData.settings.inventory = {
            enabled = true
        }
    end

    initCharsData()
    initAccountData()
end

local function onGameMenuEnter()
    LeoAltholicChecklist:SetHidden(true)
end

local function onGameMenuExit()
    LeoAltholic.ChecklistUI:CheckHide()
end

local function initialize()
    LeoAltholic.RestorePosition()
    LeoAltholic.ToolbarUI.RestorePosition()
    LeoAltholic.ChecklistUI.RestorePosition()

    LeoAltholic.UI.InitPanels()
    createMessageQueue()

    LeoAltholic.settings = LeoAltholic.Settings:New()
    LeoAltholic.settings:CreatePanel()

    LeoAltholic.initialized = true
    CALLBACK_MANAGER:FireCallbacks("LeoAltholicInitialized")
    LeoAltholic.ToolbarUI:update()
    LeoAltholic.ChecklistUI.initializeQuests()
    LeoAltholic.ChecklistUI.update()
    LeoAltholic.UI:updateResearch()
    LeoAltholic.UI.InitInventory()
end

if QUEST_JOURNAL_KEYBOARD and QUEST_JOURNAL_KEYBOARD.ShowContextMenu then
    ZO_PostHook(QUEST_JOURNAL_KEYBOARD, "ShowContextMenu", function(self, questIndex)
        if questIndex and GetJournalQuestRepeatType(questIndex) == QUEST_REPEAT_DAILY then
            AddMenuItem("Track with " .. LeoAltholic.displayName, function()
                trackQuest(questIndex)
            end)
            ShowMenu(self.control)
        end
    end)
end

local function onNewMovementInUIMode(eventCode)
    if not LeoAltholicWindow:IsHidden() then LeoAltholic.CloseUI() end
end

local function onChampionPerksSceneStateChange(oldState,newState)
    if newState == SCENE_SHOWING then
        if not LeoAltholicWindow:IsHidden() then LeoAltholic.CloseUI() end
    end
end

local function onPlayerDeactivated(event, addonName)
    EVENT_MANAGER:UnregisterForEvent(LeoAltholic.name, EVENT_PLAYER_DEACTIVATED)
    initCharsData()
    initAccountData()
end

local function onRidingSkillImprovement(eventCode, ridingSkill, previous, current, source)
    local riding = {GetRidingStats()}
    local ridetime = GetTimeUntilCanBeTrained()/1000 or 0
    if ridetime > 1 then ridetime = ridetime + GetTimeStamp() end

    LeoAltholic.globalData.CharList[LeoAltholic.CharId].attributes.riding = {
        capacity = riding[1],
        capacityMax = riding[2],
        stamina = riding[3],
        staminaMax = riding[4],
        speed = riding[5],
        speedMax = riding[6],
        time = ridetime
    }
    LeoAltholic.ChecklistUI.doneRiding()
    LeoAltholic.UI.bioList:RefreshData()
end

local function onChampionPointsChanged()
    local myChar = LeoAltholic.globalData.CharList[LeoAltholic.CharId]
    myChar.champion = {}
    for disciplineIndex = 1, GetNumChampionDisciplines() do
        local disciplineId = GetChampionDisciplineId(disciplineIndex)
        myChar.champion[disciplineIndex] = {
            spent = GetNumSpentChampionPoints(disciplineId),
            unspent = GetNumUnspentChampionPoints(disciplineId),
            skills = {}
        }
        for skill = 1, GetNumChampionDisciplineSkills(disciplineIndex) do
            local id = GetChampionSkillId(disciplineIndex, skill)
            myChar.champion[disciplineIndex].skills[skill] = GetNumPointsSpentOnChampionSkill(id)
        end
    end
    LeoAltholic.UI.championList:RefreshData()
end

local function onSkillPointsChanged()
    local char = LeoAltholic.globalData.CharList[LeoAltholic.CharId]
    if not char or not char.research or not char.research.done then return end

    local changed = false
    for _, craft in pairs(LeoAltholic.craftResearch) do
        if char.research.done[craft] then
            local maxSlots = GetMaxSimultaneousSmithingResearch(craft)
            if char.research.done[craft].max ~= maxSlots then
                char.research.done[craft].max = maxSlots
                changed = true
            end
        end
    end

    if changed then
        if LeoAltholic.IsTabVisible(LeoAltholic.TAB_RESEARCH) then
            LeoAltholic.UI.researchList:RefreshData()
        end
        LeoAltholic.ToolbarUI.update()
    end
end
local function onAddOnLoaded(event, addonName)
    if addonName ~= LeoAltholic.name then return end

    EVENT_MANAGER:UnregisterForEvent(LeoAltholic.name, EVENT_ADD_ON_LOADED)
    SCENE_MANAGER:RegisterTopLevel(LeoAltholicWindow, false)
    SCENE_MANAGER:RegisterTopLevel(LeoAltholicInventoryWindow, false)

    if GetDisplayName() == "@LeandroSilva" then
        SLASH_COMMANDS["/rr"] = function(cmd) ReloadUI() end
    end
    SLASH_COMMANDS["/leoalt"] = function(cmd)
        if not cmd or cmd == "" then
            LeoAltholic:ToggleUI()
            return
        end

        if cmd == "checklist" then
            LeoAltholic.ChecklistUI.ToggleUI()
            return
        end
    end

    initializeVars()

    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED, onResearchCompleted)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_SMITHING_TRAIT_RESEARCH_STARTED, onResearchStarted)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_SMITHING_TRAIT_RESEARCH_CANCELED, onResearchCanceled)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_SKILL_POINTS_CHANGED, onSkillPointsChanged)

    initialize()

    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_PLAYER_DEACTIVATED, onPlayerDeactivated)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_QUEST_COMPLETE, onQuestComplete)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_QUEST_ADDED, onQuestAdded)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_QUEST_REMOVED, onQuestRemoved)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, onQuestCounterChanged)

    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_OPEN_BANK, onOpenBank)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_CLOSE_BANK, onCloseBank)

    EVENT_MANAGER:RegisterForUpdate(LeoAltholic.name, 2000, onUpdate)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_NEW_MOVEMENT_IN_UI_MODE, onNewMovementInUIMode)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_RIDING_SKILL_IMPROVEMENT, onRidingSkillImprovement)
    CHAMPION_PERKS_SCENE:RegisterCallback('StateChange', onChampionPerksSceneStateChange)

    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_CRAFTING_STATION_INTERACT, onGameMenuEnter)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_END_CRAFTING_STATION_INTERACT, onGameMenuExit)
    ZO_PreHookHandler(ZO_GameMenu_InGame, "OnShow", onGameMenuEnter)
    ZO_PreHookHandler(ZO_GameMenu_InGame, "OnHide", onGameMenuExit)
    ZO_PreHookHandler(ZO_InteractWindow, "OnShow", onGameMenuEnter)
    ZO_PreHookHandler(ZO_InteractWindow, "OnHide", onGameMenuExit)
    ZO_PreHookHandler(ZO_KeybindStripControl, "OnShow", onGameMenuEnter)
    ZO_PreHookHandler(ZO_KeybindStripControl, "OnHide", onGameMenuExit)
    ZO_PreHookHandler(ZO_MainMenuCategoryBar, "OnShow", onGameMenuEnter)
    ZO_PreHookHandler(ZO_MainMenuCategoryBar, "OnHide", onGameMenuExit)

    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_CHAMPION_PURCHASE_RESULT, onChampionPointsChanged)
    EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_CHAMPION_POINT_GAINED, onChampionPointsChanged)

    LeoAltholic.log("started.")
end

EVENT_MANAGER:RegisterForEvent(LeoAltholic.name, EVENT_ADD_ON_LOADED, onAddOnLoaded)