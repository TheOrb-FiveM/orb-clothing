-- ═══════════════════════════════════════════════════════════════════════
--                          LOCALIZATION HELPER
-- ═══════════════════════════════════════════════════════════════════════
-- Resolves a translation key against the active language (Config.Language),
-- falling back to English for any missing key. Shared so both client and
-- server can call L(). The translation tables live in locales/*.lua and are
-- escrow_ignore'd so customers can add/edit languages without touching code.

local function activeLang()
    return (Config and Config.Language) or 'en'
end

-- L('key')           → returns the translated string (English fallback, then the raw key)
-- L('key', a, b, …)  → string.format the translation with the given args
function L(key, ...)
    local lang = activeLang()
    local dict = (Locales and Locales[lang]) or {}
    local str = dict[key]

    if str == nil and Locales and Locales['en'] then
        str = Locales['en'][key]
    end
    if str == nil then
        str = key
    end

    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, str, ...)
        if ok then return formatted end
    end

    return str
end

-- Full active dictionary (English base + active language overrides), used to
-- hand the NUI a single flat table of strings it can translate against.
function GetLocaleTable()
    local merged = {}
    if Locales and Locales['en'] then
        for k, v in pairs(Locales['en']) do merged[k] = v end
    end
    local lang = activeLang()
    if lang ~= 'en' and Locales and Locales[lang] then
        for k, v in pairs(Locales[lang]) do merged[k] = v end
    end
    return merged
end
