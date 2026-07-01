-- ═══════════════════════════════════════════════════════════════════════
--                       ORB-CLOTHING DATABASE SCHEMA
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `character_appearance` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `appearance` LONGTEXT DEFAULT NULL,
    `hair` LONGTEXT DEFAULT NULL,
    `clothing` LONGTEXT DEFAULT NULL,
    `props` LONGTEXT DEFAULT NULL,
    `tattoos` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`),
    KEY `idx_identifier` (`identifier`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Saved outfits (clothing + props + accessories snapshots). Auto-created on
-- resource start by server/outfits.lua — this file is only for manual imports.
CREATE TABLE IF NOT EXISTS `orb_clothing_outfits` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_owner_name` (`identifier`, `name`),
    KEY `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
