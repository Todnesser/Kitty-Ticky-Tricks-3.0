function()
    local spell = WA_Feral_Helper_Spell_Name or ""
    local wait = WA_Feral_Helper_Wait_Text or ""
    
    if wait ~= "" then
        -- Return both: E.g., "Shred\n|cFFFF0000WAIT TICK|r" (colored red)
        return string.format("%s\n|cFFFF0000%s|r", spell, wait)
    else
        return spell
    end
end

