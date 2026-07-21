

function()
    -- Hide the aura instantly if we are not in Cat Form (Form index 3)
    local _, activeForm, _, _ = GetShapeshiftFormInfo(3)
    if not activeForm then
        WA_Feral_Helper_Icon = nil
        return true  -- Returning true in the UNtrigger means "Yes, hide it"
    end
    
    -- Keep showing if we are still in Cat Form
    return false
end

