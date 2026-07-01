-- ═══════════════════════════════════════════════════════════════════════
--                        VALIDATION UTILITIES
-- ═══════════════════════════════════════════════════════════════════════

Validation = {}

function Validation.Clamp(value, min, max)
    local num = tonumber(value)
    if not num then return min end
    return math.max(min, math.min(num, max))
end

function Validation.ParentIndex(value)
    return Validation.Clamp(value, 0, 45)
end

function Validation.BlendValue(value)
    return Validation.Clamp(value, 0.0, 1.0)
end

function Validation.FaceFeature(value)
    return Validation.Clamp(value, -1.0, 1.0)
end

function Validation.HairStyle(value, max)
    max = max or 100
    return Validation.Clamp(value, 0, max)
end

function Validation.HairColor(value)
    return Validation.Clamp(value, 0, 63)
end

function Validation.EyeColor(value)
    return Validation.Clamp(value, 0, 31)
end

function Validation.OverlayVariation(value, max)
    max = max or 255
    return Validation.Clamp(value, 0, max)
end

function Validation.OverlayOpacity(value)
    return Validation.Clamp(value, 0.0, 1.0)
end

function Validation.OverlayColor(value)
    return Validation.Clamp(value, 0, 63)
end

function Validation.ClothingDrawable(value, max)
    max = max or 500
    return Validation.Clamp(value, -1, max)
end

function Validation.ClothingTexture(value, max)
    max = max or 500
    return Validation.Clamp(value, 0, max)
end

function Validation.PropDrawable(value, max)
    max = max or 500
    return Validation.Clamp(value, -1, max)
end

function Validation.PropTexture(value, max)
    max = max or 500
    return Validation.Clamp(value, 0, max)
end
