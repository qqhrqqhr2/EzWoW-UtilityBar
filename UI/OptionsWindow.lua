--===========================================================================
-- EzWoW - Utility Bar
-- UI/OptionsWindow.lua : EzWoW Style Settings Window, Blizzard Launcher & Slash
--===========================================================================
local _, ns = ...
local SettingsDialog = ns.SettingsDialog or {}
ns.SettingsDialog = SettingsDialog
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local configFrame = nil
local optionsPanel = nil
local copyBox = nil

-----------------------------------------------------------------------------
-- Donate Copy Modal
-----------------------------------------------------------------------------
function SettingsDialog.ShowDonatePopup()
    if not copyBox then
        copyBox = CreateFrame("Frame", "EzWoWUtilityBarDonate", UIParent, "BackdropTemplate")
        copyBox:SetSize(390, 116)
        copyBox:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        ns.UIKit:ElevateModal(copyBox, 260)
        ns.UIKit:ApplyBackdrop(copyBox)
        copyBox:SetBackdropColor(0.071, 0.094, 0.122, 0.98)
        copyBox:SetBackdropBorderColor(0.788, 0.643, 0.937, 1)

        local label = copyBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOP", 0, -14)
        label:SetText(ns:L("copy"))
        label:SetTextColor(0.788, 0.643, 0.937)
        copyBox.label = label

        local edit = CreateFrame("EditBox", nil, copyBox, "BackdropTemplate")
        edit:SetSize(346, 27)
        edit:SetFrameLevel(copyBox:GetFrameLevel() + 5)
        edit:SetPoint("TOP", 0, -43)
        ns.UIKit:ApplyBackdrop(edit)
        edit:SetBackdropColor(0.047, 0.067, 0.086, 0.96)
        edit:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
        edit:SetFontObject(ChatFontNormal)
        edit:SetTextColor(0.929, 0.957, 0.969)
        edit:SetTextInsets(8, 8, 0, 0)
        edit:SetAutoFocus(false)
        edit:SetText(ns.DONATE_URL)
        edit:SetScript("OnEditFocusGained", function(self)
            self:SetBackdropBorderColor(0.788, 0.643, 0.937, 1)
            self:HighlightText()
        end)
        edit:SetScript("OnEditFocusLost", function(self)
            self:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
        end)
        edit:SetScript("OnEscapePressed", function() copyBox:Hide() end)
        edit:SetScript("OnEnterPressed", function() copyBox:Hide() end)
        copyBox.edit = edit

        local closeBtn = CreateFrame("Button", nil, copyBox, "BackdropTemplate")
        closeBtn:SetSize(22, 22)
        closeBtn:SetFrameLevel(copyBox:GetFrameLevel() + 5)
        closeBtn:SetPoint("TOPRIGHT", -6, -6)
        ns.UIKit:ApplyBackdrop(closeBtn)
        closeBtn:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
        closeBtn:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
        local cTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        cTxt:SetPoint("CENTER")
        cTxt:SetText("X")
        cTxt:SetTextColor(0.929, 0.957, 0.969)
        closeBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.18, 0.24, 0.30, 1)
            self:SetBackdropBorderColor(0.788, 0.643, 0.937, 1)
        end)
        closeBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
            self:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
        end)
        closeBtn:SetScript("OnClick", function() copyBox:Hide() end)
    end
    if copyBox.label then copyBox.label:SetText(ns:L("copy")) end
    ns.UIKit:ElevateModal(copyBox, 260)
    copyBox:Show()
    if copyBox.Raise then copyBox:Raise() end
    copyBox.edit:SetFocus()
    copyBox.edit:HighlightText()
end

