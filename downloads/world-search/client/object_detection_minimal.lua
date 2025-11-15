-- =====================================================
-- WORLD SEARCH - OBJECT DETECTION SYSTEM (MINIMAL TEST)
-- =====================================================

print("^6[WorldSearch DEBUG]^7 MINIMAL object detection script executing...")

-- Test if this basic script loads
WorldSearchObjectDetection = {
    test = true
}

_G.WorldSearchObjectDetection = WorldSearchObjectDetection

print("^2[WorldSearch DEBUG]^7 MINIMAL object detection system loaded successfully!")

-- Simple export functions
function WorldSearchObjectDetection.GetCurrentObject()
    return nil
end

function WorldSearchObjectDetection.GetNearbyObjects()
    return {}
end

-- Register exports
exports('GetCurrentObject', WorldSearchObjectDetection.GetCurrentObject)
exports('GetNearbyObjects', WorldSearchObjectDetection.GetNearbyObjects)

print("^2[WorldSearch DEBUG]^7 MINIMAL exports registered!")