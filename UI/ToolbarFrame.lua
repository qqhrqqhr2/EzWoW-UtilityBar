--===========================================================================
-- EzWoW - Utility Bar
-- UI/ToolbarFrame.lua : Main Utility Bar, Secure Buttons & Category Headers
--===========================================================================
local _, ns = ...
local ToolbarController = ns.ToolbarController or {}
ns.ToolbarController = ToolbarController
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local buttons = {}
local headers = {}
local draggingCategory = nil
local draggingTitle = false
local hoverUI = false
local hoverExitElapsed = 0

-----------------------------------------------------------------------------
-- Main Frame Creation
-----------------------------------------------------------------------------
local frame = CreateFrame("Frame", "EzWoWUtilityBarFrame", UIParent, "BackdropTemplate")
frame:SetSize(280, 62)
frame:SetClampedToScreen(true)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
frame:SetMovable(true)
frame:EnableMouse(false)
ns.UIKit:ApplyBackdrop(frame, 1, 1)
frame:SetBackdropBorderColor(0.204, 0.298, 0.357, 0.90)
frame:SetBackdropColor(0.071, 0.094, 0.122, 0.93)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", 12, -8)
title:SetTextColor(0.788, 0.643, 0.937)
title:SetText("EzWoW - Utility Bar")
title:SetDrawLayer("OVERLAY", 2)

ns.MainFrame = frame
ns.buttons = buttons
ns.headers = headers

-----------------------------------------------------------------------------
-- Cooldown, Usability & Active Stance Helpers
-----------------------------------------------------------------------------
function ToolbarController.GetEntryBorderColor(entry)
    local q = entry.type == "item" and tonumber(entry.quality)
    if q and q >= 2 then
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
        if c and c.r then
            return c.r * 0.85, c.g * 0.85, c.b * 0.85, 0.95
        end
        local fallback = {
            [2] = { 0.12, 0.85, 0.00 },
            [3] = { 0.00, 0.44, 0.87 },
            [4] = { 0.64, 0.21, 0.93 },
            [5] = { 1.00, 0.50, 0.00 },
        }
        local f = fallback[q]
        if f then return f[1], f[2], f[3], 0.95 end
    end
    return 0.17, 0.22, 0.26, 0.90
end

function ToolbarController.GetCooldownInfo(entry)
    local start, duration, enabled
    if entry.type == "item" then
        if C_Item and type(C_Item.GetItemCooldown) == "function" then
            local ok, a, b, c = pcall(C_Item.GetItemCooldown, entry.id)
            if ok then
                if type(a) == "table" then
                    start, duration, enabled = a.startTime, a.duration, a.isEnabled
                else
                    start, duration, enabled = a, b, c
                end
            end
        end
        if start == nil and type(GetItemCooldown) == "function" then
            local ok, a, b, c = pcall(GetItemCooldown, entry.id)
            if ok then start, duration, enabled = a, b, c end
        end
    else
        if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
            local ok, a, b, c = pcall(C_Spell.GetSpellCooldown, entry.id)
            if ok then
                if type(a) == "table" then
                    start, duration, enabled = a.startTime, a.duration, a.isEnabled
                else
                    start, duration, enabled = a, b, c
                end
            end
        end
        if start == nil and type(GetSpellCooldown) == "function" then
            local ok, a, b, c = pcall(GetSpellCooldown, entry.id)
            if ok then start, duration, enabled = a, b, c end
        end
    end

    if ns.IsSecret(start) or ns.IsSecret(duration) then
        return start, duration, enabled, true
    end
    return tonumber(start) or 0, tonumber(duration) or 0, enabled, false
end