-----------------------------------------------------------------------------
-- EzWoW Style Configuration Window (EzWoWUtilityBarConfig)
-----------------------------------------------------------------------------
function ns:ToggleOptions()
    if configFrame then
        configFrame:SetShown(not configFrame:IsShown())
        if configFrame:IsShown() then configFrame:Raise() end
        return
    end

    local db = self.db or _G.EzWoW_UtilityBarDB
    configFrame = CreateFrame("Frame", "EzWoWUtilityBarConfig", UIParent, "BackdropTemplate")
    configFrame:SetSize(420, 764)
    configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    configFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    configFrame:SetToplevel(true)
    configFrame:SetClampedToScreen(true)
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    if UISpecialFrames then tinsert(UISpecialFrames, "EzWoWUtilityBarConfig") end

    ns.UIKit:ApplyBackdrop(configFrame, 1, 1)
    configFrame:SetBackdropColor(0.071, 0.094, 0.122, 0.97)
    configFrame:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
    self.ConfigFrame = configFrame

    -- Top Header Bar (58px)
    local top = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
    top:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -1, -1)
    top:SetHeight(58)
    top:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    top:SetBackdropColor(0.114, 0.157, 0.192, 0.98)
    top:EnableMouse(true)
    top:RegisterForDrag("LeftButton")
    top:SetScript("OnDragStart", function()
        if not InCombatLockdown() then configFrame:StartMoving() end
    end)
    top:SetScript("OnDragStop", function()
        configFrame:StopMovingOrSizing()
    end)

    local accent = top:CreateTexture(nil, "ARTWORK")
    accent:SetColorTexture(0.788, 0.643, 0.937, 1)
    accent:SetPoint("BOTTOMLEFT", top, "BOTTOMLEFT", 0, 0)
    accent:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", 0, 0)
    accent:SetHeight(2)

    local titleIcon = top:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(28, 28)
    titleIcon:SetPoint("TOPLEFT", 14, -14)
    titleIcon:SetTexture(ns.MEDIA_PATH .. "Icon")

    local heading = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 48, -11)
    heading:SetText("EzWoW - Utility Bar")
    heading:SetTextColor(0.788, 0.643, 0.937)

    local sub = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -3)
    sub:SetWidth(320)
    sub:SetJustifyH("LEFT")
    sub:SetText(ns:L("subtitle"))
    sub:SetTextColor(0.655, 0.725, 0.773)

    local close = CreateFrame("Button", nil, top, "BackdropTemplate")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", top, "TOPRIGHT", -10, -10)
    close:SetFrameLevel(top:GetFrameLevel() + 3)
    ns.UIKit:ApplyBackdrop(close)
    close:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
    close:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
    local closeTxt = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    closeTxt:SetPoint("CENTER")
    closeTxt:SetText("X")
    closeTxt:SetTextColor(0.929, 0.957, 0.969)
    close:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.24, 0.30, 1)
        self:SetBackdropBorderColor(0.788, 0.643, 0.937, 1)
    end)
    close:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
        self:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
    end)
    close:SetScript("OnClick", function() configFrame:Hide() end)

    local function CreateSectionHeader(text, yOffset)
        local t = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOPLEFT", 20, yOffset)
        t:SetText(text)
        t:SetTextColor(0.788, 0.643, 0.937)
        local line = configFrame:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.204, 0.298, 0.357, 0.85)
        line:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 20, yOffset - 20)
        line:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -20, yOffset - 20)
        line:SetHeight(1)
        return t
    end

    local updateLabels

    -- 1. Visible Categories Section
    local categoryHeading = CreateSectionHeader(ns:L("categories"), -66)
    local categoryLabels, categoryChecks = {}, {}
    for i = 1, #self.order do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = 20 + col * 195
        local y = -90 - row * 25
        local c = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
        c:SetSize(24, 24)
        c:SetPoint("TOPLEFT", x, y)
        c:SetChecked(db.categories[self.order[i]])
        local t = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("LEFT", c, "RIGHT", 4, 0)
        t:SetWidth(155)
        t:SetJustifyH("LEFT")
        t:SetText(ns:GetGroupLabel(self.order[i]))
        t:SetTextColor(0.929, 0.957, 0.969)
        c:SetScript("OnClick", function(btn)
            local key = ns.order[i]
            if key then
                db.categories[key] = btn:GetChecked()
                ns:RefreshToolbar()
            end
        end)
        categoryChecks[i] = c
        categoryLabels[i] = t
    end

    -- 2. Icon Layout Section
    local layoutHeading = CreateSectionHeader(ns:L("layout"), -295)
    local function CreateOptionCheck(dbKey, yOffset)
        local c = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
        c:SetSize(25, 25)
        c:SetPoint("TOPLEFT", 20, yOffset)
        c:SetChecked(db[dbKey])
        local t = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("LEFT", c, "RIGHT", 5, 0)
        t:SetWidth(345)
        t:SetJustifyH("LEFT")
        t:SetTextColor(0.929, 0.957, 0.969)
        c:SetScript("OnClick", function(btn)
            db[dbKey] = not not btn:GetChecked()
            ns:RefreshToolbar()
        end)
        return c, t
    end

    local modeCheck, modeText = CreateOptionCheck("unified", -318)
    local bestCheck, bestText = CreateOptionCheck("bestOnly", -341)
    local growCheck, growText = CreateOptionCheck("growUp", -364)
    local lowStockCheck, lowStockText = CreateOptionCheck("lowStockWarn", -387)

    local langBtn = CreateFrame("Button", nil, configFrame, "BackdropTemplate")
    langBtn:SetPoint("TOPLEFT", 20, -416)
    langBtn:SetSize(187, 28)
    ns.UIKit:ApplyBackdrop(langBtn)
    langBtn:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
    langBtn:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
    local langText = langBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    langText:SetPoint("CENTER")
    langText:SetWidth(177)
    langBtn.label = langText
    langBtn:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(0.788, 0.643, 0.937, 1) end)
    langBtn:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(0.204, 0.298, 0.357, 1) end)

    local rankBtn = CreateFrame("Button", nil, configFrame, "BackdropTemplate")
    rankBtn:SetPoint("TOPLEFT", 213, -416)
    rankBtn:SetSize(187, 28)
    ns.UIKit:ApplyBackdrop(rankBtn)
    rankBtn:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
    rankBtn:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
    local rankText = rankBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rankText:SetPoint("CENTER")
    rankText:SetWidth(177)
    rankBtn:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(0.788, 0.643, 0.937, 1) end)
    rankBtn:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(0.204, 0.298, 0.357, 1) end)

    -- 3. Toolbar Controls Section
    local controlsHeading = CreateSectionHeader(ns:L("controls"), -452)
    local function CreateActionButton(text, x, y, onClick)
        local b = CreateFrame("Button", nil, configFrame, "BackdropTemplate")
        b:SetSize(181, 31)
        b:SetPoint("TOPLEFT", x, y)
        ns.UIKit:ApplyBackdrop(b)
        b:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
        b:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
        local label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("CENTER")
        label:SetWidth(173)
        label:SetWordWrap(false)
        label:SetText(text)
        label:SetTextColor(0.929, 0.957, 0.969)
        b:SetScript("OnEnter", function(s)
            s:SetBackdropColor(0.16, 0.21, 0.26, 1)
            s:SetBackdropBorderColor(0.788, 0.643, 0.937, 1)
        end)
        b:SetScript("OnLeave", function(s)
            s:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
            s:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
        end)
        b:SetScript("OnClick", onClick)
        return b, label
    end

    local function CreateStepper(x, y, getter, setter, minVal, maxVal, step)
        local label = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("TOPLEFT", x, y - 8)
        label:SetWidth(90)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)

        local function makeStepBtn(symbol, bx, delta)
            local btn = CreateFrame("Button", nil, configFrame, "BackdropTemplate")
            btn:SetSize(27, 29)
            btn:SetPoint("TOPLEFT", bx, y)
            ns.UIKit:ApplyBackdrop(btn)
            btn:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
            btn:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            txt:SetPoint("CENTER", 0, 0)
            txt:SetText(symbol)
            btn:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(0.788, 0.643, 0.937, 1) end)
            btn:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(0.204, 0.298, 0.357, 1) end)
            btn:SetScript("OnClick", function()
                setter(math.max(minVal, math.min(maxVal, getter() + delta)))
                if updateLabels then updateLabels() end
            end)
            return btn
        end

        local minus = makeStepBtn("-", x + 94, -step)
        makeStepBtn("+", x + 160, step)
        local value = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("CENTER", minus, "CENTER", 33, 0)
        value:SetWidth(40)
        value:SetJustifyH("CENTER")
        return label, value
    end

    local sizeLabel, sizeValue = CreateStepper(20, -478, function() return db.size or 36 end, function(v)
        db.size = v; db.manualWidth = nil; ns:RefreshToolbar()
    end, 24, 64, 2)

    local colsLabel, colsValue = CreateStepper(210, -478, function() return db.columns or 8 end, function(v)
        db.columns = v; db.manualWidth = nil; ns:RefreshToolbar()
    end, 4, 16, 1)

    local function GetOpacityPct()
        return math.floor((db.opacity or 1) * 100 + 0.5)
    end
    local alphaLabel, alphaValue = CreateStepper(20, -511, GetOpacityPct, function(v)
        db.opacity = v / 100
    end, 30, 100, 10)

    local fadeCheck = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
    fadeCheck:SetSize(26, 26)
    fadeCheck:SetPoint("TOPLEFT", 210, -512)
    fadeCheck:SetChecked(db.fade)
    local fadeText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fadeText:SetPoint("LEFT", fadeCheck, "RIGHT", 4, 0)
    fadeText:SetWidth(160)
    fadeText:SetJustifyH("LEFT")
    fadeText:SetTextColor(0.929, 0.957, 0.969)
    fadeCheck:SetScript("OnClick", function(s) db.fade = not not s:GetChecked() end)

    local lockBtn, lockText = CreateActionButton(ns:L("lock"), 20, -544, function()
        db.locked = not db.locked; ns:RefreshToolbar()
    end)
    local visBtn, visText = CreateActionButton(ns:L("show"), 219, -544, function()
        db.visible = not db.visible; ns:RefreshToolbar()
    end)
    local _, expandText = CreateActionButton(ns:L("expand"), 20, -579, function()
        for _, k in ipairs(ns.order) do db.collapsed[k] = false end
        ns:RefreshToolbar()
    end)
    local _, collapseText = CreateActionButton(ns:L("collapse"), 219, -579, function()
        for _, k in ipairs(ns.order) do db.collapsed[k] = true end
        ns:RefreshToolbar()
    end)
    local _, refreshText = CreateActionButton(ns:L("refresh"), 20, -614, function()
        ns:RefreshToolbar()
    end)
    local _, restoreText = CreateActionButton(ns:L("restore"), 219, -614, function()
        db.hidden = {}
        ns:RefreshToolbar()
        updateLabels()
    end)

    -- 4. Reset Position & Support / Donate Buttons & Footer
    local resetPosBtn, resetPosText = CreateActionButton(ns:L("resetPos"), 20, -688, function()
        if InCombatLockdown() then return end
        db.position = nil
        db.visible = true
        db.manualWidth = nil
        db.manualHeight = nil
        if ns.MainFrame then
            ns.MainFrame:ClearAllPoints()
            ns.MainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
        end
        ns:RefreshToolbar()
        updateLabels()
    end)
    resetPosBtn:ClearAllPoints()
    resetPosBtn:SetPoint("BOTTOMLEFT", configFrame, "BOTTOMLEFT", 20, 36)
    resetPosBtn:SetSize(185, 33)

    local donateBtn = CreateFrame("Button", nil, configFrame, "BackdropTemplate")
    donateBtn:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -20, 36)
    donateBtn:SetSize(185, 33)
    ns.UIKit:ApplyBackdrop(donateBtn)
    donateBtn:SetBackdropColor(0.18, 0.14, 0.24, 0.96)
    donateBtn:SetBackdropBorderColor(0.788, 0.643, 0.937, 0.95)
    local donateText = donateBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    donateText:SetPoint("CENTER")
    donateText:SetWidth(365)
    donateText:SetText(ns:L("donate"))
    donateText:SetTextColor(0.788, 0.643, 0.937)
    donateBtn:SetScript("OnEnter", function(s)
        s:SetBackdropColor(0.24, 0.19, 0.32, 1)
        s:SetBackdropBorderColor(0.788, 0.643, 0.937, 1)
    end)
    donateBtn:SetScript("OnLeave", function(s)
        s:SetBackdropColor(0.18, 0.14, 0.24, 0.96)
        s:SetBackdropBorderColor(0.788, 0.643, 0.937, 0.95)
    end)
    donateBtn:SetScript("OnMouseDown", function() donateText:SetPoint("CENTER", 1, -1) end)
    donateBtn:SetScript("OnMouseUp", function() donateText:SetPoint("CENTER", 0, 0) end)
    donateBtn:SetScript("OnClick", SettingsDialog.ShowDonatePopup)

    local hint = configFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 20, -654)
    hint:SetWidth(380)
    hint:SetJustifyH("LEFT")
    hint:SetText(ns:L("hint"))

    local foot = configFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    local ver = ns.GetVersion()
    foot:SetPoint("BOTTOM", 0, 12)
    foot:SetText("EzWoW - Utility Bar" .. (ver ~= "" and (" " .. ver) or "") .. "  ·  /ezub")

    updateLabels = function()
        ns.FitText(categoryHeading, ns:L("categories"), 375, 13, 10)
        ns.FitText(layoutHeading, ns:L("layout"), 375, 13, 10)
        ns.FitText(controlsHeading, ns:L("controls"), 375, 13, 10)
        for i, k in ipairs(ns.order) do
            if categoryLabels[i] then ns.FitText(categoryLabels[i], ns:GetGroupLabel(k), 150, 12, 9) end
            if categoryChecks[i] then categoryChecks[i]:SetChecked(db.categories[k]) end
        end
        ns.FitText(modeText, ns:L("unified"), 340, 12, 9)
        modeCheck:SetChecked(db.unified)
        ns.FitText(bestText, ns:L("bestOnly"), 340, 12, 9)
        bestCheck:SetChecked(db.bestOnly)
        ns.FitText(growText, ns:L("growUp"), 340, 12, 9)
        growCheck:SetChecked(db.growUp)
        ns.FitText(lowStockText, ns:L("lowStockWarn"), 340, 12, 9)
        lowStockCheck:SetChecked(db.lowStockWarn)
        ns.FitText(langText, ns:L("language") .. ": " .. ns:GetLanguageDisplayLabel() .. " ▼", 177, 12, 9)
        ns.FitText(rankText, ns:L("spellRanks") .. ": " .. ns:L(db.spellRanks == "all" and "allRanks" or "highestRank") .. " ▼", 177, 12, 9)
        if resetPosText then ns.FitText(resetPosText, ns:L("resetPos"), 171, 12, 9) end
        ns.FitText(donateText, ns:L("donate"), 171, 12, 9)
        ns.FitText(hint, ns:L("hint"), 375, 10, 8)
        ns.FitText(sub, ns:L("subtitle"), 345, 10, 8)
        ns.FitText(expandText, ns:L("expand"), 171, 12, 9)
        ns.FitText(collapseText, ns:L("collapse"), 171, 12, 9)
        ns.FitText(refreshText, ns:L("refresh"), 171, 12, 9)
        ns.FitText(sizeLabel, ns:L("size"), 88, 12, 9)
        sizeValue:SetText(tostring(db.size or 36))
        ns.FitText(colsLabel, ns:L("columns"), 88, 12, 9)
        colsValue:SetText(tostring(db.columns or 8))
        ns.FitText(lockText, ns:L(db.locked and "unlock" or "lock"), 171, 12, 9)
        ns.FitText(visText, ns:L(db.visible and "hide" or "show"), 171, 12, 9)
        ns.FitText(alphaLabel, ns:L("opacity"), 88, 12, 9)
        alphaValue:SetText(GetOpacityPct() .. "%")
        ns.FitText(fadeText, ns:L("fade"), 160, 12, 9)
        fadeCheck:SetChecked(db.fade)

        local hiddenCount = 0
        for _ in pairs(db.hidden or {}) do hiddenCount = hiddenCount + 1 end
        ns.FitText(restoreText, ns:L("restore") .. " (" .. hiddenCount .. ")", 171, 12, 9)
        restoreText:SetTextColor(hiddenCount > 0 and 0.94 or 0.55, hiddenCount > 0 and 0.80 or 0.58, hiddenCount > 0 and 0.53 or 0.60)
        if copyBox and copyBox.label then copyBox.label:SetText(ns:L("copy")) end
        if optionsPanel and optionsPanel.refreshText then optionsPanel.refreshText() end
    end

    rankBtn:SetScript("OnClick", function()
        db.spellRanks = (db.spellRanks == "all") and "highest" or "all"
        updateLabels()
        ns:RefreshToolbar()
    end)

    -- click the box, then pick a language from the list
    local langItems = {}
    for i, v in ipairs(ns.LANGUAGE_OPTIONS) do langItems[i] = { value = v[1], text = v[2] } end
    ns.LanguageDropdown.Attach(langBtn, {
        items = langItems,
        colors = { accent = { 0.788, 0.643, 0.937, 1 } },
        get = function() return db.language end,
        set = function(code)
            db.language = code
            updateLabels()
            ns:RefreshToolbar()
        end,
    })

    for _, btn in ipairs({ lockBtn, visBtn }) do
        btn:HookScript("OnClick", updateLabels)
    end

    configFrame:SetScript("OnShow", updateLabels)
    configFrame.updateLabels = updateLabels
    updateLabels()
