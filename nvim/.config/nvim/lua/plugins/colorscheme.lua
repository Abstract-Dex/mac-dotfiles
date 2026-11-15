-- Catppuccin Mocha, one step darker — matches the Ghostty + T3 Code "Catppuccin Midnight" theme.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "mocha",
      color_overrides = {
        mocha = {
          base = "#16161f", -- editor background (same as Ghostty background)
          mantle = "#111119", -- sidebars, statusline, floats
          crust = "#0f0f17", -- borders, darkest bits
          text = "#dfe5f7", -- brighter text for readability
          subtext1 = "#c9d0e8",
          subtext0 = "#b4bcd6",
          surface0 = "#24243a", -- cursor line, selection-ish
          surface1 = "#34344c",
          surface2 = "#4a4a66",
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin" },
  },
}