function ToolbarController.IsEntryUsable(entry)
    if entry.type == "spell" then
        if C_Spell and type(C_Spell.IsSpellUsable) == "function" then
            local ok, a, b = pcall(C_Spell.IsSpellUsable, entry.id)
            if ok then
                local u = ns.ToBooleanFlag(a)
                if u == nil then return true, false end
                return u, ns.ToBooleanFlag(b) == true
            end
        end
        if type(IsUsableSpell) == "function" then
            local ok, a, b = pcall(IsUsableSpell, entry.id)
            if ok then
                local u = ns.ToBooleanFlag(a)
                if u == nil then return true, false end
                return u, ns.ToBooleanFlag(b) == true
            end
        end
    else
        if C_Item and type(C_Item.IsUsableItem) == "function" then
            local ok, a, b = pcall(C_Item.IsUsableItem, entry.id)
            if ok then
                local u = ns.ToBooleanFlag(a)
                if u == nil then return true, false end
                return u, ns.ToBooleanFlag(b) == true
            end
        end
        if type(IsUsableItem) == "function" then
            local ok, a, b = pcall(IsUsableItem, entry.id)
            if ok then
                local u = ns.ToBooleanFlag(a)
                if u == nil then return true, false end
                return u, ns.ToBooleanFlag(b) == true
            end
        end
    end
    return true, false
end

function ToolbarController.IsActiveFormSpell(entry)
    if entry.type ~= "spell" or entry.category ~= "forms" then return false end
    if type(GetShapeshiftForm) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then return false end
    local ok, idx = pcall(GetShapeshiftForm)
    if not ok or not idx or ns.IsSecret(idx) or idx <= 0 then return false end
    local success, texture, _, _, spellID = pcall(GetShapeshiftFormInfo, idx)
    if not success then return false end
    if spellID and not ns.IsSecret(spellID) and tonumber(spellID) == tonumber(entry.id) then
        return true
    end
    if texture and entry.icon and not ns.IsSecret(texture) and tostring(texture) == tostring(entry.icon) then
        return true
    end
    return false
end

-----------------------------------------------------------------------------
-- Secure Action Button Pool
-----------------------------------------------------------------------------
function ToolbarController.AcquireActionButton(index)
    if buttons[index] then return buttons[index] end

    local b = CreateFrame("Button", "EzWoWUtilityBarAction" .. index, frame, "SecureActionButtonTemplate")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetAllPoints()
    b.border:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.border:SetVertexColor(0.17, 0.22, 0.26, 0.90)
    b.border:SetDrawLayer("BACKGROUND", 0)

    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)

    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)
    b.cooldown:SetFrameLevel(b:GetFrameLevel() + 2)
    if b.cooldown.SetDrawEdge then b.cooldown:SetDrawEdge(false) end
    if b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(false) end

    b.shade = b:CreateTexture(nil, "OVERLAY")
    b.shade:SetAllPoints(b.icon)
    b.shade:SetColorTexture(0, 0, 0, 0.52)
    b.shade:Hide()

    b.activeEdges = {}
    for edge = 1, 4 do
        local t = b:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetVertexColor(0.95, 0.76, 0.33, 1)
        if edge == 1 then
            t:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
            t:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
            t:SetHeight(2)
        elseif edge == 2 then
            t:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
            t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
            t:SetHeight(2)
        elseif edge == 3 then
            t:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
            t:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
            t:SetWidth(2)
        else
            t:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
            t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
            t:SetWidth(2)
        end
        t:Hide()
        b.activeEdges[edge] = t
    end

    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b.count:SetDrawLayer("OVERLAY", 6)

    local glow = b:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(b.icon)
    glow:SetColorTexture(1, 0.86, 0.52, 0.16)

    local pushed = b:CreateTexture(nil, "OVERLAY")
    pushed:SetAllPoints(b.icon)
    pushed:SetColorTexture(0, 0, 0, 0.30)
    if b.SetPushedTexture then b:SetPushedTexture(pushed) else pushed:Hide() end

    local hideBtn = CreateFrame("Button", nil, b)
    hideBtn:SetSize(14, 14)
    hideBtn:SetPoint("TOPRIGHT", b, "TOPRIGHT", 2, 2)
    hideBtn:SetFrameLevel(b:GetFrameLevel() + 6)

    local hbg = hideBtn:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(0.10, 0.06, 0.05, 0.92)

    local hedge = hideBtn:CreateTexture(nil, "BORDER")
    hedge:SetPoint("TOPLEFT", -1, 1)
    hedge:SetPoint("BOTTOMRIGHT", 1, -1)
    hedge:SetColorTexture(0.72, 0.30, 0.24, 0.95)
    hedge:SetDrawLayer("BACKGROUND", -1)

    local hx = hideBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hx:SetPoint("CENTER", 0, 1)
    hx:SetText("x")
    hx:SetTextColor(1, 0.78, 0.70)

    hideBtn:SetScript("OnClick", function(self)
        local owner = self:GetParent()
        if not ns.db or not owner.entry then return end
        ns.db.hidden[ns.GetEntryKey(owner.entry)] = true
        self:Hide()
        GameTooltip:Hide()
        ns:RefreshToolbar()
        if ns.ConfigFrame and ns.ConfigFrame:IsShown() and ns.ConfigFrame.updateLabels then
            ns.ConfigFrame.updateLabels()
        end
    end)
    hideBtn:SetScript("OnEnter", function(self)
        hbg:SetColorTexture(0.42, 0.12, 0.09, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns:L("hideIcon"), 1, 0.82, 0.60)
        GameTooltip:Show()
    end)
    hideBtn:SetScript("OnLeave", function(self)
        hbg:SetColorTexture(0.10, 0.06, 0.05, 0.92)
        GameTooltip:Hide()
        if not self:GetParent():IsMouseOver() then
            self:Hide()
        end
    end)
    hideBtn:Hide()
    b.hideBtn = hideBtn

    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetScript("OnEnter", function(self)
        if not self.entry then return end
        if ns.hoverUIActive and ns.db and not ns.db.locked then
            self.hideBtn:Show()
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.entry.type == "item" then
            if self.entry.inventorySlot and GameTooltip.SetInventoryItem then
                GameTooltip:SetInventoryItem("player", self.entry.inventorySlot)
            elseif GameTooltip.SetItemByID then
                GameTooltip:SetItemByID(self.entry.id)
            end
        elseif GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(self.entry.id)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if not self.hideBtn:IsMouseOver() then
            self.hideBtn:Hide()
        end
    end)

    buttons[index] = b
    return b
