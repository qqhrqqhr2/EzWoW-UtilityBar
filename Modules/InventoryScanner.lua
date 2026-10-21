--===========================================================================
-- EzWoW - Utility Bar
-- Modules/InventoryScanner.lua : Bag, Trinket & Spellbook Scanner
--===========================================================================
local _, ns = ...
local InventoryScanner = ns.InventoryScanner or {}
ns.InventoryScanner = InventoryScanner
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local lowerText = ns.LowerText

local scanTooltip = CreateFrame("GameTooltip", "EzWoWUtilityBarScanTooltip", UIParent, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

-----------------------------------------------------------------------------
-- Tooltip & Item API Wrappers
-----------------------------------------------------------------------------
local bagTooltipCache = {}
local safeItemInfoCache = {}

-- An item whose data or tooltip is not ready yet (just logged in, new loot, secret text)
-- must not be judged now: it would be skipped and the result kept for the whole session.
local retryCount, retryQueued = {}, false
local MAX_RETRIES = 6

function ns.NoteIncompleteItem(itemID)
    if not itemID then return end
    ns.waitingItems[itemID] = true
    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    retryCount[itemID] = (retryCount[itemID] or 0) + 1
    if retryCount[itemID] > MAX_RETRIES or retryQueued then return end
    if C_Timer and type(C_Timer.After) == "function" then
        retryQueued = true
        C_Timer.After(1.5, function()
            retryQueued = false
            if ns.db and ns.RequestRefresh then ns:RequestRefresh() end
        end)
    end
end

function ns.ScanBagItemTooltip(bag, slot)
    local itemID = C_Container and C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)
    if itemID and bagTooltipCache[itemID] then
        local c = bagTooltipCache[itemID]
        return c[1], c[2], c[3], true
    end
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    scanTooltip:SetBagItem(bag, slot)

    local hasUse, complete = false, true
    local lines = {}
    for i = 1, scanTooltip:NumLines() do
        local fs = _G["EzWoWUtilityBarScanTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if type(text) == "string" and ns.IsSecret(text) then
            complete = false
        elseif type(text) == "string" then
            lines[#lines + 1] = text
            if text:find("Use:", 1, true) or text:find("Utiliser :", 1, true) or text:find("Utiliser:", 1, true)
                or text:find("사용 효과", 1, true) or text:find("사용:", 1, true)
                or text:find("使用:", 1, true) or text:find("使用：", 1, true)
                or text:find("Использование:", 1, true) or text:find("Benutzen:", 1, true) or text:find("Uso:", 1, true)
                or text:find("오른쪽 클릭으로 열기", 1, true) or text:find("우클릭으로 열기", 1, true)
                or text:find("Right Click to Open", 1, true) or text:find("Clic droit pour ouvrir", 1, true)
                or text:find("Zum Öffnen rechtsklicken", 1, true) or text:find("Clic derecho para abrir", 1, true)
                or text:find("чтобы открыть", 1, true) or text:find("右键点击打开", 1, true) or text:find("右鍵點擊打開", 1, true) then
                hasUse = true
            end
        end
    end
    local fullText, firstLine = table.concat(lines, "\n"), lines[1]
    if not firstLine or firstLine == "" or (RETRIEVING_ITEM_INFO and firstLine == RETRIEVING_ITEM_INFO) then
        complete, firstLine = false, nil
    end
    if itemID and not ns.GetSafeItemInfo(itemID) then complete = false end
    if itemID and complete then
        bagTooltipCache[itemID] = { hasUse, fullText, firstLine }
        retryCount[itemID] = nil
    elseif itemID then
        ns.NoteIncompleteItem(itemID)
    end
    return hasUse, fullText, firstLine, complete
end

function ns.EquippedSlotHasUseEffect(slot)
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    local ok = pcall(scanTooltip.SetInventoryItem, scanTooltip, "player", slot)
    if not ok then return false end

    for i = 2, scanTooltip:NumLines() do
        local fs = _G["EzWoWUtilityBarScanTooltipTextLeft" .. i]
        local raw = fs and fs:GetText()
        if type(raw) == "string" and not ns.IsSecret(raw) then
            local line = lowerText(raw):gsub("^%s+", "")
            if line:find("use:", 1, true) == 1 or line:find("utiliser :", 1, true) == 1 or line:find("utiliser:", 1, true) == 1
                or line:find("사용 효과:", 1, true) == 1 or line:find("사용:", 1, true) == 1
                or line:find("使用:", 1, true) == 1 or line:find("使用：", 1, true) == 1
                or line:find("использование:", 1, true) == 1 or line:find("benutzen:", 1, true) == 1
                or line:find("uso:", 1, true) == 1 then
                return true
            end
        end
    end
    return false
end

function ns.GetSafeItemInfo(itemID)
    if not itemID then return nil, nil, nil, nil end
    local cached = safeItemInfoCache[itemID]
    if cached then
        return cached[1], cached[2], cached[3], cached[4], cached[5], cached[6]
    end
    if type(GetItemInfo) == "function" then
        local ok, name, _, quality, level, minLevel, itemType, itemSubType = pcall(GetItemInfo, itemID)
        if ok and name then
            safeItemInfoCache[itemID] = { name, itemType, itemSubType, quality, minLevel, level }
            return name, itemType, itemSubType, quality, minLevel, level
        end
    end
    if C_Item and type(C_Item.GetItemInfo) == "function" then
        local ok, name, _, quality, level, minLevel, itemType, itemSubType = pcall(C_Item.GetItemInfo, itemID)
        if ok and name then
            safeItemInfoCache[itemID] = { name, itemType, itemSubType, quality, minLevel, level }
            return name, itemType, itemSubType, quality, minLevel, level
        end
    end
    return nil, nil, nil, nil
end

function ns.IsItemEquippable(itemID)
    local fn = (C_Item and C_Item.IsEquippableItem) or IsEquippableItem
    if type(fn) ~= "function" then return false end
    local ok, res = pcall(fn, itemID)
    return ok and (res == true or res == 1)
end

function ns.GetSafeItemCount(itemID)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if type(fn) ~= "function" then return nil end
    local ok, count = pcall(fn, itemID)
    if ok and type(count) == "number" and not ns.IsSecret(count) then
        return count
    end
    return nil
end

function ns.GetEntryKey(entry)
    if entry.type == "spell" then
        return "spell:" .. lowerText(entry.name)
    end
    return "item:" .. tostring(entry.id)
end

function ns.IsActionablePlayerSpell(spellInfo, spellID)
    if not spellID or not spellInfo then return false end
    local kind = spellInfo.itemType
    if kind and Enum and Enum.SpellBookItemType then
        local spellKind = Enum.SpellBookItemType.Spell
        if spellKind and kind ~= spellKind then return false end
    end
    if C_Spell and type(C_Spell.IsSpellPassive) == "function" then
        local ok, passive = pcall(C_Spell.IsSpellPassive, spellID)
        if ok and passive then return false end
    elseif type(IsPassiveSpell) == "function" then
        local ok, passive = pcall(IsPassiveSpell, spellID)
        if ok and passive then return false end
    end
    if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok and known == false then return false end
    elseif type(IsSpellKnown) == "function" then
        local ok, known = pcall(IsSpellKnown, spellID)
        if ok and known == false then return false end
    end
    return true
end

-----------------------------------------------------------------------------
-- Main Entry Collector
-----------------------------------------------------------------------------
local EQUIP_SLOTS = { 13, 14, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 15, 16, 17, 18 }

function ns:CollectEntries()
    local out = {}
    local db = self.db or _G.EzWoW_UtilityBarDB or {}
    local hidden = db.hidden or {}
    local categories = db.categories or {}
    local _, playerClass = UnitClass("player")
    local classReagents = ns.Data.CLASS_REAGENTS[playerClass] or {}

    -- 1. Bag Consumables, Reagents & Ammo
    if C_Container and C_Container.GetContainerNumSlots then
        local itemAt, skipItem = {}, {}
        for bag = 0, 4 do
            local numSlots = C_Container.GetContainerNumSlots(bag) or 0
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                local id = info and info.itemID
                if id and not skipItem[id] then
                    local stack = info.stackCount or 1
                    if itemAt[id] then
                        local existing = out[itemAt[id]]
                        existing.count = (existing.count or 0) + stack
                    else
                        local name, itemType, itemSubType, quality, minLevel, ilvl = ns.GetSafeItemInfo(id)
                        local reagThresh = classReagents[id]
                        local isAmmo = (playerClass == "HUNTER" or playerClass == "WARRIOR" or playerClass == "ROGUE")
                            and ns.IsAmmoItem(itemType, itemSubType)

                        if (reagThresh or isAmmo) and not hidden["item:" .. id] then
                            if not name or not itemType then
                                self.waitingItems[id] = true
                            end
                            local _, _, firstLine = ns.ScanBagItemTooltip(bag, slot)
                            name = name or firstLine
                            if categories.reagent then
                                out[#out + 1] = {
                                    type         = "item",
                                    id           = id,
                                    icon         = info.iconFileID,
                                    name         = name or tostring(id),
                                    category     = "reagent",
                                    count        = stack,
                                    quality      = quality or info.quality,
                                    minLevel     = tonumber(minLevel) or 0,
                                    ilvl         = tonumber(ilvl) or 0,
                                    lowThreshold = isAmmo and 200 or (reagThresh or 5),
                                }
                                itemAt[id] = #out
                            else
                                skipItem[id] = true
                            end
                        else
                            local hasUse, tipText, firstLine = ns.ScanBagItemTooltip(bag, slot)
                            if (hasUse or ns.Data.CAMPING_ITEMS[id] or ns.Data.WEAPON_BUFF_ITEMS[id])
                                and not ns.IsItemEquippable(id)
                                and not hidden["item:" .. id] then
                                if not name or not itemType then
                                    self.waitingItems[id] = true
                                end
                                name = name or firstLine
                                local cat = (ns.Data.CAMPING_ITEMS[id] and "camping")
                                    or (ns.Data.WEAPON_BUFF_ITEMS[id] and "weaponbuff")
                                    or ns.ClassifyItem(name, itemType, itemSubType, tipText)

                                if categories[cat] then
                                    local lowThresh = (cat == "potion" or cat == "elixir" or cat == "weaponbuff"
                                        or cat == "food" or cat == "bandage" or cat == "bomb" or cat == "reagent") and 5 or nil
                                    out[#out + 1] = {
                                        type         = "item",
                                        id           = id,
                                        icon         = info.iconFileID,
                                        name         = name or tostring(id),
                                        category     = cat,
                                        count        = stack,
                                        quality      = quality or info.quality,
                                        minLevel     = tonumber(minLevel) or 0,
                                        ilvl         = tonumber(ilvl) or 0,
                                        effect       = ns.DetectEffectKind(tipText),
                                        lowThreshold = lowThresh,
                                    }
                                    itemAt[id] = #out
                                else
                                    skipItem[id] = true
                                end
                            else
                                skipItem[id] = true
                            end
                        end
                    end
                end
            end
        end
    end

    -- 2. Equipped On-Use Gear & Trinkets
    if categories.trinket then
        for _, slot in ipairs(EQUIP_SLOTS) do
            local id = GetInventoryItemID("player", slot)
            if id and not hidden["item:" .. id] and ns.EquippedSlotHasUseEffect(slot) then
                local name, _, _, quality = ns.GetSafeItemInfo(id)
                local q = quality
                if type(GetInventoryItemQuality) == "function" then
                    local ok, val = pcall(GetInventoryItemQuality, "player", slot)
                    if ok and val then q = val end
                end
                out[#out + 1] = {
                    type          = "item",
                    id            = id,
                    inventorySlot = slot,
                    icon          = GetInventoryItemTexture("player", slot),
                    name          = name or "Item",
                    category      = "trinket",
                    quality       = q,
                }
            end
        end
    end

    -- 3. Learned Professions, Stances/Forms, Travel & Class Utility Spells
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
        local seenSpell = {}
        local highestByName = {}
        local numSkillLines = C_SpellBook.GetNumSpellBookSkillLines() or 0

        for tab = 1, numSkillLines do
            local line = C_SpellBook.GetSpellBookSkillLineInfo(tab)
            if line then
                for idx = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local si = C_SpellBook.GetSpellBookItemInfo(idx, Enum.SpellBookSpellBank.Player)
                    if si and si.spellID and not seenSpell[si.spellID] and ns.IsActionablePlayerSpell(si, si.spellID) then
                        local spellID = si.spellID
                        local name = C_Spell.GetSpellName(spellID)
                        local low = lowerText(name)
                        local cat = ns.IsFormSpell(name, playerClass) and "forms" or nil

                        if not cat then
                            for _, word in ipairs(ns.Data.CAMPING_SPELLS) do
                                if low == word or low:find(word, 1, true) == 1 then
                                    cat = "camping"
                                    break
                                end
                            end
                        end
                        if not cat then
                            for _, word in ipairs(ns.Data.TRAVEL_SPELLS) do
                                if low == word or low:find(word, 1, true) == 1 then
                                    cat = "travel"
                                    break
                                end
                            end
                        end
                        if not cat then
                            for _, word in ipairs(ns.Data.PROFESSION_KEYWORDS) do
                                if low:find(word, 1, true) then
                                    cat = "profession"
                                    break
                                end
                            end
                        end
                        if not cat and ns.IsClassUtilitySpell(name) then
                            cat = "classskill"
                        end

                        if cat and categories[cat] and not hidden["spell:" .. low] then
                            seenSpell[spellID] = true
                            local entry = {
                                type     = "spell",
                                id       = spellID,
                                icon     = C_Spell.GetSpellTexture(spellID),
                                name     = name,
                                category = cat,
                            }
                            if db.spellRanks == "all" then
                                out[#out + 1] = entry
                            else
                                local rankKey = cat .. ":" .. (name or ""):lower()
                                local priorIdx = highestByName[rankKey]
                                if priorIdx then
                                    out[priorIdx] = entry
                                else
                                    out[#out + 1] = entry
                                    highestByName[rankKey] = #out
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if db.bestOnly then
        out = ns.FilterBestConsumables(out)
    end

    local orderRank = {}
    for idx, catKey in ipairs(self.order) do
        orderRank[catKey] = idx
    end

    table.sort(out, function(a, b)
        if a.category ~= b.category then
            local ai = orderRank[a.category] or 99
            local bi = orderRank[b.category] or 99
            return ai < bi
        end
        return (a.name or "") < (b.name or "")
    end)

    return out
end
