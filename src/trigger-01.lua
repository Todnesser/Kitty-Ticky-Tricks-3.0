function()
    -- 1. Check if we are in Cat Form (Shapeshift Form index 3)
    local _, activeForm = GetShapeshiftFormInfo(3) 
    if not activeForm then 
        WA_Feral_Helper_Icon = nil
        WA_Feral_Helper_Spell_Name = ""
        WA_Feral_Helper_Wait_Text = ""
        return false 
    end
    
    -- 2. Pull Dynamic Player State & Resources
    local energy = UnitPower("player", 3) -- 3 = Energy
    local mana = UnitPower("player", 0)   -- 0 = Mana
    local cp = GetComboPoints("player", "target")
    
    -- 3. Spell / Debuff Configuration
    local mangleSpellID = 33983  
    local shredSpellID = 27002   
    local ripSpellID = 27008
    local biteSpellID = 24248
    local rakeSpellID = 27003
    local ffSpellID = 27011      -- Faerie Fire (Feral)
    local catFormSpellID = 768
    
    local spellNames = {
        [mangleSpellID]="Mangle",
        [shredSpellID]="Shred",
        [ripSpellID]="Rip",
        [biteSpellID]="Bite",
        [rakeSpellID]="Rake",
        [ffSpellID]="Faerie Fire",
        [catFormSpellID]="Powershift"
    }
    
    -- Rotation preferences (FeralDruidRotation / setupRotation)
    local useBite = aura_env.config.useBite          
    local biteOverRip = aura_env.config.biteOverRip
    local useRakeTrick = aura_env.config.useRakeTrick
    local useMangleTrick = aura_env.config.useMangleTrick
    local useRipTrick = aura_env.config.useRipTrick
    local maintainFaerieFire = aura_env.config.maintainFaerieFire
    local isNearEndHP = aura_env.config.nearEndHPThreshold
    
    local ripCp = aura_env.config.ripCp
    local biteCp = aura_env.config.biteCp
    local ripTrickCP = aura_env.config.ripTrickCp
    
    -- Go Constants & Thresholds
    local BiteTrickMax = 39.0
    local BiteTrickCP = 2
    local RipTrickMin = 52.0
    local BiteTime = 0.0 
    local maxWaitTime = 1.0
    
    -- Dynamic Spell Cost calculations
    local ripCost = 30
    local biteCost = 35
    local shredCost = 42 
    local isMangleTalented = true   
    local mangleCost = 45.0 
    if isMangleTalented then
        mangleCost = 40 
    end
    local T6_FERAL_SET_IDS = {
        [31039] = true, -- Thunderheart Cover (Helmet)
        [31048] = true, -- Thunderheart Pauldrons
        [31042] = true, -- Thunderheart Chestguard
        [34444] = true, -- Thunderheart Wristguards
        [31034] = true, -- Thunderheart Gauntlets
        [34556] = true, -- Thunderheart Waistguard
        [31044] = true, -- Thunderheart Leggings
        [34573] = true, -- Thunderheart Treads
    }
    local WOLFSHEAD_ID = 8345
    local wolfshead = false
    local equippedCount = 0
    -- Slots: 1 (Head), 3 (Shoulder), 5 (Chest), 9 (Wrist), 10 (Hands), 12 (Legs), 8 (Feet), 6 (Waist)
    local slots = {1, 3, 5, 6, 8, 9, 10, 12} 
    
    for _, slot in ipairs(slots) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            if T6_FERAL_SET_IDS[itemID] then
                equippedCount = equippedCount + 1
            elseif itemID == WOLFSHEAD_ID then
                wolfshead = true
            end
        end
    end
    
    if equippedCount >= 2 then
        mangleCost = mangleCost - 5
    end
    
    local spellCosts = {
        [mangleSpellID] = mangleCost,
        [shredSpellID] = 42,
        [ripSpellID] = 30,
        [biteSpellID] = 35,
        [rakeSpellID] = 35,
        [ffSpellID] = 0,
        [catFormSpellID] = 0
    }
    
    -- Check if Faerie Fire (Feral) is on Cooldown (ignoring standard GCD)
    local ffReady = true
    local start, duration = GetSpellCooldown(ffSpellID)
    if start and duration and duration > 1.5 then
        ffReady = false
    end
    
    -- Dynamic Shift Cost calculation
    local shiftCost = 581         
    local costTable = GetSpellPowerCost(catFormSpellID)
    if costTable then
        for _, costInfo in pairs(costTable) do
            if costInfo.type == 0 then
                shiftCost = costInfo.cost
            end
        end
    end
    
    -- 4. Clearcasting (Omen of Clarity) Check
    local omenProc = false
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if name == "Clearcasting" then
            omenProc = true
            break
        end
    end
    
    -- 5. Target Debuff Checks & Expiration Timing
    local hasMangle = false
    local mangleRemaining = 0
    local hasRip = false
    local ripRemaining = 0
    local hasRake = false
    local hasFF = false
    
    if UnitExists("target") and not UnitIsDead("target") then
        for i = 1, 40 do
            local name, _, _, _, duration, expirationTime, _, _, _, spellId = UnitDebuff("target", i)
            if not name then break end
            
            if spellId == mangleSpellID or spellId == 33876 or spellId == 33878 or spellId == 35290 or name == "Mangle (Cat)" or name == "Mangle (Bear)" or name == "Mangle" then
                hasMangle = true
                if expirationTime and expirationTime > 0 then
                    mangleRemaining = expirationTime - GetTime()
                end
            elseif spellId == ripSpellID or name == "Rip" then
                hasRip = true
                if expirationTime and expirationTime > 0 then
                    ripRemaining = expirationTime - GetTime()
                end
            elseif spellId == rakeSpellID or name == "Rake" then
                hasRake = true
            elseif spellId == ffSpellID or name == "Faerie Fire (Feral)" or name == "Faerie Fire" then
                hasFF = true
            end
        end
    end
    
    -- 6. Tick Timing Predictions
    if not WA_Feral_LastEnergy then WA_Feral_LastEnergy = energy end
    if not WA_Feral_LastTickTime then WA_Feral_LastTickTime = GetTime() end
    
    local currentTime = GetTime()
    if energy > WA_Feral_LastEnergy then
        WA_Feral_LastTickTime = currentTime
    end
    WA_Feral_LastEnergy = energy
    
    local timeToNextTick = 2.0 - (currentTime - WA_Feral_LastTickTime)
    if timeToNextTick < 0 or timeToNextTick > 2.0 then timeToNextTick = 2.0 end
    
    -- 7. Logic Triggers Mirroring Go Properties
    local targetHealthPercent = (UnitHealth("target") / UnitHealthMax("target")) * 100
    local isNearEnd = (targetHealthPercent > 0 and targetHealthPercent < isNearEndHP)
    
    -- Maintain Faerie Fire first (only if enabled, debuff is missing, and spell is off cooldown)
    if maintainFaerieFire and not hasFF and ffReady then
        WA_Feral_Helper_Icon = GetSpellTexture(ffSpellID)
        WA_Feral_Helper_Spell_Name = "Faerie Fire"
        WA_Feral_Helper_Wait_Text = ""
        return true
    end
    
    local ripNow = cp >= ripCp and not hasRip and not isNearEnd
    local ripweaveNow = useRipTrick and cp >= ripTrickCP and not hasRip and energy >= RipTrickMin and not isNearEnd
    ripNow = ripNow or ripweaveNow
    
    -- Fixed the "biteAtEnd" logic to avoid incorrectly biting in the middle of a fight
    local biteAtEnd = cp >= biteCp and isNearEnd
    
    local mangleNow = isMangleTalented and not ripNow and not hasMangle
    
    local biteBeforeRip = hasRip and useBite and ripRemaining >= BiteTime
    local biteNow = (biteBeforeRip or biteOverRip) and cp >= biteCp
    
    local ripNext = (ripNow or (cp >= ripCp and ripRemaining <= timeToNextTick)) and (not isNearEnd)
    local mangleNext = not ripNext and (mangleNow or mangleRemaining <= timeToNextTick)
    local waitToMangle = mangleNext or (not wolfshead and mangleCost <= 38)
    
    local biteBeforeRipNext = biteBeforeRip and (ripRemaining - timeToNextTick) >= BiteTime
    local prioBiteOverMangle = biteOverRip or not mangleNow
    
    local recommendedSpellID = nil
    
    -- 8. SIMULATOR ROTATION DECISION TREE
    
    -- Out of Mana / Low Mana Rule (No-shift rotation when OOM)
    if mana < shiftCost then
        if ripNow and (energy >= ripCost or omenProc) then
            recommendedSpellID = ripSpellID
        elseif mangleNow and (energy >= mangleCost or omenProc) then
            recommendedSpellID = mangleSpellID
        elseif biteNow and (energy >= biteCost or omenProc) then
            recommendedSpellID = biteSpellID
        elseif energy >= shredCost or omenProc then
            recommendedSpellID = shredSpellID
        end
        
        -- Bottomed out on Energy
    elseif energy < 10 then
        recommendedSpellID = catFormSpellID
        
        -- Rip Logic
    elseif ripNow then
        if energy >= ripCost or omenProc then
            recommendedSpellID = ripSpellID
        elseif timeToNextTick > maxWaitTime then 
            recommendedSpellID = catFormSpellID
        else
            recommendedSpellID = ripSpellID
        end
        
        -- Bite / BiteAtEnd Logic
    elseif (biteNow or biteAtEnd) and prioBiteOverMangle then
        local cutoffMod = 20.0
        if timeToNextTick <= 1.0 then cutoffMod = 0.0 end
        
        if energy >= (shredCost + 15.0 + cutoffMod) or (energy >= (15 + cutoffMod) and omenProc) then
            recommendedSpellID = shredSpellID
        elseif energy >= biteCost then
            recommendedSpellID = biteSpellID
        else
            local wait = false
            if energy >= 22 and biteBeforeRip and not biteBeforeRipNext then
                wait = true
            elseif energy >= 15 and (not biteBeforeRip or biteBeforeRipNext or biteAtEnd) then
                wait = true
            elseif not ripNext and (energy < 20 or not mangleNext) then
                wait = false
                recommendedSpellID = catFormSpellID
            else
                wait = true
            end
            
            if wait then
                if timeToNextTick > maxWaitTime then
                    recommendedSpellID = catFormSpellID
                else
                    recommendedSpellID = biteSpellID
                    
                end
            end
        end
        
        -- Bite Trick / Rake Trick Logic
    elseif energy >= biteCost and energy <= BiteTrickMax and useRakeTrick and not omenProc and cp >= BiteTrickCP then
        recommendedSpellID = biteSpellID
    elseif energy >= biteCost and energy < mangleCost and useRakeTrick and timeToNextTick > 1.0 and not hasRake and not omenProc then
        recommendedSpellID = rakeSpellID
        
        -- Mangle Logic
    elseif mangleNow then
        if energy < (mangleCost - 20) and not ripNext then
            recommendedSpellID = catFormSpellID
        elseif energy >= mangleCost or omenProc then
            recommendedSpellID = mangleSpellID
        elseif timeToNextTick > maxWaitTime then
            recommendedSpellID = catFormSpellID
        else
            recommendedSpellID = mangleSpellID
        end
        
        -- Builder Phase
    elseif energy >= 22 then
        if omenProc then
            recommendedSpellID = shredSpellID
            -- Mangle Trick scenario
        elseif isMangleTalented and energy >= (2 * mangleCost - 20) and energy < (22 + mangleCost) and timeToNextTick <= 1.0 and useMangleTrick and (not useRakeTrick or mangleCost == 35) then
            recommendedSpellID = mangleSpellID
        elseif energy >= shredCost then
            recommendedSpellID = shredSpellID
        elseif isMangleTalented and energy >= mangleCost and timeToNextTick > 1.0 then
            recommendedSpellID = mangleSpellID
        elseif timeToNextTick > maxWaitTime then
            recommendedSpellID = catFormSpellID
        else
            -- We have more than 22 energy, want to shred, but don't have enough yet and can't shift. We wait.
            recommendedSpellID = shredSpellID
            
        end
        
        -- End of Cycle Fallback
    elseif not ripNext and (energy < (mangleCost - 20) or not waitToMangle) then
        recommendedSpellID = catFormSpellID
    elseif timeToNextTick > maxWaitTime then
        recommendedSpellID = catFormSpellID
    else
        -- Absolute baseline fallback wait
        recommendedSpellID = shredSpellID
        
    end
    
    
    -- 9. Send the recommendation to WeakAuras
    if recommendedSpellID then
        local recommendedIcon = GetSpellTexture(recommendedSpellID)
        local spellName = spellNames[recommendedSpellID]
        local waitText = ""
        if not omenProc and spellCosts[recommendedSpellID] > energy then
            waitText = "WAIT TICK" 
        end
        WA_Feral_Helper_Icon = recommendedIcon
        WA_Feral_Helper_Spell_Name = spellName
        WA_Feral_Helper_Wait_Text = waitText
        return true
    end
    
    -- Fallback/Hide
    WA_Feral_Helper_Icon = nil
    WA_Feral_Helper_Spell_Name = ""
    WA_Feral_Helper_Wait_Text = ""
    return false
end