end

function ToolbarController.BindEntryToButton(b, entry, size)
    b.entry = entry
    b:ClearAllPoints()
    b:SetSize(size, size)
    b.icon:SetTexture(entry.icon)
    b.icon:SetVertexColor(1, 1, 1, 1)
    b:SetAlpha(1)

    local db = ns.db or _G.EzWoW_UtilityBarDB
    local isLow = db and db.lowStockWarn and entry.lowThreshold and entry.count and entry.count > 0 and entry.count <= entry.lowThreshold
    if isLow then
        b.border:SetVertexColor(0.90, 0.26, 0.22, 0.98)
        b.count:SetTextColor(1, 0.32, 0.32)
        b.count:SetText(tostring(entry.count))
    else
        b.border:SetVertexColor(ToolbarController.GetEntryBorderColor(entry))
        b.count:SetTextColor(1, 1, 1)
        b.count:SetText(entry.count and (entry.count > 1 or entry.category == "reagent") and entry.count or "")
    end

    b:SetAttribute("type", entry.type)
    if entry.type == "item" then
        b:SetAttribute("item", entry.inventorySlot and tostring(entry.inventorySlot) or ("item:" .. tostring(entry.id)))
        b:SetAttribute("spell", nil)
    else
        b:SetAttribute("item", nil)
        b:SetAttribute("spell", entry.id)
    end

    b.hideBtn:Hide()
    b.lastStart = nil
    b.lastDuration = nil
    b.lastCount = nil
    b:Show()
end

-----------------------------------------------------------------------------
-- Category Header Bar & Drag Badge
-----------------------------------------------------------------------------
local dragBadge = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
dragBadge:SetSize(140, 22)
dragBadge:SetFrameStrata("TOOLTIP")
dragBadge:Hide()
ns.UIKit:ApplyBackdrop(dragBadge)
dragBadge:SetBackdropColor(0.14, 0.11, 0.20, 0.96)
dragBadge:SetBackdropBorderColor(0.788, 0.643, 0.937, 1)
dragBadge.text = dragBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dragBadge.text:SetPoint("CENTER", 0, 0)
dragBadge.text:SetTextColor(0.929, 0.957, 0.969)

