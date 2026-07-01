/**
 * ORB CLOTHING — UI CONFIGURATION
 *
 * Edit these values to customize the in-game UI appearance.
 * Changes take effect on resource restart (no rebuild needed).
 *
 * Color format: hex (#RRGGBB) or rgb (r, g, b)
 * Font format: Any Google Font or system font name
 */

const UI_CONFIG = {
    // ─── Clothing images CDN ──────────────────────────────────────
    // Default CDN ships with vanilla GTA drawables only.
    //
    // For add-on clothing packs, pick ONE path:
    //
    //   PATH A — LOCAL (recommended): drop PNG files into
    //     orb-clothing/html/assets/clothing_images/ and the creator
    //     serves them directly — no CDN, no hosting.
    //     Uncomment the two "local" lines below (and comment the two
    //     default lines), then restart orb-clothing.
    //
    //     The free orb-clothing_companion package automates the capture
    //     (/screenshot) and the file copying (orbclothing_import).
    //
    //   PATH B — ADVANCED: fork the upstream CDN repo, generate WebP
    //     files yourself, upload to jsDelivr / R2 / own host, override
    //     cdnBase below. See orb-clothing_companion/advanced/README.md.
    //
    // Format: {cdnBase}/clothing_images/{model}-{prefix}-{index}.{imageExtension}
    cdnBase:        'https://cdn.jsdelivr.net/gh/TheOrb-FiveM/images-cdn@main/clothing',
    imageExtension: 'webp',
    // cdnBase:        'assets',
    // imageExtension: 'png',
    //
    //   PATH C — GREENSCREEN (fully automated): install orb-greenscreen,
    //     run /screenshot in-game, restart orb-greenscreen, done.
    //     orb-clothing reads images directly from orb-greenscreen's output.
    //     Zero renaming, zero copying, zero hosting.
    //     Set to the resource name to enable; null/'' to use the CDN above.
    greenscreenResource: null,

    // ─── Primary accent color (buttons, active states, glows) ───
    primaryColor: '#00f0ff',        // Cyan (TheOrb default)
    primaryMid: '#00c4d4',          // Mid tone for gradients
    primaryDark: '#007a85',         // Dark tone for gradients

    // ─── Danger color (delete buttons, error states) ───
    dangerColor: '#ff4444',

    // ─── Background ───
    panelBg: 'rgba(19, 19, 19, 0.92)',      // Main panel background
    surfaceBg: 'rgba(255, 255, 255, 0.05)',  // Cards, inputs, tabs
    surfaceHover: 'rgba(255, 255, 255, 0.1)', // Hover state on surfaces
    surfaceActive: 'rgba(255, 255, 255, 0.15)', // Active/pressed surfaces

    // ─── Text ───
    textPrimary: '#ffffff',
    textSecondary: 'rgba(255, 255, 255, 0.6)',
    textMuted: 'rgba(255, 255, 255, 0.35)',
    textDisabled: 'rgba(255, 255, 255, 0.2)',

    // ─── Borders ───
    borderDefault: 'rgba(255, 255, 255, 0.15)',
    borderSubtle: 'rgba(255, 255, 255, 0.08)',
    borderHover: 'rgba(255, 255, 255, 0.25)',

    // ─── Fonts ───
    fontHeadline: "'Space Grotesk', sans-serif",
    fontBody: "'Manrope', sans-serif",

    // ─── Left gradient overlay (fades game world into panel) ───
    gradientBg: 'rgba(19, 19, 19, 0.95)',
};

// ──────────────────────────────────────────────────────────────
//  Apply config as CSS custom properties (do not edit below)
// ──────────────────────────────────────────────────────────────

(function applyUIConfig() {
    const c = UI_CONFIG;
    const root = document.documentElement.style;

    // Expose CDN base globally so script.js can read it.
    // Strip trailing slash so URL concatenation is consistent.
    window.ORB_CDN_BASE = (c.cdnBase || '').replace(/\/+$/, '');

    // Expose image extension so script.js can build filenames for either
    // the default WebP CDN or the PNG output of orb-clothing_companion.
    window.ORB_IMAGE_EXT = (c.imageExtension || 'webp').replace(/^\./, '');

    // Greenscreen mode: read images directly from orb-greenscreen's output
    // folder via cfx-nui protocol. Set to resource name or null to disable.
    window.ORB_GREENSCREEN_RESOURCE = c.greenscreenResource || null;

    // Parse hex to r,g,b for rgba() usage
    function hexToRgb(hex) {
        hex = hex.replace('#', '');
        return [
            parseInt(hex.substring(0, 2), 16),
            parseInt(hex.substring(2, 4), 16),
            parseInt(hex.substring(4, 6), 16)
        ].join(', ');
    }

    // Colors
    root.setProperty('--primary', c.primaryColor);
    root.setProperty('--primary-rgb', hexToRgb(c.primaryColor));
    root.setProperty('--primary-mid', c.primaryMid);
    root.setProperty('--primary-dark', c.primaryDark);
    root.setProperty('--danger', c.dangerColor);
    root.setProperty('--danger-rgb', hexToRgb(c.dangerColor));

    // Backgrounds
    root.setProperty('--panel-bg', c.panelBg);
    root.setProperty('--surface-bg', c.surfaceBg);
    root.setProperty('--surface-hover', c.surfaceHover);
    root.setProperty('--surface-active', c.surfaceActive);

    // Text
    root.setProperty('--text-primary', c.textPrimary);
    root.setProperty('--text-secondary', c.textSecondary);
    root.setProperty('--text-muted', c.textMuted);
    root.setProperty('--text-disabled', c.textDisabled);

    // Borders
    root.setProperty('--border-default', c.borderDefault);
    root.setProperty('--border-subtle', c.borderSubtle);
    root.setProperty('--border-hover', c.borderHover);

    // Fonts
    root.setProperty('--font-headline', c.fontHeadline);
    root.setProperty('--font-body', c.fontBody);

    // Gradient
    root.setProperty('--gradient-bg', c.gradientBg);
})();
