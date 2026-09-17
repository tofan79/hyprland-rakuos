-- Look and feel configuration

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        extend_border_grab_area = 10,
        resize_on_border = true,
        allow_tearing = true,
    },
    group = {
        groupbar = {
            font_family               = "JetBrains Mono NF",
            font_size                 = 10,
            gradients                 = true,
            gradient_round_only_edges = false,
            gradient_rounding         = 5,
            height                    = 18,
            indicator_height          = 0,
            gaps_in                   = 3,
            gaps_out                  = 3,
        },
    },
    decoration = {
        dim_special = 0.3,
        rounding = 12,
        active_opacity = 0.9,
        inactive_opacity = 0.7,
        fullscreen_opacity = 1.0,
        blur = {
            enabled = true,
            size = 3,
            passes = 2,
            special = true,
            new_optimizations = true,
            ignore_opacity = true,
            xray = true,
        },
        shadow = {
            enabled = true,
            range = 30,
            render_power = 3,
            color = "0x66000000",
        },
    },
})