function ToolbarController.AcquireCategoryHeader(groupKey)
    if headers[groupKey] then return headers[groupKey] end

    local h = CreateFrame("Button", nil, frame)
    h:SetHeight(20)
    h:EnableMouse(ns.hoverUIActive or (ns.db and not ns.db.locked))
    h:RegisterForDrag("LeftButton")

    h.bg = h:CreateTexture(nil, "BACKGROUND")
    h.bg:SetAllPoints()
    h.bg:SetColorTexture(0.114, 0.157, 0.192, 0.92)

    h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.label:SetPoint("LEFT", 12, 0)
    h.label:SetJustifyH("LEFT")
    h.label:SetTextColor(0.929, 0.957, 0.969)

    h.grip = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.grip:SetPoint("RIGHT", -8, 0)
    h.grip:SetText("↕")
    h.grip:SetTextColor(0.788, 0.643, 0.937, 0.85)

    h.accent = h:CreateTexture(nil, "ARTWORK")
    h.accent:SetColorTexture(0.788, 0.643, 0.937, 0.95)
    h.accent:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
    h.accent:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 0)
    h.accent:SetWidth(2)

    h:SetScript("OnClick", function(self)
        if self.justDragged then
            self.justDragged = nil
            return
        end
        if not ns.hoverUIActive and (not ns.db or ns.db.locked) then return end
        ns.db.collapsed[groupKey] = not ns.db.collapsed[groupKey]
        ns:RefreshToolbar()
    end)

    h:SetScript("OnDragStart", function(self)
        if not ns.db or ns.db.locked or InCombatLockdown() then return end
        self.justDragged = true
        draggingCategory = groupKey
        self.bg:SetColorTexture(0.24, 0.19, 0.32, 0.98)
        dragBadge.text:SetText("↕  " .. ns:GetGroupLabel(groupKey))
        dragBadge:SetWidth(math.max(110, dragBadge.text:GetStringWidth() + 24))
        dragBadge:Show()
    end)

    h:SetScript("OnDragStop", function(self)
        if draggingCategory ~= groupKey then return end
        draggingCategory = nil
        dragBadge:Hide()
        self.bg:SetColorTexture(0.114, 0.157, 0.192, 0.92)
        ns:RefreshToolbar()
        if ns.ConfigFrame and ns.ConfigFrame:IsShown() and ns.ConfigFrame.updateLabels then
            ns.ConfigFrame.updateLabels()
        end
    end)

    h:SetScript("OnEnter", function(self)
        local active = (draggingCategory == groupKey)
        self.bg:SetColorTexture(active and 0.24 or 0.16, active and 0.19 or 0.22, active and 0.32 or 0.27, 0.98)
    end)

    h:SetScript("OnLeave", function(self)
        local active = (draggingCategory == groupKey)
        self.bg:SetColorTexture(active and 0.24 or 0.114, active and 0.19 or 0.157, active and 0.32 or 0.192, active and 0.98 or 0.92)
    end)

    headers[groupKey] = h
    return h
end

-----------------------------------------------------------------------------
-- Visual State & Layout Refresh
-----------------------------------------------------------------------------
function ns:UpdateVisuals()
    local db = self.db or _G.EzWoW_UtilityBarDB
    if not db then return end
    local now = GetTime()

    for _, b in ipairs(buttons) do
        if b:IsShown() and b.entry then
            local empty = false
            if b.entry.type == "item" and not b.entry.inventorySlot then
                local n = ns.GetSafeItemCount(b.entry.id)
                if n then
                    local low = db.lowStockWarn and b.entry.lowThreshold and n > 0 and n <= b.entry.lowThreshold
                    if n ~= b.lastCount or low ~= b.lastLow then
                        b.lastCount = n
                        b.lastLow = low
                        if low then
                            b.border:SetVertexColor(0.90, 0.26, 0.22, 0.98)
                            b.count:SetTextColor(1, 0.32, 0.32)
                            b.count:SetText(tostring(n))
                        else
                            b.border:SetVertexColor(ToolbarController.GetEntryBorderColor(b.entry))
                            b.count:SetTextColor(1, 1, 1)
                            b.count:SetText((n > 1 or (n == 1 and b.entry.category == "reagent")) and n or "")
                        end
                    end
                    empty = (n == 0)
                end
            end

            local start, duration, _, secret = ToolbarController.GetCooldownInfo(b.entry)
            local onCD = false
            if secret then
                if b.cooldown.SetCooldown then
                    pcall(b.cooldown.SetCooldown, b.cooldown, start, duration)
                end
                b.cooldown:Show()
                b.lastStart, b.lastDuration = nil, nil
            else
                onCD = start > 0 and duration > 0 and (start + duration) > (now + 0.05)
                if onCD then
                    if b.lastStart ~= start or b.lastDuration ~= duration then
                        if CooldownFrame_Set then
                            CooldownFrame_Set(b.cooldown, start, duration, 1)
                        elseif b.cooldown.SetCooldown then
                            b.cooldown:SetCooldown(start, duration)
                        end
                        b.lastStart, b.lastDuration = start, duration
                    end
                    b.cooldown:Show()
                else
                    b.cooldown:Hide()
                    b.lastStart, b.lastDuration = nil, nil
                end
            end

            local usable, noResource = ToolbarController.IsEntryUsable(b.entry)
            local active = ToolbarController.IsActiveFormSpell(b.entry)
            local blocked = (not usable and not onCD and not active) or empty

            b.shade:SetAlpha(noResource and 0.75 or 0.52)
            b.shade:SetShown(blocked)
            b.icon:SetDesaturated(blocked)
            for _, edge in ipairs(b.activeEdges) do
                edge:SetShown(active)
            end
            b.icon:SetVertexColor(1, 1, 1, 1)
        end
    end