end

-----------------------------------------------------------------------------
-- Blizzard Settings Canvas Launcher
-----------------------------------------------------------------------------
function ns:RegisterBlizzardOptions()
    if optionsPanel then return end
    optionsPanel = CreateFrame("Frame", "EzWoWUtilityBarOptionsPanel", UIParent)
    optionsPanel.name = "EzWoW - Utility Bar"

    local icon = optionsPanel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPLEFT", 18, -18)
    icon:SetTexture(ns.MEDIA_PATH .. "Icon")

    local heading = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    heading:SetText("EzWoW - Utility Bar")
    heading:SetTextColor(0.788, 0.643, 0.937)

    local desc = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -14)
    desc:SetWidth(520)
    desc:SetJustifyH("LEFT")
    desc:SetText(ns:L("panelDesc"))

    local open = CreateFrame("Button", nil, optionsPanel, "BackdropTemplate")
    open:SetSize(220, 28)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
    ns.UIKit:ApplyBackdrop(open)
    open:SetBackdropColor(0.18, 0.14, 0.24, 0.96)
    open:SetBackdropBorderColor(0.788, 0.643, 0.937, 1)
    open.label = open:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    open.label:SetPoint("CENTER")
    open.label:SetTextColor(0.788, 0.643, 0.937)
    open.label:SetText(ns:L("panelOpen"))
    ns.UIKit:FitFontString(open.label, 212, 1)
    open:SetScript("OnEnter", function(s)
        s:SetBackdropColor(0.24, 0.19, 0.32, 1)
        s:SetBackdropBorderColor(0.788, 0.643, 0.937, 1)
    end)
    open:SetScript("OnLeave", function(s)
        s:SetBackdropColor(0.18, 0.14, 0.24, 0.96)
        s:SetBackdropBorderColor(0.788, 0.643, 0.937, 1)
    end)
    open:SetScript("OnMouseDown", function(s) s.label:SetPoint("CENTER", 1, -1) end)
    open:SetScript("OnMouseUp", function(s) s.label:SetPoint("CENTER", 0, 0) end)
    open:SetScript("OnClick", function() ns:ToggleOptions() end)

    local hint = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -14)
    hint:SetTextColor(0.655, 0.725, 0.773)
    hint:SetText(ns:L("panelHint"))

    optionsPanel.refreshText = function()
        desc:SetText(ns:L("panelDesc"))
        open.label:SetText(ns:L("panelOpen"))
        ns.UIKit:FitFontString(open.label, 212, 1)
        hint:SetText(ns:L("panelHint"))
    end
    optionsPanel:SetScript("OnShow", optionsPanel.refreshText)

    if Settings and type(Settings.RegisterCanvasLayoutCategory) == "function" and type(Settings.RegisterAddOnCategory) == "function" then
        local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, optionsPanel, "EzWoW - Utility Bar")
        if ok and cat then
            pcall(Settings.RegisterAddOnCategory, cat)
        end
    elseif type(InterfaceOptions_AddCategory) == "function" then
        pcall(InterfaceOptions_AddCategory, optionsPanel)
    end
