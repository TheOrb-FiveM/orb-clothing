fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'orb-clothing'
author 'TheOrb Scripts'
description 'Advanced Character Creator & Clothing System'
version '1.5.0'

dependencies {
    'ox_lib',
    'oxmysql',
}

-- Declared so other resources with `dependencies { 'qb-clothing' }` (qb-houses,
-- qb-apartments, stock qb-core ecosystem) start correctly with orb-clothing as
-- the replacement. Also satisfies ESX skinchanger/esx_skin checks.
provides {
    'qb-clothing',
    'skinchanger',
    'esx_skin',
}

shared_scripts {
    '@ox_lib/init.lua',
    'bridge/_detect.lua',
    'config.lua',
    -- Localization: translation tables first, then the L() helper that reads them
    'locales/en.lua',
    'locales/es.lua',
    'shared/locale.lua',
    'shared/tattoo_data.lua',
    'shared/ped_models.lua',
}

client_scripts {
    -- Bridge (loaded first)
    'bridge/client/framework.lua',
    'bridge/client/hud.lua',

    -- Utils (needed by other modules)
    'client/utils/validation.lua',
    'client/utils/data_cache.lua',

    -- Core systems
    'client/systems/appearance.lua',
    'client/systems/hair.lua',
    'client/systems/clothes.lua',
    'client/systems/tattoos.lua',
    'client/systems/outfits.lua',
    'client/systems/camera.lua',

    -- Store interaction layer
    'client/store/blips.lua',
    'client/store/zones.lua',
    'client/store/interaction.lua',

    -- Admin tools (loaded before main.lua so MergeAdminStores is available)
    'client/admin/manager.lua',
    'client/admin/nui_admin.lua',

    -- UI bridge
    'client/ui/nui_callbacks.lua',

    -- Main entry point (loads last)
    'client/main.lua',

    -- Compatibility shims (opt-in via Config.CompatMode, loaded last so
    -- they can early-return without affecting anything else if disabled)
    'client/compat/qb_clothing.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    -- Bridge (loaded first)
    'bridge/server/framework.lua',

    -- Server modules
    'server/store/validation.lua',
    'server/admin/storage.lua',
    'server/admin/commands.lua',
    'server/main.lua',
    'server/load.lua',
    'server/outfits.lua',

    -- Migration tool: /migrateclothing, /migrateqs, /migrateqb + Config.AutoImport
    -- (imports looks/outfits from qs-appearance or qb-clothing)
    'server/migrate_qs.lua',

    -- Compatibility shims (opt-in via Config.CompatMode)
    'server/compat/qb_clothing.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/config_ui.js',
    'html/assets/*.svg',
    'html/assets/*.png',
    -- Local image host for add-on clothing packs. Populated by the
    -- orb-clothing_companion importer (or manually), served via NUI
    -- at relative path `assets/clothing_images/*.png`. Empty by default
    -- so there is no resource-start hitch until the customer adds files.
    -- Vanilla drawables still stream from the jsDelivr CDN unless the
    -- customer explicitly opts into local mode in config_ui.js.
    'html/assets/clothing_images/**/*.png',
}

escrow_ignore {
    'config.lua',
    'shared/tattoo_data.lua',
    'shared/ped_models.lua',
    'data/**',
    'database.sql',
    'html/config_ui.js',
    'html/assets/*.svg',
    'html/assets/*.png',
    'locales/*.lua',
}
