--===========================================================================
-- EzWoW - Utility Bar
-- Modules/PetSummon.lua : Auto-summon companion pet (option, default off)
--===========================================================================
-- Keeps a companion pet out: when none is out, summons a random favourite
-- (any random pet while the account has no favourites), a moment after a
-- trigger event. Never in combat, mounted, on a taxi or vehicle, dead,
-- stealthed, feigning death, in an instance, or while casting.
--
-- The pet journal's summon calls are plain API here (refused only in combat),
-- so the summon runs from a timer; no click is needed.
--
-- A pet the player puts away stays away until they summon one again (or
-- re-log): the journal's Dismiss and its toggle are seen by post-hooks; a
-- pet that vanishes with no game reason (action bar, macro) counts too.
--===========================================================================
local _, ns = ...
local PetSummon = ns.PetSummon or {}
ns.PetSummon = PetSummon
local type, pcall = type, pcall

local DELAY = 2           -- seconds after a trigger: lets a load, landing or dismount settle
local LOGIN_DELAY = 5     -- after a loading screen
local THROTTLE = 3        -- at most one summon attempt per this many seconds
local CAUSE_WINDOW = 4    -- a pet lost this soon after a game cause was not the player's doing

local ev = CreateFrame("Frame")
local pending = false     -- a summon attempt is scheduled
local lastAttempt = 0
local hooked = false
local registered = false
local castWait = false
local userDismissed = false   -- the player put the pet away (this session)
local current                 -- the pet we last saw out (nil: none)
local lastCause = 0           -- last time the game itself may have taken the pet

local function Now()
    return (type(GetTime) == "function" and GetTime()) or 0
end

local function J()
    local j = _G.C_PetJournal
    return type(j) == "table" and j or nil
end

function PetSummon.IsSupported()
    local j = J()
    return j ~= nil
        and type(j.GetSummonedPetGUID) == "function"
        and type(j.SummonRandomPet) == "function"
end

local function IsEnabled()
    return ns.db ~= nil and ns.db.autoSummonPet == true and PetSummon.IsSupported()
end

local function SummonedGUID()
    local ok, guid = pcall(J().GetSummonedPetGUID)
    if not ok or guid == nil or ns.IsSecret(guid) then return nil end
    return guid
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok or ns.IsSecret(a) then return nil end
    return a, b
end

-- Blockers that lift by themselves; each has an event that queues again.
local function IsBlocked()
    if Call(UnitIsDeadOrGhost, "player") then return true end
    if Call(UnitOnTaxi, "player") then return true end
    if Call(UnitInVehicle, "player") then return true end
    if Call(IsMounted) then return true end
    if Call(IsStealthed) then return true end
    if Call(UnitIsFeignDeath, "player") then return true end
    if Call(IsInInstance) then return true end
    return false
end

local function IsCasting()
    return Call(UnitCastingInfo, "player") ~= nil or Call(UnitChannelInfo, "player") ~= nil
end

local function WaitForCastEnd()
    if castWait then return end
    castWait = true
    if ev.RegisterUnitEvent then
        pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_STOP", "player")
        pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_CHANNEL_STOP", "player")
    else
        pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_STOP")
        pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_CHANNEL_STOP")
    end
end

local function StopCastWait()
    if not castWait then return end
    castWait = false
    pcall(ev.UnregisterEvent, ev, "UNIT_SPELLCAST_STOP")
    pcall(ev.UnregisterEvent, ev, "UNIT_SPELLCAST_CHANNEL_STOP")
end

local Queue

local function Attempt()
    pending = false
    if not IsEnabled() or userDismissed then return end
    if SummonedGUID() then return end
    if InCombatLockdown() then return end   -- PLAYER_REGEN_ENABLED queues again
    if IsBlocked() then return end
    if IsCasting() then
        WaitForCastEnd()
        return
    end
    local wait = THROTTLE - (Now() - lastAttempt)
    if wait > 0 then
        Queue(wait)
        return
    end
    lastAttempt = Now()
    local j = J()
    -- the argument is "all pets": false = favourites only, true = any pet
    local favourites = Call(j.HasFavoritePets) and true or false
    pcall(j.SummonRandomPet, not favourites)
end

Queue = function(delay)
    if pending or not IsEnabled() or userDismissed then return end
    pending = true
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay or DELAY, Attempt)
    else
        Attempt()
    end
end

-- A pet that vanished with no game reason was put away by the player
-- (action bar or macro: those run in the client, unseen by the hooks).
local function CheckVanish()
    if not IsEnabled() or userDismissed or SummonedGUID() then return end
    if Now() - lastCause < CAUSE_WINDOW or InCombatLockdown() or IsBlocked() then
        Queue()
        return
    end
    userDismissed = true
end

local function OnCompanionUpdate()
    local guid = SummonedGUID()
    local before = current
    current = guid
    if guid then
        userDismissed = false   -- the player (or we) summoned one: watching again
        return
    end
    if before and C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(1, CheckVanish)
    end
end

-- The player's own dismissals: Dismiss, or summoning the pet that is out
-- (the journal's toggle). Post-hooks; the pet may already be gone.
local function OnDismiss()
    if IsEnabled() then userDismissed = true end
end

local function OnSummonByGUID(guid)
    if IsEnabled() and guid and guid == current then userDismissed = true end
end

-- Events after which the game may have taken the pet, and after which a
-- missing pet may come back.
local CAUSE_EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_MOUNT_DISPLAY_CHANGED",
    "UPDATE_STEALTH", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE", "PLAYER_REGEN_ENABLED", "COMPANION_UPDATE",
}

local function SetRegistered(on)
    if registered == on then return end
    registered = on
    for i = 1, #CAUSE_EVENTS do
        if on then
            pcall(ev.RegisterEvent, ev, CAUSE_EVENTS[i])
        else
            pcall(ev.UnregisterEvent, ev, CAUSE_EVENTS[i])
        end
    end
    if not on then StopCastWait() end
end

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        ev:UnregisterEvent("PLAYER_LOGIN")
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0, function() PetSummon.Apply() end)
        else
            PetSummon.Apply()
        end
        return
    end
    if not IsEnabled() then return end
    if event == "COMPANION_UPDATE" then
        if arg1 == "MOUNT" then return end
        OnCompanionUpdate()
        return
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if arg1 and arg1 ~= "player" then return end
        StopCastWait()
        Queue(1)
        return
    elseif (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and arg1 ~= "player" then
        return
    end
    lastCause = Now()
    if event == "PLAYER_ENTERING_WORLD" then
        Queue(LOGIN_DELAY)
    else
        Queue()
    end
end)
pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")

-- Login and the option toggle; takes effect at once in both directions.
-- fresh: the player just turned it on, which also ends an earlier dismissal.
function PetSummon.Apply(fresh)
    if not PetSummon.IsSupported() then return end
    local on = IsEnabled()
    SetRegistered(on)
    if not on then return end
    if not hooked then
        hooked = true
        local j = J()
        if type(j.DismissSummonedPet) == "function" then
            pcall(hooksecurefunc, j, "DismissSummonedPet", OnDismiss)
        end
        if type(j.SummonPetByGUID) == "function" then
            pcall(hooksecurefunc, j, "SummonPetByGUID", OnSummonByGUID)
        end
    end
    current = SummonedGUID()
    if fresh then userDismissed = false end
    Queue(fresh and DELAY or LOGIN_DELAY)
end