end

-----------------------------------------------------------------------------
-- Top-Right Toolbar Controls, Resize Grip & Hover Reveal
-----------------------------------------------------------------------------
function ToolbarController.SaveFramePosition()
    if not ns.db then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ns.db.position = { point or "CENTER", relativePoint or "CENTER", x or 0, y or 0 }
end

function ToolbarController.CreateToolbarControl(name, iconName, xOffset, tipKey, onClick)
    local b = CreateFrame("Button", name, frame, "BackdropTemplate")
    b:SetSize(23, 23)
    b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", xOffset, -3)
    ns.UIKit:ApplyBackdrop(b)
    b:SetBackdropColor(0.114, 0.157, 0.192, 0.92)
    b:SetBackdropBorderColor(0.204, 0.298, 0.357, 0.95)

    local icon = b:CreateTexture(nil, "ARTWORK")
    b.icon = icon
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture(ns.MEDIA_PATH .. iconName .. ".tga")

    b:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.20, 0.16, 0.27, 0.98)
        self:SetBackdropBorderColor(0.788, 0.643, 0.937, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("EzWoW - Utility Bar", 0.788, 0.643, 0.937)
        GameTooltip:AddLine(ns:L(tipKey), 0.929, 0.957, 0.969, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.114, 0.157, 0.192, 0.92)
        self:SetBackdropBorderColor(0.204, 0.298, 0.357, 0.95)
        GameTooltip:Hide()
    end)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

local foldBtn = ToolbarController.CreateToolbarControl("EzWoWUtilityBarFoldButton", "fold", -57, "foldTip", function()
    if not ns.db then return end
    local allCollapsed = true
    for _, k in ipairs(ns.order) do
        if not ns.db.collapsed[k] then
            allCollapsed = false
            break
        end
    end
    for _, k in ipairs(ns.order) do
        ns.db.collapsed[k] = not allCollapsed
    end
    ns:RefreshToolbar()
end)

local gearBtn = ToolbarController.CreateToolbarControl("EzWoWUtilityBarSettingsButton", "gear", -6, "gearTip", function()
    ns:ToggleOptions()
end)

local lockBtn = ToolbarController.CreateToolbarControl("EzWoWUtilityBarLockButton", "unlock", -32, "lockTip", function()
    if not ns.db or InCombatLockdown() then return end
    ns.db.locked = not ns.db.locked
    ns:RefreshToolbar()
end)

local resizeHandle = CreateFrame("Button", "EzWoWUtilityBarResizeHandle", frame)
resizeHandle:SetSize(19, 19)
resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
resizeHandle:SetFrameLevel(frame:GetFrameLevel() + 10)
local resizeIcon = resizeHandle:CreateTexture(nil, "ARTWORK")
resizeIcon:SetAllPoints()
resizeIcon:SetTexture(ns.MEDIA_PATH .. "resize.tga")

frame:SetResizable(true)
if frame.SetResizeBounds then
    frame:SetResizeBounds(190, 55, 900, 900)
