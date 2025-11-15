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
print("^2[WorldSearch]^7 Testing global access: ObjectStatusUI =", ObjectStatusUI)
print("^2[WorldSearch]^7 Testing global access: _G.ObjectStatusUI =", _G.ObjectStatusUI)