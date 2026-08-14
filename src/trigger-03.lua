-- Do not remove this comment, it is part of this aura: Energy Ticklizer
function(a, e, t, powerType)
    if not WeakAuraEnergyTicklerFrame then
        local f = CreateFrame("frame", "WeakAuraEnergyTicklerFrame")
        f:SetScript("OnUpdate", function(self)
                local now = GetTime()
                local currEnergy = UnitPower("player", 3)
                local energyDiff = currEnergy - (self.lastEnergy or 0)
                local timeDiff = now - (self.lastTick or 0)
                self.lastEnergy = currEnergy
                if timeDiff >= 2.02 then
                    WeakAuras.ScanEvents("ENERGYTICKLE")
                    self.lastTick = now
                    return
                end
                if energyDiff <= 0 then return end
                if energyDiff > 21 or (energyDiff < 20 and currEnergy ~= UnitPowerMax("player", 3)) then return end
                if now - (self.energized or 0) < 0.02 then return end
                self.lastTick = now
                WeakAuras.ScanEvents("ENERGYTICKLE")
        end)
        f:SetScript("OnEvent", function(self)
                local params = {CombatLogGetCurrentEventInfo()}
                local e, u, t = params[2], params[4], params[17]
                if e ~= "SPELL_ENERGIZE" then return end
                if u ~= UnitGUID("player") then return end
                if t ~= 3 then return end
                self.energized = GetTime()
        end)
        f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
    if (e ~= "ENERGYTICKLE") then return end
    if not a.s  then
        a.s = {
            show = true,
            progressType = "timed"
        }
    end
    local s = a.s
    s.changed = true
    s.duration = 2.02
    s.expirationTime = GetTime() + 2.02
    aura_env.lastTick = GetTime()
    WeakAuras.ScanEvents("ENERGY_TICK_TIME", aura_env.lastTick)
    return true
end

