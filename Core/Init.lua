--===========================================================================
-- EzWoW - Utility Bar
-- Core/Init.lua : Namespace, EzWoW Style Palette, Taint Guards & SavedVariables
--===========================================================================
local ADDON_NAME, ns = ...
local CoreBootstrap = ns.CoreBootstrap or {}
ns.CoreBootstrap = CoreBootstrap
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

_G.EzWoW_UtilityBar = ns
_G.EzWoW_UtilityBar = ns

ns.ADDON_NAME = ADDON_NAME or "EzWoW-UtilityBar"
ns.MEDIA_PATH = "Interface\\AddOns\\EzWoW-UtilityBar\\Media\\"
ns.DONATE_URL = "https://buymeacoffee.com/qqhrqqhr2"

-----------------------------------------------------------------------------
-- EzWoW Style v1.0 Palette (Brand Accent: Purple #C9A4EF)
-----------------------------------------------------------------------------
ns.Style = {
    bgPrimary   = { 0.071, 0.094, 0.122, 0.93 }, -- #12181F
    bgSecondary = { 0.114, 0.157, 0.192, 0.96 }, -- #1D2831
    border      = { 0.204, 0.298, 0.357, 1.00 }, -- #344C5B
    textBody    = { 0.929, 0.957, 0.969, 1.00 }, -- #EDF4F7
    textMuted   = { 0.655, 0.725, 0.773, 1.00 }, -- #A7B9C5
    accent      = { 0.788, 0.643, 0.937, 1.00 }, -- #C9A4EF
    accentHex   = "C9A4EF",
    gold        = { 0.950, 0.760, 0.330, 1.00 },
    warning     = { 0.906, 0.486, 0.439, 1.00 }, -- #E77C70
    disabled    = { 0.388, 0.447, 0.482, 1.00 }, -- #63727B
}

-----------------------------------------------------------------------------
-- Default Category Order & Configuration Schema
-----------------------------------------------------------------------------
ns.DEFAULT_ORDER = {
    "potion",
    "trinket",
    "elixir",
    "weaponbuff",
    "food",
    "bandage",
    "camping",
    "quest",
    "travel",
    "engineering",
    "other",
    "profession",
    "forms",
    "classskill",
    "reagent",
}

ns.DEFAULTS = {
    size         = 36,
    columns      = 8,
    locked       = false,
    visible      = true,
    opacity      = 1,
    fade         = false,
    categories   = {},
    collapsed    = {},
    hidden       = {},
    language     = "auto",
    position     = nil,
    manualWidth  = nil,
    manualHeight = nil,
    unified      = false,
    spellRanks   = "highest",
    bestOnly     = false,
    growUp       = false,
    lowStockWarn = true,
}

ns.order = {}
for i, k in ipairs(ns.DEFAULT_ORDER) do
    ns.order[i] = k
end

ns.waitingItems = {}
ns.hoverUIActive = false
ns.pendingRefresh = false

-----------------------------------------------------------------------------
-- Security & String Helpers (Interface 16001)
-----------------------------------------------------------------------------
function ns.IsSecret(value)
    return type(_G.issecretvalue) == "function" and _G.issecretvalue(value) and true or false
end

function ns.ToBooleanFlag(value)
    if ns.IsSecret(value) then
        return nil
    end
    return value == true or value == 1
end

function ns.LowerText(str)
    local s = (str or ""):lower()
    s = s:gsub("\208([\144-\159])", function(c)
        return "\208" .. string.char(c:byte() + 32)
    end)
    s = s:gsub("\208([\160-\175])", function(c)
        return "\209" .. string.char(c:byte() - 32)
    end)
    s = s:gsub("\208\129", "\209\145")
    return s
end

function ns.GetVersion()
    local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if type(getter) == "function" then
        local ok, ver = pcall(getter, ns.ADDON_NAME, "Version")
        if ok and type(ver) == "string" and ver ~= "" and not ver:find("^@") then
            return ver
        end
    end
    return ""
end

function ns.Print(msg)
    print("|cffC9A4EFEzWoW - Utility Bar:|r " .. tostring(msg or ""))
end

function ns.FitText(fs, text, maxWidth, baseSize, minSize)
    if not fs then return end
    text = text or ""
    fs:SetWordWrap(false)
    local font, _, flags = fs:GetFont()
    if not font then
        fs:SetText(text)
        return
    end
    fs:SetFont(font, baseSize, flags)
    fs:SetText(text)
    local size = baseSize
    while fs:GetStringWidth() > maxWidth and size > minSize do
        size = size - 0.5
        fs:SetFont(font, size, flags)
    end
    if fs:GetStringWidth() > maxWidth then
        local original = text
        while #text > 0 and fs:GetStringWidth() > maxWidth do
            text = text:sub(1, -2)
            while #text > 0 and string.byte(text, #text) >= 128 and string.byte(text, #text) < 192 do
                text = text:sub(1, -2)
            end
            fs:SetText(text .. "...")
            if text == original then break end
        end
    end
end

-----------------------------------------------------------------------------
-- SavedVariables Initialization & Normalization
-----------------------------------------------------------------------------
function ns:InitDB()
    if type(_G.EzWoW_UtilityBarDB) ~= "table" then
        if type(_G.EzWoW_UtilityBarDB) == "table" and next(_G.EzWoW_UtilityBarDB) ~= nil then
            _G.EzWoW_UtilityBarDB = _G.EzWoW_UtilityBarDB
        else
            _G.EzWoW_UtilityBarDB = {}
        end
    elseif type(_G.EzWoW_UtilityBarDB) == "table" then
        for k, v in pairs(_G.EzWoW_UtilityBarDB) do
            if _G.EzWoW_UtilityBarDB[k] == nil then
                _G.EzWoW_UtilityBarDB[k] = v
            end
        end
    end

    _G.EzWoW_UtilityBarDB = _G.EzWoW_UtilityBarDB
    self.db = _G.EzWoW_UtilityBarDB

    for k, v in pairs(self.DEFAULTS) do
        if self.db[k] == nil then
            if type(v) == "table" then
                self.db[k] = {}
            else
                self.db[k] = v
            end
        end
    end

    self.db.categories = type(self.db.categories) == "table" and self.db.categories or {}
    self.db.categories.bomb = nil

    local validSet = {}
    for _, key in ipairs(self.DEFAULT_ORDER) do
        validSet[key] = true
    end

    local resolvedOrder, seen = {}, {}
    if type(self.db.order) == "table" then
        for _, key in ipairs(self.db.order) do
            if validSet[key] and not seen[key] then
                resolvedOrder[#resolvedOrder + 1] = key
                seen[key] = true
            end
        end
    end
    for _, key in ipairs(self.DEFAULT_ORDER) do
        if not seen[key] then
            resolvedOrder[#resolvedOrder + 1] = key
            seen[key] = true
        end
    end

    self.order = resolvedOrder
    self.db.order = resolvedOrder

    if type(self.db.collapsed) ~= "table" then self.db.collapsed = {} end
    if type(self.db.hidden) ~= "table" then self.db.hidden = {} end
    if type(self.db.opacity) ~= "number" then self.db.opacity = 1 end

    for _, key in ipairs(self.order) do
        if self.db.categories[key] == nil then self.db.categories[key] = true end
        if self.db.collapsed[key] == nil then self.db.collapsed[key] = false end
    end
end
