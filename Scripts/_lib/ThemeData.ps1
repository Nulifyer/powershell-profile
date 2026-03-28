# Shared theme data for theme.ps1 and wallpaper.ps1
# Keys: bg (terminal background), os (muted/UI), closer (prompt char), pink (path), lavender (git), blue (user@host)

$script:palettes = [ordered]@{
    catppuccin_mocha      = @{ bg = "#1E1E2E"; os = "#ACB0BE"; closer = "p:os"; pink = "#F5C2E7"; lavender = "#B4BEFE"; blue = "#89B4FA" }
    catppuccin_macchiato  = @{ bg = "#24273A"; os = "#ACB0BE"; closer = "p:os"; pink = "#F5BDE6"; lavender = "#B7BDF8"; blue = "#8AADF4" }
    catppuccin_frappe     = @{ bg = "#303446"; os = "#ACB0BE"; closer = "p:os"; pink = "#F4B8E4"; lavender = "#BABBF1"; blue = "#8CAAEE" }
    catppuccin_latte      = @{ bg = "#EFF1F5"; os = "#ACB0BE"; closer = "p:os"; pink = "#ea76cb"; lavender = "#7287FD"; blue = "#1e66f5" }
    gruvbox               = @{ bg = "#282828"; os = "#A89984"; closer = "p:os"; pink = "#E78A4E"; lavender = "#A9B665"; blue = "#D8A657" }
    gruvbox_light         = @{ bg = "#FBF1C7"; os = "#7C6F64"; closer = "p:os"; pink = "#AF3A03"; lavender = "#79740E"; blue = "#B57614" }
    everforest            = @{ bg = "#2D353B"; os = "#9DA9A0"; closer = "p:os"; pink = "#E69875"; lavender = "#A7C080"; blue = "#DBBC7F" }
    everforest_light      = @{ bg = "#FDF6E3"; os = "#829181"; closer = "p:os"; pink = "#E67E80"; lavender = "#8DA101"; blue = "#DFA000" }
    tokyonight            = @{ bg = "#1A1B26"; os = "#565F89"; closer = "p:os"; pink = "#FF966C"; lavender = "#9ECE6A"; blue = "#7AA2F7" }
    tokyonight_light      = @{ bg = "#D5D6DB"; os = "#6172B0"; closer = "p:os"; pink = "#8C4351"; lavender = "#485E30"; blue = "#34548A" }
    nord                  = @{ bg = "#2E3440"; os = "#D8DEE9"; closer = "p:os"; pink = "#B48EAD"; lavender = "#A3BE8C"; blue = "#88C0D0" }
    dracula               = @{ bg = "#282A36"; os = "#6272A4"; closer = "p:os"; pink = "#FF79C6"; lavender = "#50FA7B"; blue = "#F1FA8C" }
    rose_pine             = @{ bg = "#191724"; os = "#908CAA"; closer = "p:os"; pink = "#EB6F92"; lavender = "#F6C177"; blue = "#9CCFD8" }
    rose_pine_dawn        = @{ bg = "#FAF4ED"; os = "#797593"; closer = "p:os"; pink = "#B4637A"; lavender = "#EA9D34"; blue = "#56949F" }
    kanagawa              = @{ bg = "#1F1F28"; os = "#727169"; closer = "p:os"; pink = "#FFA066"; lavender = "#98BB6C"; blue = "#E6C384" }
    solarized             = @{ bg = "#002B36"; os = "#93A1A1"; closer = "p:os"; pink = "#CB4B16"; lavender = "#859900"; blue = "#268BD2" }
    onedark               = @{ bg = "#282C34"; os = "#ABB2BF"; closer = "p:os"; pink = "#E86671"; lavender = "#98C379"; blue = "#E5C07B" }
    lume                  = @{ bg = "#12101E"; os = "#8A8498"; closer = "p:os"; pink = "#D0A0B8"; lavender = "#A0D4A8"; blue = "#C4B080" }
    monokai               = @{ bg = "#272822"; os = "#A59F85"; closer = "p:os"; pink = "#F92672"; lavender = "#A6E22E"; blue = "#FD971F" }
    ayu_dark              = @{ bg = "#0B0E14"; os = "#565B66"; closer = "p:os"; pink = "#FF8F40"; lavender = "#AAD94C"; blue = "#E6B450" }
    ayu_mirage            = @{ bg = "#1F2430"; os = "#707A8C"; closer = "p:os"; pink = "#FFAD66"; lavender = "#D5FF80"; blue = "#FFD173" }
    vesper                = @{ bg = "#101010"; os = "#8B8B8B"; closer = "p:os"; pink = "#FFC799"; lavender = "#99FFE4"; blue = "#FF8080" }
    poimandres            = @{ bg = "#1B1E28"; os = "#A6ACCD"; closer = "p:os"; pink = "#D0679D"; lavender = "#5DE4C7"; blue = "#FFFAC2" }
    nightfox              = @{ bg = "#192330"; os = "#738091"; closer = "p:os"; pink = "#F4A261"; lavender = "#81B29A"; blue = "#DBC074" }
    carbonfox             = @{ bg = "#161616"; os = "#7B7C7E"; closer = "p:os"; pink = "#EE5396"; lavender = "#25BE6A"; blue = "#33B1FF" }
    mellow                = @{ bg = "#161617"; os = "#757581"; closer = "p:os"; pink = "#F5A191"; lavender = "#90B99F"; blue = "#E6B99D" }
    moonfly               = @{ bg = "#080808"; os = "#808080"; closer = "p:os"; pink = "#FF5189"; lavender = "#79DAC8"; blue = "#E3C78A" }
    horizon               = @{ bg = "#1C1E26"; os = "#BBBBBB"; closer = "p:os"; pink = "#E95678"; lavender = "#FAB795"; blue = "#29D398" }
    palenight             = @{ bg = "#292D3E"; os = "#A6ACCD"; closer = "p:os"; pink = "#C792EA"; lavender = "#C3E88D"; blue = "#FFCB6B" }
    zenburn               = @{ bg = "#3F3F3F"; os = "#DCDCCC"; closer = "p:os"; pink = "#F0DFAF"; lavender = "#7F9F7F"; blue = "#CC9393" }
}