end

-----------------------------------------------------------------------------
-- Slash Commands (/ezub, /eub, /fub, /ezwowutilitybar)
-----------------------------------------------------------------------------
SLASH_EZWOWUTILITYBAR1 = "/ezub"
SLASH_EZWOWUTILITYBAR2 = "/eub"
SLASH_EZWOWUTILITYBAR3 = "/fub"
SLASH_EZWOWUTILITYBAR4 = "/ezwowutilitybar"

SlashCmdList.EZWOWUTILITYBAR = function(msg)
    local db = ns.db or _G.EzWoW_UtilityBarDB
    if not db then
        ns.Print(ns:L("waiting"))
        return
    end
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "refresh" then
        ns:RefreshToolbar()
    elseif msg == "lock" then
        db.locked = not db.locked
        ns:RefreshToolbar()
        ns.Print(ns:L(db.locked and "lockedMsg" or "unlockedMsg"))
    elseif msg == "show" then
        db.visible = true
        ns:RefreshToolbar()
    elseif msg == "hide" then
        db.visible = false
        ns:RefreshToolbar()
    elseif msg:match("^lang") then
        local arg = msg:match("^%S+%s+(%S+)")
        local norm = arg and ns.LANG_ALIASES[arg]
        if not norm then
            ns.Print("/ezub lang auto | ko | en | de | fr | es | ru | cn | tw")
            return
        end
        db.language = norm
        if configFrame and configFrame.updateLabels then configFrame.updateLabels() end
        ns:RefreshToolbar()
        ns.Print(ns:L("language") .. ": " .. norm .. " (" .. ns:GetActiveLang() .. ")")
    else
        ns:ToggleOptions()
    end
end