elseif frame.SetMinResize then
    frame:SetMinResize(190, 55)
    frame:SetMaxResize(900, 900)
end

resizeHandle:RegisterForDrag("LeftButton")
resizeHandle:SetScript("OnDragStart", function()
    if ns.db and not ns.db.locked and not InCombatLockdown() then
        frame:StartSizing("BOTTOMRIGHT")
    end
end)
resizeHandle:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    if not ns.db then return end
    ns.db.manualWidth = math.floor(frame:GetWidth() + 0.5)
    ns.db.manualHeight = math.floor(frame:GetHeight() + 0.5)
    ns.db.columns = math.max(1, math.floor((ns.db.manualWidth - 16) / ((ns.db.size or 36) + 4)))
    ToolbarController.SaveFramePosition()
    ns:RefreshToolbar()
end)

local titleHover = CreateFrame("Frame", nil, frame, "BackdropTemplate")
titleHover:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -3)
titleHover:SetSize(128, 23)
titleHover:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
titleHover:SetBackdropBorderColor(0.788, 0.643, 0.937, 0)
titleHover:EnableMouse(true)
titleHover:RegisterForDrag("LeftButton")

titleHover:SetScript("OnDragStart", function()
    if not ns.db or InCombatLockdown() or not IsControlKeyDown() then return end
    draggingTitle = true
    frame:StartMoving()
end)
titleHover:SetScript("OnDragStop", function()
    if not draggingTitle then return end
    draggingTitle = false
    frame:StopMovingOrSizing()
    ToolbarController.SaveFramePosition()
end)

function ns:ShowHoverUI(show)
    hoverUI = show
    self.hoverUIActive = show
    local canClickHeader = show or (self.db and not self.db.locked)
    for _, h in pairs(headers) do
        h:EnableMouse(canClickHeader)
    end
    hoverExitElapsed = 0
    if not self.db then return end
    foldBtn:SetShown(show)
    gearBtn:SetShown(show)
    lockBtn:SetShown(show)
    resizeHandle:SetShown(show and not self.db.locked)
    titleHover:SetBackdropBorderColor(0.788, 0.643, 0.937, show and 0.9 or 0)
    frame:SetBackdropColor(0.071, 0.094, 0.122, show and 0.88 or (self.db.locked and 0 or 0.93))
    frame:SetBackdropBorderColor(0.788, 0.643, 0.937, show and 0.9 or (self.db.locked and 0 or 0.90))
    if not show then
        for _, b in ipairs(buttons) do
            if b.hideBtn then b.hideBtn:Hide() end
        end
    end
end

titleHover:SetScript("OnEnter", function(self)
    ns:ShowHoverUI(true)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("EzWoW - Utility Bar", 0.788, 0.643, 0.937)
    GameTooltip:AddLine(ns:L("helpMove"), 0.929, 0.957, 0.969, true)
    GameTooltip:AddLine(ns:L("helpReorder"), 0.655, 0.725, 0.773, true)
    GameTooltip:AddLine(ns:L("hideHint"), 0.655, 0.725, 0.773, true)
    GameTooltip:Show()
end)
titleHover:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