# Full ANSI 16-color schemes for terminal emulators and VS Code
$script:wtSchemes = @{
    catppuccin_mocha = @{
        name = "Catppuccin Mocha"; background = "#1E1E2E"; foreground = "#CDD6F4"; cursorColor = "#F5E0DC"; selectionBackground = "#585B70"
        black = "#45475A"; red = "#F38BA8"; green = "#A6E3A1"; yellow = "#F9E2AF"; blue = "#89B4FA"; purple = "#F5C2E7"; cyan = "#94E2D5"; white = "#BAC2DE"
        brightBlack = "#585B70"; brightRed = "#F38BA8"; brightGreen = "#A6E3A1"; brightYellow = "#F9E2AF"; brightBlue = "#89B4FA"; brightPurple = "#F5C2E7"; brightCyan = "#94E2D5"; brightWhite = "#A6ADC8"
    }
    catppuccin_macchiato = @{
        name = "Catppuccin Macchiato"; background = "#24273A"; foreground = "#CAD3F5"; cursorColor = "#F4DBD6"; selectionBackground = "#5B6078"
        black = "#494D64"; red = "#ED8796"; green = "#A6DA95"; yellow = "#EED49F"; blue = "#8AADF4"; purple = "#F5BDE6"; cyan = "#8BD5CA"; white = "#B8C0E0"
        brightBlack = "#5B6078"; brightRed = "#ED8796"; brightGreen = "#A6DA95"; brightYellow = "#EED49F"; brightBlue = "#8AADF4"; brightPurple = "#F5BDE6"; brightCyan = "#8BD5CA"; brightWhite = "#A5ADCB"
    }
    catppuccin_frappe = @{
        name = "Catppuccin Frappe"; background = "#303446"; foreground = "#C6D0F5"; cursorColor = "#F2D5CF"; selectionBackground = "#626880"
        black = "#51576D"; red = "#E78284"; green = "#A6D189"; yellow = "#E5C890"; blue = "#8CAAEE"; purple = "#F4B8E4"; cyan = "#81C8BE"; white = "#B5BFE2"
        brightBlack = "#626880"; brightRed = "#E78284"; brightGreen = "#A6D189"; brightYellow = "#E5C890"; brightBlue = "#8CAAEE"; brightPurple = "#F4B8E4"; brightCyan = "#81C8BE"; brightWhite = "#A5ADCE"
    }
    catppuccin_latte = @{
        name = "Catppuccin Latte"; background = "#EFF1F5"; foreground = "#4C4F69"; cursorColor = "#DC8A78"; selectionBackground = "#ACB0BE"
        black = "#5C5F77"; red = "#D20F39"; green = "#40A02B"; yellow = "#DF8E1D"; blue = "#1E66F5"; purple = "#EA76CB"; cyan = "#179299"; white = "#ACB0BE"
        brightBlack = "#6C6F85"; brightRed = "#D20F39"; brightGreen = "#40A02B"; brightYellow = "#DF8E1D"; brightBlue = "#1E66F5"; brightPurple = "#EA76CB"; brightCyan = "#179299"; brightWhite = "#BCC0CC"
    }
    gruvbox = @{
        name = "Gruvbox Dark"; background = "#1D2021"; foreground = "#DDC7A1"; cursorColor = "#DDC7A1"; selectionBackground = "#3C3836"
        black = "#141617"; red = "#EA6962"; green = "#A9B665"; yellow = "#D8A657"; blue = "#7DAEA3"; purple = "#D3869B"; cyan = "#89B482"; white = "#DDC7A1"
        brightBlack = "#928374"; brightRed = "#E3746F"; brightGreen = "#ABB578"; brightYellow = "#D6AC67"; brightBlue = "#8CB0A8"; brightPurple = "#D699A9"; brightCyan = "#98B593"; brightWhite = "#DCCDB5"
    }
    gruvbox_light = @{
        name = "Gruvbox Light"; background = "#FBF1C7"; foreground = "#3C3836"; cursorColor = "#3C3836"; selectionBackground = "#EBDBB2"
        black = "#FBF1C7"; red = "#CC241D"; green = "#98971A"; yellow = "#D79921"; blue = "#458588"; purple = "#B16286"; cyan = "#689D6A"; white = "#7C6F64"
        brightBlack = "#928374"; brightRed = "#9D0006"; brightGreen = "#79740E"; brightYellow = "#B57614"; brightBlue = "#076678"; brightPurple = "#8F3F71"; brightCyan = "#427B58"; brightWhite = "#3C3836"
    }
    everforest = @{
        name = "Everforest Dark"; background = "#2D353B"; foreground = "#D3C6AA"; cursorColor = "#D3C6AA"; selectionBackground = "#475258"
        black = "#343F44"; red = "#E67E80"; green = "#A7C080"; yellow = "#DBBC7F"; blue = "#7FBBB3"; purple = "#D699B6"; cyan = "#83C092"; white = "#D3C6AA"
        brightBlack = "#475258"; brightRed = "#E67E80"; brightGreen = "#A7C080"; brightYellow = "#DBBC7F"; brightBlue = "#7FBBB3"; brightPurple = "#D699B6"; brightCyan = "#83C092"; brightWhite = "#D3C6AA"
    }
    everforest_light = @{
        name = "Everforest Light"; background = "#FDF6E3"; foreground = "#5C6A72"; cursorColor = "#5C6A72"; selectionBackground = "#E6E2CC"
        black = "#F3EAD3"; red = "#F85552"; green = "#8DA101"; yellow = "#DFA000"; blue = "#3A94C5"; purple = "#DF69BA"; cyan = "#35A77C"; white = "#5C6A72"
        brightBlack = "#939B8E"; brightRed = "#F85552"; brightGreen = "#8DA101"; brightYellow = "#DFA000"; brightBlue = "#3A94C5"; brightPurple = "#DF69BA"; brightCyan = "#35A77C"; brightWhite = "#5C6A72"
    }
    tokyonight = @{
        name = "Tokyo Night"; background = "#1A1B26"; foreground = "#C0CAF5"; cursorColor = "#C0CAF5"; selectionBackground = "#33467C"
        black = "#15161E"; red = "#F7768E"; green = "#9ECE6A"; yellow = "#E0AF68"; blue = "#7AA2F7"; purple = "#BB9AF7"; cyan = "#7DCFFF"; white = "#A9B1D6"
        brightBlack = "#565F89"; brightRed = "#F7768E"; brightGreen = "#9ECE6A"; brightYellow = "#E0AF68"; brightBlue = "#7AA2F7"; brightPurple = "#BB9AF7"; brightCyan = "#7DCFFF"; brightWhite = "#C0CAF5"
    }
    tokyonight_light = @{
        name = "Tokyo Night Light"; background = "#D5D6DB"; foreground = "#343B58"; cursorColor = "#343B58"; selectionBackground = "#9699A3"
        black = "#0F0F14"; red = "#8C4351"; green = "#485E30"; yellow = "#8F5E15"; blue = "#34548A"; purple = "#5A4A78"; cyan = "#0F4B6E"; white = "#343B58"
        brightBlack = "#9699A3"; brightRed = "#8C4351"; brightGreen = "#485E30"; brightYellow = "#8F5E15"; brightBlue = "#34548A"; brightPurple = "#5A4A78"; brightCyan = "#0F4B6E"; brightWhite = "#343B58"
    }
    nord = @{
        name = "Nord"; background = "#2E3440"; foreground = "#D8DEE9"; cursorColor = "#D8DEE9"; selectionBackground = "#434C5E"
        black = "#3B4252"; red = "#BF616A"; green = "#A3BE8C"; yellow = "#EBCB8B"; blue = "#81A1C1"; purple = "#B48EAD"; cyan = "#88C0D0"; white = "#E5E9F0"
        brightBlack = "#4C566A"; brightRed = "#BF616A"; brightGreen = "#A3BE8C"; brightYellow = "#EBCB8B"; brightBlue = "#81A1C1"; brightPurple = "#B48EAD"; brightCyan = "#8FBCBB"; brightWhite = "#ECEFF4"
    }
    dracula = @{
        name = "Dracula"; background = "#282A36"; foreground = "#F8F8F2"; cursorColor = "#F8F8F2"; selectionBackground = "#44475A"
        black = "#21222C"; red = "#FF5555"; green = "#50FA7B"; yellow = "#F1FA8C"; blue = "#BD93F9"; purple = "#FF79C6"; cyan = "#8BE9FD"; white = "#F8F8F2"
        brightBlack = "#6272A4"; brightRed = "#FF6E6E"; brightGreen = "#69FF94"; brightYellow = "#FFFFA5"; brightBlue = "#D6ACFF"; brightPurple = "#FF92DF"; brightCyan = "#A4FFFF"; brightWhite = "#FFFFFF"
    }
    rose_pine = @{
        name = "Rose Pine"; background = "#191724"; foreground = "#E0DEF4"; cursorColor = "#E0DEF4"; selectionBackground = "#403D52"
        black = "#26233A"; red = "#EB6F92"; green = "#9CCFD8"; yellow = "#F6C177"; blue = "#31748F"; purple = "#C4A7E7"; cyan = "#9CCFD8"; white = "#E0DEF4"
        brightBlack = "#6E6A86"; brightRed = "#EB6F92"; brightGreen = "#9CCFD8"; brightYellow = "#F6C177"; brightBlue = "#31748F"; brightPurple = "#C4A7E7"; brightCyan = "#9CCFD8"; brightWhite = "#E0DEF4"
    }
    rose_pine_dawn = @{
        name = "Rose Pine Dawn"; background = "#FAF4ED"; foreground = "#575279"; cursorColor = "#575279"; selectionBackground = "#DFDAD9"
        black = "#F2E9E1"; red = "#B4637A"; green = "#56949F"; yellow = "#EA9D34"; blue = "#286983"; purple = "#907AA9"; cyan = "#56949F"; white = "#575279"
        brightBlack = "#9893A5"; brightRed = "#B4637A"; brightGreen = "#56949F"; brightYellow = "#EA9D34"; brightBlue = "#286983"; brightPurple = "#907AA9"; brightCyan = "#56949F"; brightWhite = "#575279"
    }
    kanagawa = @{
        name = "Kanagawa"; background = "#1F1F28"; foreground = "#DCD7BA"; cursorColor = "#DCD7BA"; selectionBackground = "#2D4F67"
        black = "#16161D"; red = "#C34043"; green = "#76946A"; yellow = "#C0A36E"; blue = "#7E9CD8"; purple = "#957FB8"; cyan = "#6A9589"; white = "#C8C093"
        brightBlack = "#727169"; brightRed = "#E82424"; brightGreen = "#98BB6C"; brightYellow = "#E6C384"; brightBlue = "#7FB4CA"; brightPurple = "#938AA9"; brightCyan = "#7AA89F"; brightWhite = "#DCD7BA"
    }
    solarized = @{
        name = "Solarized Dark"; background = "#002B36"; foreground = "#839496"; cursorColor = "#839496"; selectionBackground = "#073642"
        black = "#073642"; red = "#DC322F"; green = "#859900"; yellow = "#B58900"; blue = "#268BD2"; purple = "#D33682"; cyan = "#2AA198"; white = "#EEE8D5"
        brightBlack = "#586E75"; brightRed = "#CB4B16"; brightGreen = "#586E75"; brightYellow = "#657B83"; brightBlue = "#839496"; brightPurple = "#6C71C4"; brightCyan = "#93A1A1"; brightWhite = "#FDF6E3"
    }
    onedark = @{
        name = "One Dark"; background = "#282C34"; foreground = "#ABB2BF"; cursorColor = "#ABB2BF"; selectionBackground = "#3E4451"
        black = "#3F4451"; red = "#E06C75"; green = "#98C379"; yellow = "#E5C07B"; blue = "#61AFEF"; purple = "#C678DD"; cyan = "#56B6C2"; white = "#ABB2BF"
        brightBlack = "#4F5666"; brightRed = "#BE5046"; brightGreen = "#98C379"; brightYellow = "#D19A66"; brightBlue = "#61AFEF"; brightPurple = "#C678DD"; brightCyan = "#56B6C2"; brightWhite = "#ABB2BF"
    }
    lume = @{
        name = "Lume"; background = "#12101E"; foreground = "#D8D0E4"; cursorColor = "#D8D0E4"; selectionBackground = "#1E1A2C"
        black = "#0E0C18"; red = "#C49080"; green = "#A0D4A8"; yellow = "#C4B080"; blue = "#8CC0E0"; purple = "#B8A0E0"; cyan = "#88C0B8"; white = "#D8D0E4"
        brightBlack = "#302C42"; brightRed = "#E8B4A0"; brightGreen = "#A0D4A8"; brightYellow = "#C4B080"; brightBlue = "#8CC0E0"; brightPurple = "#D0A0B8"; brightCyan = "#88C0B8"; brightWhite = "#D8D0E4"
    }
    monokai = @{
        name = "Monokai"; background = "#272822"; foreground = "#F8F8F2"; cursorColor = "#F8F8F2"; selectionBackground = "#49483E"
        black = "#272822"; red = "#F92672"; green = "#A6E22E"; yellow = "#F4BF75"; blue = "#66D9EF"; purple = "#AE81FF"; cyan = "#A1EFE4"; white = "#F8F8F2"
        brightBlack = "#75715E"; brightRed = "#F92672"; brightGreen = "#A6E22E"; brightYellow = "#F4BF75"; brightBlue = "#66D9EF"; brightPurple = "#AE81FF"; brightCyan = "#A1EFE4"; brightWhite = "#F9F8F5"
    }
    ayu_dark = @{
        name = "Ayu Dark"; background = "#10141C"; foreground = "#BFBDB6"; cursorColor = "#E6B450"; selectionBackground = "#273747"
        black = "#0A0E14"; red = "#F07178"; green = "#AAD94C"; yellow = "#E6B450"; blue = "#39BAE6"; purple = "#D2A6FF"; cyan = "#95E6CB"; white = "#BFBDB6"
        brightBlack = "#ACB6BF"; brightRed = "#FF3333"; brightGreen = "#AAD94C"; brightYellow = "#FFB454"; brightBlue = "#59C2FF"; brightPurple = "#D2A6FF"; brightCyan = "#95E6CB"; brightWhite = "#FFFFFF"
    }
    ayu_mirage = @{
        name = "Ayu Mirage"; background = "#242936"; foreground = "#CCCAC2"; cursorColor = "#FFCC66"; selectionBackground = "#33415E"
        black = "#1A1F29"; red = "#F28779"; green = "#D5FF80"; yellow = "#FFCC66"; blue = "#5CCFE6"; purple = "#DFBFFF"; cyan = "#95E6CB"; white = "#CCCAC2"
        brightBlack = "#B8CFE6"; brightRed = "#F28779"; brightGreen = "#D5FF80"; brightYellow = "#FFD173"; brightBlue = "#73D0FF"; brightPurple = "#DFBFFF"; brightCyan = "#95E6CB"; brightWhite = "#FFFFFF"
    }
    vesper = @{
        name = "Vesper"; background = "#101010"; foreground = "#FFFFFF"; cursorColor = "#FFC799"; selectionBackground = "#252525"
        black = "#101010"; red = "#FF8080"; green = "#99FFE4"; yellow = "#FFC799"; blue = "#99FFE4"; purple = "#FFC799"; cyan = "#99FFE4"; white = "#FFFFFF"
        brightBlack = "#8B8B8B"; brightRed = "#FF8080"; brightGreen = "#99FFE4"; brightYellow = "#FFC799"; brightBlue = "#99FFE4"; brightPurple = "#FFC799"; brightCyan = "#99FFE4"; brightWhite = "#FFFFFF"
    }
    poimandres = @{
        name = "Poimandres"; background = "#1B1E28"; foreground = "#E4F0FB"; cursorColor = "#A6ACCD"; selectionBackground = "#303340"
        black = "#171922"; red = "#D0679D"; green = "#5DE4C7"; yellow = "#FFFAC2"; blue = "#89DDFF"; purple = "#ADD7FF"; cyan = "#5FB3A1"; white = "#E4F0FB"
        brightBlack = "#506477"; brightRed = "#FCC5E9"; brightGreen = "#5DE4C7"; brightYellow = "#FFFAC2"; brightBlue = "#89DDFF"; brightPurple = "#ADD7FF"; brightCyan = "#5DE4C7"; brightWhite = "#FFFFFF"
    }
    nightfox = @{
        name = "Nightfox"; background = "#192330"; foreground = "#CDCECF"; cursorColor = "#CDCECF"; selectionBackground = "#2B3B51"
        black = "#393B44"; red = "#C94F6D"; green = "#81B29A"; yellow = "#DBC074"; blue = "#719CD6"; purple = "#9D79D6"; cyan = "#63CDCF"; white = "#DFDFE0"
        brightBlack = "#738091"; brightRed = "#D6616B"; brightGreen = "#58CD8B"; brightYellow = "#EFE0A2"; brightBlue = "#84CEE4"; brightPurple = "#B8A1E3"; brightCyan = "#59F0FF"; brightWhite = "#F2F2F2"
    }
    carbonfox = @{
        name = "Carbonfox"; background = "#161616"; foreground = "#F2F4F8"; cursorColor = "#F2F4F8"; selectionBackground = "#2A2A2A"
        black = "#282828"; red = "#EE5396"; green = "#25BE6A"; yellow = "#08BDBA"; blue = "#78A9FF"; purple = "#BE95FF"; cyan = "#33B1FF"; white = "#DFDFE0"
        brightBlack = "#525253"; brightRed = "#F16DA6"; brightGreen = "#46C880"; brightYellow = "#2DC7C4"; brightBlue = "#8CB6FF"; brightPurple = "#C8A5FF"; brightCyan = "#52BDFF"; brightWhite = "#F2F4F8"
    }
    mellow = @{
        name = "Mellow"; background = "#161617"; foreground = "#C9C7CD"; cursorColor = "#C9C7CD"; selectionBackground = "#2A2A2D"
        black = "#27272A"; red = "#F5A191"; green = "#90B99F"; yellow = "#E6B99D"; blue = "#ACA1CF"; purple = "#E29ECA"; cyan = "#EA83A5"; white = "#C1C0D4"
        brightBlack = "#353539"; brightRed = "#FFAE9F"; brightGreen = "#9DC6AC"; brightYellow = "#F0C5A9"; brightBlue = "#B9AEDA"; brightPurple = "#ECAAD6"; brightCyan = "#F591B2"; brightWhite = "#CAC9DD"
    }
    moonfly = @{
        name = "Moonfly"; background = "#080808"; foreground = "#C6C6C6"; cursorColor = "#C6C6C6"; selectionBackground = "#373C4D"
        black = "#323437"; red = "#FF5D5D"; green = "#85DC85"; yellow = "#E3C78A"; blue = "#80A0FF"; purple = "#CF87E8"; cyan = "#79DAC8"; white = "#C6C6C6"
        brightBlack = "#808080"; brightRed = "#FF5189"; brightGreen = "#8CC85F"; brightYellow = "#E3C78A"; brightBlue = "#74B2FF"; brightPurple = "#AE81FF"; brightCyan = "#36C692"; brightWhite = "#E4E4E4"
    }
    horizon = @{
        name = "Horizon"; background = "#1C1E26"; foreground = "#D5D8DA"; cursorColor = "#D5D8DA"; selectionBackground = "#2E303E"
        black = "#16161C"; red = "#E95678"; green = "#29D398"; yellow = "#FAB795"; blue = "#26BBD9"; purple = "#B877DB"; cyan = "#59E1E3"; white = "#D5D8DA"
        brightBlack = "#BBBBBB"; brightRed = "#EC6A88"; brightGreen = "#3FDAA4"; brightYellow = "#FBC3A7"; brightBlue = "#3FC4DE"; brightPurple = "#F075B5"; brightCyan = "#6BE4E6"; brightWhite = "#FFFFFF"
    }
    palenight = @{
        name = "Palenight"; background = "#292D3E"; foreground = "#A6ACCD"; cursorColor = "#FFCC00"; selectionBackground = "#3C435E"
        black = "#292D3E"; red = "#FF5370"; green = "#C3E88D"; yellow = "#FFCB6B"; blue = "#82AAFF"; purple = "#C792EA"; cyan = "#89DDFF"; white = "#A6ACCD"
        brightBlack = "#676E95"; brightRed = "#FF5370"; brightGreen = "#C3E88D"; brightYellow = "#FFCB6B"; brightBlue = "#82AAFF"; brightPurple = "#C792EA"; brightCyan = "#89DDFF"; brightWhite = "#FFFFFF"
    }
    zenburn = @{
        name = "Zenburn"; background = "#3F3F3F"; foreground = "#DCDCCC"; cursorColor = "#8FAF9F"; selectionBackground = "#2F2F2F"
        black = "#3F3F3F"; red = "#CC9393"; green = "#7F9F7F"; yellow = "#F0DFAF"; blue = "#8CD0D3"; purple = "#DCA3A3"; cyan = "#93B3A3"; white = "#DCDCCC"
        brightBlack = "#5B605E"; brightRed = "#DCA3A3"; brightGreen = "#BFEBBF"; brightYellow = "#F0DFAF"; brightBlue = "#8CD0D3"; brightPurple = "#DC8CC3"; brightCyan = "#93B3A3"; brightWhite = "#FFFFFF"
    }
}
