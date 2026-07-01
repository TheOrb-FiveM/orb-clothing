-- ═══════════════════════════════════════════════════════════════════════
--                       SERVER LOAD - APPEARANCE LOADER
-- ═══════════════════════════════════════════════════════════════════════

lib.callback.register('orb-clothing:server:loadAppearance', function(source)
    local identifier = Bridge.GetIdentifier(source)
    if not identifier then return nil end

    local result = MySQL.scalar.await(
        'SELECT appearance FROM character_appearance WHERE identifier = ?',
        { identifier }
    )

    if result then
        local data = json.decode(result)

        -- Broadcast ped scale to other players via state bag
        if data and data.sliders and data.sliders['bodyHeight'] then
            local scale = 0.85 + (data.sliders['bodyHeight'] / 100.0 * 0.30)
            local player = Player(source)
            if player then
                player.state:set('orb-clothing:scale', scale, true)
            end
        end

        return data
    end

    return nil
end)