function ns:RefreshToolbar()
    local db = self.db or _G.EzWoW_UtilityBarDB
    if not db then return end
    if InCombatLockdown() then
        self.pendingRefresh = true
        return
    end
    self.pendingRefresh = false

    local entries = self:CollectEntries()
    local size = db.size or 36
    local cols = math.max(1, db.columns or 8)

    local grouped = {}
    for _, entry in ipairs(entries) do
        grouped[entry.category] = grouped[entry.category] or {}
        table.insert(grouped[entry.category], entry)
    end

    local width = math.max(190, db.manualWidth or (16 + cols * (size + 4)))
    cols = math.max(1, math.floor((width - 16) / (size + 4)))

    local y = 32
    local index = 0

    if db.unified then
        for _, k in ipairs(self.order) do
            headers[k] = ToolbarController.AcquireCategoryHeader(k)
            headers[k]:Hide()
        end
        local shown = {}
        for _, entry in ipairs(entries) do
            if db.categories[entry.category] then
                shown[#shown + 1] = entry
            end
        end
        for n, entry in ipairs(shown) do
            index = index + 1
            local b = ToolbarController.AcquireActionButton(index)
            ToolbarController.BindEntryToButton(b, entry, size)
            b:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + ((n - 1) % cols) * (size + 4), -y - math.floor((n - 1) / cols) * (size + 4))
        end
        y = y + math.ceil(#shown / cols) * (size + 4) + 5
    else
        for _, k in ipairs(self.order) do
            local group = grouped[k]
            local h = ToolbarController.AcquireCategoryHeader(k)
            if db.categories[k] and group and #group > 0 then
                local collapsed = db.collapsed[k]
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -y)
                h:SetWidth(width - 16)
                h.label:SetText((collapsed and ">  " or "v  ") .. self:GetGroupLabel(k) .. "  |  " .. #group)
                ns.UIKit:FitFontString(h.label, width - 50, 1)  -- keep clear of the drag grip
                if h.grip then h.grip:SetShown(not db.locked) end
                if draggingCategory == k then
                    h.bg:SetColorTexture(0.24, 0.19, 0.32, 0.98)
                else
                    h.bg:SetColorTexture(0.114, 0.157, 0.192, 0.92)
                end
                h:Show()
                y = y + 25
                if not collapsed then
                    for n, entry in ipairs(group) do
                        index = index + 1
                        local b = ToolbarController.AcquireActionButton(index)
                        ToolbarController.BindEntryToButton(b, entry, size)
                        b:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + ((n - 1) % cols) * (size + 4), -y - math.floor((n - 1) / cols) * (size + 4))
                    end
                    y = y + math.ceil(#group / cols) * (size + 4) + 5
                end
            else
                h:Hide()
            end
        end
    end

    for i = index + 1, #buttons do
        local b = buttons[i]
        b:Hide()
        b:SetAttribute("type", nil)
        b.entry = nil
        b.cooldown:Hide()
        b.shade:Hide()
        b.hideBtn:Hide()
        for _, edge in ipairs(b.activeEdges) do edge:Hide() end
    end

    local left, top, bottom = frame:GetLeft(), frame:GetTop(), frame:GetBottom()
    if not draggingTitle and left and top and bottom then
        frame:ClearAllPoints()
        if db.growUp then
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
            db.position = { "BOTTOMLEFT", "BOTTOMLEFT", left, bottom }
        else
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            db.position = { "TOPLEFT", "BOTTOMLEFT", left, top }
        end
    end

    frame:SetSize(width, math.max(48, y + 10, db.manualHeight or 0))
    frame:SetBackdropColor(0.071, 0.094, 0.122, db.locked and 0 or 0.93)
    frame:SetBackdropBorderColor(0.204, 0.298, 0.357, db.locked and 0 or 0.90)

    for _, h in pairs(headers) do
        if h.bg then h.bg:SetAlpha(db.locked and 0 or 1) end
        if h.accent then h.accent:SetAlpha(db.locked and 0 or 1) end
        if h.grip then h.grip:SetShown(not db.locked) end
    end

    if db.visible then frame:Show() else frame:Hide() end
    if lockBtn and lockBtn.icon then
        lockBtn.icon:SetTexture(ns.MEDIA_PATH .. (db.locked and "lock" or "unlock") .. ".tga")
    end
    self:ShowHoverUI(hoverUI)
    self:UpdateVisuals()
end

-----------------------------------------------------------------------------
-- OnUpdate Drivers & Events
-----------------------------------------------------------------------------
local visualTimer = 0

frame:SetScript("OnUpdate", function(_, elapsed)
    local db = ns.db or _G.EzWoW_UtilityBarDB
    if not db then return end

    -- 1. Category Drag Reordering
    if draggingCategory then
        if InCombatLockdown() or not IsMouseButtonDown("LeftButton") then
            local prev = draggingCategory
            draggingCategory = nil
            dragBadge:Hide()
            if headers[prev] then headers[prev].bg:SetColorTexture(0.114, 0.157, 0.192, 0.92) end
            ns:RefreshToolbar()
            if ns.ConfigFrame and ns.ConfigFrame:IsShown() and ns.ConfigFrame.updateLabels then
                ns.ConfigFrame.updateLabels()
            end
            return
        end
        local cx, cy = GetCursorPosition()
        local uScale = (dragBadge and dragBadge:GetEffectiveScale()) or UIParent:GetEffectiveScale() or 1
        dragBadge:ClearAllPoints()
        dragBadge:SetPoint("LEFT", UIParent, "BOTTOMLEFT", cx / uScale + 14, cy / uScale)
        local curY = cy / frame:GetEffectiveScale()

        local fromIdx
        for i, k in ipairs(ns.order) do
            if k == draggingCategory then fromIdx = i; break end
        end
        if fromIdx then
            for i, otherK in ipairs(ns.order) do
                local otherH = headers[otherK]
                if otherK ~= draggingCategory and otherH and otherH:IsShown() then
                    local _, otherCY = otherH:GetCenter()
                    if otherCY and ((i < fromIdx and curY > otherCY) or (i > fromIdx and curY < otherCY)) then
                        table.remove(ns.order, fromIdx)
                        table.insert(ns.order, i, draggingCategory)
                        db.order = ns.order
                        ns:RefreshToolbar()
                        if ns.ConfigFrame and ns.ConfigFrame:IsShown() and ns.ConfigFrame.updateLabels then
                            ns.ConfigFrame.updateLabels()
                        end
                        break
                    end
                end
            end
        end
    end

    -- 2. Hover Reveal Auto-Exit
    if hoverUI then
        if draggingTitle or draggingCategory or frame:IsMouseOver() or (resizeHandle.IsMouseOver and resizeHandle:IsMouseOver()) then
            hoverExitElapsed = 0
        else
            hoverExitElapsed = hoverExitElapsed + elapsed
            if hoverExitElapsed >= 0.15 then
                ns:ShowHoverUI(false)
            end
        end
    end

    -- 3. Smooth Opacity & Mouseover Fade
    local targetAlpha = db.opacity or 1
    if db.fade and not (hoverUI or draggingTitle or frame:IsMouseOver() or (ns.ConfigFrame and ns.ConfigFrame:IsShown())) then
        targetAlpha = 0
    end
    local curAlpha = frame:GetAlpha()
    if math.abs(curAlpha - targetAlpha) > 0.005 then
        local step = elapsed * 5
        if curAlpha < targetAlpha then
            curAlpha = math.min(targetAlpha, curAlpha + step)
        else
            curAlpha = math.max(targetAlpha, curAlpha - step)
        end
        frame:SetAlpha(curAlpha)
    end

    -- 4. Periodic Visual Cooldown/Count Poll
    visualTimer = visualTimer + elapsed
    if visualTimer >= 0.25 then
        visualTimer = 0
        ns:UpdateVisuals()
    end
end)

local refreshQueued = false
function ns:RequestRefresh()
    if refreshQueued then return end
    if C_Timer and type(C_Timer.After) == "function" then
        refreshQueued = true
        C_Timer.After(0.2, function()
            refreshQueued = false
            ns:RefreshToolbar()
        end)
    else
        ns:RefreshToolbar()
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
frame:RegisterEvent("SPELL_UPDATE_USABLE")
frame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        ns:InitDB()
        if ns.db.position then
            frame:ClearAllPoints()
            frame:SetPoint(ns.db.position[1], UIParent, ns.db.position[2], ns.db.position[3], ns.db.position[4])
        end
        if ns.RegisterBlizzardOptions then
            ns:RegisterBlizzardOptions()
        end
        ns:RefreshToolbar()
        ns.Print(ns:L("loaded"))
    elseif event == "PLAYER_REGEN_ENABLED" then
        if ns.pendingRefresh then
            ns:RefreshToolbar()
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if arg1 and ns.waitingItems[arg1] then
            ns.waitingItems[arg1] = nil
            if ns.db then ns:RequestRefresh() end
        end
    elseif event == "SPELL_UPDATE_COOLDOWN"
        or event == "SPELL_UPDATE_USABLE"
        or event == "ACTIONBAR_UPDATE_COOLDOWN"
        or event == "UNIT_POWER_UPDATE"
        or event == "PLAYER_TARGET_CHANGED"
        or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "BAG_UPDATE_COOLDOWN" then
        if ns.db then ns:UpdateVisuals() end
    elseif ns.db then
        ns:RequestRefresh()
    end
end)
