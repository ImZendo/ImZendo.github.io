-- =====================================================
-- WORLD SEARCH - MINIMAL TEST UI
-- =====================================================

print("^2[WorldSearch]^7 *** OBJECT STATUS UI SCRIPT STARTING ***")

-- Minimal UI object
local ObjectStatusUI = {
    isVisible = false,
    currentObject = nil
}

-- Simple show function
function ObjectStatusUI.Show(objectData)
    print("^2[WorldSearch]^7 ObjectStatusUI.Show called!")
    ObjectStatusUI.isVisible = true
    ObjectStatusUI.currentObject = objectData
end

-- Simple hide function  
function ObjectStatusUI.Hide()
    print("^2[WorldSearch]^7 ObjectStatusUI.Hide called!")
    ObjectStatusUI.isVisible = false
    ObjectStatusUI.currentObject = nil
end

-- Update function
function ObjectStatusUI.UpdateStatus(searched)
    print("^2[WorldSearch]^7 ObjectStatusUI.UpdateStatus called:", searched)
end

-- Export immediately
_G.ObjectStatusUI = ObjectStatusUI

print("^2[WorldSearch]^7 *** OBJECT STATUS UI EXPORTED TO GLOBAL ***")

-- Show object status UI
function ObjectStatusUI.Show(objectData)
    print("^6[WorldSearch DEBUG]^7 ObjectStatusUI.Show called")
    if not objectData then 
        print("^1[WorldSearch DEBUG]^7 No objectData provided to Show")
        return 
    end
    
    ObjectStatusUI.currentObject = {
        name = objectData.config and objectData.config.name or "Unknown Object",
        prompt = objectData.config and objectData.config.prompt or "Press E to search",
        searched = objectData.searched or false,
        searchable = not (objectData.searched or false)
    }
    
    ObjectStatusUI.isVisible = true
    print("^2[WorldSearch DEBUG]^7 ObjectStatusUI shown for:", ObjectStatusUI.currentObject.name)
end

-- Hide object status UI
function ObjectStatusUI.Hide()
    print("^6[WorldSearch DEBUG]^7 ObjectStatusUI.Hide called")
    ObjectStatusUI.isVisible = false
    ObjectStatusUI.currentObject = nil
end

-- Update object status (for when object becomes searched)
function ObjectStatusUI.UpdateStatus(searched)
    print("^6[WorldSearch DEBUG]^7 ObjectStatusUI.UpdateStatus called, searched:", searched)
    if ObjectStatusUI.currentObject then
        ObjectStatusUI.currentObject.searched = searched
        ObjectStatusUI.currentObject.searchable = not searched
    end
end

-- Draw the object status UI (simplified)
function ObjectStatusUI.Draw()
    if not ObjectStatusUI.isVisible or not ObjectStatusUI.currentObject then
        return
    end
    
    local pos = UI_CONFIG.position
    local size = UI_CONFIG.size
    local colors = UI_CONFIG.colors
    local alpha = ObjectStatusUI.alpha
    
    -- Determine status colors
    local statusColor = ObjectStatusUI.currentObject.searched and colors.searched or colors.available
    local statusText = ObjectStatusUI.currentObject.searched and "SEARCHED" or "AVAILABLE"
    local objectName = ObjectStatusUI.currentObject.name or "Unknown Object"
    
    -- Simple background
    DrawRect(pos.x, pos.y, size.width, size.height, 
        colors.background.r, colors.background.g, colors.background.b, colors.background.a)
    
    -- Status indicator bar (top)
    DrawRect(pos.x, pos.y - size.height/2 + 0.005, size.width, 0.005, 
        statusColor.r, statusColor.g, statusColor.b, statusColor.a)
    
    -- Object name (main text)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.4, 0.4)
    SetTextColour(colors.text.r, colors.text.g, colors.text.b, colors.text.a)
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(objectName)
    EndTextCommandDisplayText(pos.x, pos.y - 0.015)
    
    -- Status text
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.3, 0.3)
    SetTextColour(statusColor.r, statusColor.g, statusColor.b, statusColor.a)
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(statusText)
    EndTextCommandDisplayText(pos.x, pos.y + 0.015)
end

-- Render loop
CreateThread(function()
    while true do
        if ObjectStatusUI.isVisible then
            ObjectStatusUI.Draw()
        end
        Wait(0)
    end
end)

-- Export the UI system immediately
_G.ObjectStatusUI = ObjectStatusUI

-- Debug: Confirm UI system loaded
print("^2[WorldSearch]^7 Custom Object Status UI system loaded and ready")