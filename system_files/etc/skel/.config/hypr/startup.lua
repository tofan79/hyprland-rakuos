-- ═══════════════════════════════════════════
-- Autostart (UWSM-aware)
-- ═══════════════════════════════════════════

hl.on("hyprland.start", function()
    -- Import env for systemd (via uwsm, this is handled automatically)
    -- Only needed for non-UWSM sessions
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd --all")

    -- GNOME keyring (start early for apps that need secrets)
    hl.exec_cmd("uwsm app -- gnome-keyring-daemon --start --components=secrets,pkcs11")

    -- Set cursor theme
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")

    -- Dark mode for GTK
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark")

    -- Portal services (for Flatpak, file dialogs, etc.)
    hl.exec_cmd("uwsm app -- /usr/lib/xdg-desktop-portal-hyprland")
    hl.exec_cmd("uwsm app -- /usr/lib/xdg-desktop-portal-gtk")
    hl.exec_cmd("sleep 1 && uwsm app -- /usr/lib/xdg-desktop-portal")

    -- Clipboard history
    hl.exec_cmd("wl-paste --watch cliphist store")

    -- Noctalia shell
    hl.exec_cmd("noctalia")
end)
