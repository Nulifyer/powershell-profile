# Shared theme data for theme.ps1 and wallpaper.ps1
# Keys: bg (terminal background), muted (dimmed UI), path (cwd), git (branch), userhost (user@host)

$script:palettes = [ordered]@{
    ayu_dark              = @{ bg = "#0F1419"; muted = "#565B66"; path = "#FF8F40"; git = "#B8CC52"; userhost = "#FFB454" }
    ayu_mirage            = @{ bg = "#1F2430"; muted = "#707A8C"; path = "#FFAD66"; git = "#D5FF80"; userhost = "#FFD173" }
    carbonfox             = @{ bg = "#161616"; muted = "#7B7C7E"; path = "#EE5396"; git = "#25BE6A"; userhost = "#33B1FF" }
    catppuccin_frappe     = @{ bg = "#303446"; muted = "#ACB0BE"; path = "#F4B8E4"; git = "#BABBF1"; userhost = "#8CAAEE" }
    catppuccin_latte      = @{ bg = "#EFF1F5"; muted = "#ACB0BE"; path = "#ea76cb"; git = "#7287FD"; userhost = "#1e66f5" }
    catppuccin_macchiato  = @{ bg = "#24273A"; muted = "#ACB0BE"; path = "#F5BDE6"; git = "#B7BDF8"; userhost = "#8AADF4" }
    catppuccin_mocha      = @{ bg = "#1E1E2E"; muted = "#ACB0BE"; path = "#F5C2E7"; git = "#B4BEFE"; userhost = "#89B4FA" }
    dracula               = @{ bg = "#282A36"; muted = "#626483"; path = "#FF79C6"; git = "#50FA7B"; userhost = "#F1FA8C" }
    everforest            = @{ bg = "#2D353B"; muted = "#9DA9A0"; path = "#E69875"; git = "#A7C080"; userhost = "#DBBC7F" }
    everforest_light      = @{ bg = "#FDF6E3"; muted = "#829181"; path = "#E67E80"; git = "#8DA101"; userhost = "#DFA000" }
    gruvbox               = @{ bg = "#202020"; muted = "#5A524C"; path = "#E78A4E"; git = "#A9B665"; userhost = "#D8A657" }
    gruvbox_light         = @{ bg = "#FBF1C7"; muted = "#7C6F64"; path = "#AF3A03"; git = "#79740E"; userhost = "#B57614" }
    horizon               = @{ bg = "#1C1E26"; muted = "#6F6F70"; path = "#E95678"; git = "#FAB795"; userhost = "#29D398" }
    kanagawa              = @{ bg = "#1F1F28"; muted = "#727169"; path = "#FFA066"; git = "#98BB6C"; userhost = "#E6C384" }
    lume                  = @{ bg = "#12101E"; muted = "#8A8498"; path = "#D0A0B8"; git = "#A0D4A8"; userhost = "#C4B080" }
    mellow                = @{ bg = "#161617"; muted = "#757581"; path = "#F5A191"; git = "#90B99F"; userhost = "#E6B99D" }
    monokai               = @{ bg = "#272822"; muted = "#A59F85"; path = "#F92672"; git = "#A6E22E"; userhost = "#FD971F" }
    moonfly               = @{ bg = "#080808"; muted = "#808080"; path = "#FF5189"; git = "#79DAC8"; userhost = "#E3C78A" }
    nightfox              = @{ bg = "#192330"; muted = "#738091"; path = "#F4A261"; git = "#81B29A"; userhost = "#DBC074" }
    nord                  = @{ bg = "#2E3440"; muted = "#D8DEE9"; path = "#B48EAD"; git = "#A3BE8C"; userhost = "#88C0D0" }
    onedark               = @{ bg = "#282C34"; muted = "#ABB2BF"; path = "#E86671"; git = "#98C379"; userhost = "#E5C07B" }
    palenight             = @{ bg = "#292D3E"; muted = "#676E95"; path = "#C792EA"; git = "#C3E88D"; userhost = "#FFCB6B" }
    poimandres            = @{ bg = "#1B1E28"; muted = "#A6ACCD"; path = "#D0679D"; git = "#5DE4C7"; userhost = "#FFFAC2" }
    rose_pine             = @{ bg = "#191724"; muted = "#908CAA"; path = "#EB6F92"; git = "#F6C177"; userhost = "#9CCFD8" }
    rose_pine_dawn        = @{ bg = "#FAF4ED"; muted = "#797593"; path = "#B4637A"; git = "#EA9D34"; userhost = "#56949F" }
    solarized             = @{ bg = "#002B36"; muted = "#93A1A1"; path = "#CB4B16"; git = "#859900"; userhost = "#268BD2" }
    tokyonight            = @{ bg = "#1A1B26"; muted = "#444B6A"; path = "#FF966C"; git = "#9ECE6A"; userhost = "#7AA2F7" }
    tokyonight_light      = @{ bg = "#D5D6DB"; muted = "#6172B0"; path = "#8C4351"; git = "#485E30"; userhost = "#34548A" }
    vesper                = @{ bg = "#101010"; muted = "#7E7E7E"; path = "#FFC799"; git = "#99FFE4"; userhost = "#FF8080" }
    zenburn               = @{ bg = "#3F3F3F"; muted = "#606060"; path = "#F0DFAF"; git = "#709080"; userhost = "#DCA3A3" }
    challengerdeep        = @{ bg = "#1E1C31"; muted = "#565575"; path = "#C991E1"; git = "#62D196"; userhost = "#65B2FF" }
    flexoki               = @{ bg = "#1C1B1A"; muted = "#575653"; path = "#CE5D97"; git = "#879A39"; userhost = "#4385BE" }
    flexoki_light         = @{ bg = "#FFFCF0"; muted = "#575653"; path = "#CE5D97"; git = "#879A39"; userhost = "#4385BE" }
    github_dark           = @{ bg = "#101216"; muted = "#8B949E"; path = "#DB61A2"; git = "#56D364"; userhost = "#58A6FF" }
    iceberg               = @{ bg = "#161821"; muted = "#6B7089"; path = "#E27878"; git = "#B4BE82"; userhost = "#84A0C6" }
    iceberg_light         = @{ bg = "#E8E9EC"; muted = "#8389A3"; path = "#CC517A"; git = "#668E3D"; userhost = "#2D539E" }
    material_darker       = @{ bg = "#212121"; muted = "#4A4A4A"; path = "#C792EA"; git = "#C3E88D"; userhost = "#82AAFF" }
    oxocarbon             = @{ bg = "#161616"; muted = "#525252"; path = "#EE5396"; git = "#42BE65"; userhost = "#78A9FF" }
    oxocarbon_light       = @{ bg = "#F2F4F8"; muted = "#525252"; path = "#EE5396"; git = "#42BE65"; userhost = "#0F62FE" }
    spaceduck             = @{ bg = "#16172D"; muted = "#686F9A"; path = "#CE6F8F"; git = "#5CCC96"; userhost = "#7A5CCC" }
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
        name = "Gruvbox Dark"; background = "#202020"; foreground = "#DDC7A1"; cursorColor = "#DDC7A1"; selectionBackground = "#2A2827"
        black = "#2A2827"; red = "#EA6962"; green = "#A9B665"; yellow = "#D8A657"; blue = "#7DAEA3"; purple = "#D3869B"; cyan = "#89B482"; white = "#DDC7A1"
        brightBlack = "#5A524C"; brightRed = "#EA6962"; brightGreen = "#A9B665"; brightYellow = "#D8A657"; brightBlue = "#7DAEA3"; brightPurple = "#D3869B"; brightCyan = "#89B482"; brightWhite = "#EBDBB2"
    }
    gruvbox_light = @{
        name = "Gruvbox Light"; background = "#FBF1C7"; foreground = "#3C3836"; cursorColor = "#3C3836"; selectionBackground = "#EBDBB2"
        black = "#FBF1C7"; red = "#CC241D"; green = "#98971A"; yellow = "#D79921"; blue = "#458588"; purple = "#B16186"; cyan = "#689D69"; white = "#7C6F64"
        brightBlack = "#928374"; brightRed = "#9D0006"; brightGreen = "#79740E"; brightYellow = "#B57614"; brightBlue = "#076678"; brightPurple = "#8F3F71"; brightCyan = "#427B58"; brightWhite = "#3C3836"
    }
    everforest = @{
        name = "Everforest Dark"; background = "#2D353B"; foreground = "#D3C6AA"; cursorColor = "#D3C6AA"; selectionBackground = "#475258"
        black = "#343F44"; red = "#E67E80"; green = "#A7C080"; yellow = "#DBBC7F"; blue = "#7FBBB3"; purple = "#D699B6"; cyan = "#83C092"; white = "#D3C6AA"
        brightBlack = "#475258"; brightRed = "#E67E80"; brightGreen = "#A7C080"; brightYellow = "#DBBC7F"; brightBlue = "#7FBBB3"; brightPurple = "#D699B6"; brightCyan = "#83C092"; brightWhite = "#D3C6AA"
    }
    everforest_light = @{
        name = "Everforest Light"; background = "#FDF6E3"; foreground = "#5C6A72"; cursorColor = "#5C6A72"; selectionBackground = "#E6E2CC"
        black = "#EFEBD4"; red = "#F85552"; green = "#8DA101"; yellow = "#DFA000"; blue = "#3A94C5"; purple = "#DF69BA"; cyan = "#35A77C"; white = "#5C6A72"
        brightBlack = "#939F91"; brightRed = "#F85552"; brightGreen = "#8DA101"; brightYellow = "#DFA000"; brightBlue = "#3A94C5"; brightPurple = "#DF69BA"; brightCyan = "#35A77C"; brightWhite = "#5C6A72"
    }
    tokyonight = @{
        name = "Tokyo Night"; background = "#1A1B26"; foreground = "#C0CAF5"; cursorColor = "#C0CAF5"; selectionBackground = "#2F3549"
        black = "#16161E"; red = "#F7768E"; green = "#9ECE6A"; yellow = "#E0AF68"; blue = "#7AA2F7"; purple = "#BB9AF7"; cyan = "#7DCFFF"; white = "#A9B1D6"
        brightBlack = "#444B6A"; brightRed = "#F7768E"; brightGreen = "#9ECE6A"; brightYellow = "#E0AF68"; brightBlue = "#7AA2F7"; brightPurple = "#BB9AF7"; brightCyan = "#7DCFFF"; brightWhite = "#C0CAF5"
    }
    tokyonight_light = @{
        name = "Tokyo Night Light"; background = "#D5D6DB"; foreground = "#343B58"; cursorColor = "#343B58"; selectionBackground = "#9699A3"
        black = "#1A1B26"; red = "#8C4351"; green = "#485E30"; yellow = "#965027"; blue = "#34548A"; purple = "#5A4A78"; cyan = "#166775"; white = "#343B58"
        brightBlack = "#9699A3"; brightRed = "#8C4351"; brightGreen = "#485E30"; brightYellow = "#965027"; brightBlue = "#34548A"; brightPurple = "#5A4A78"; brightCyan = "#166775"; brightWhite = "#343B58"
    }
    nord = @{
        name = "Nord"; background = "#2E3440"; foreground = "#D8DEE9"; cursorColor = "#D8DEE9"; selectionBackground = "#434C5E"
        black = "#3B4252"; red = "#BF616A"; green = "#A3BE8C"; yellow = "#EBCB8B"; blue = "#81A1C1"; purple = "#B48EAD"; cyan = "#88C0D0"; white = "#E5E9F0"
        brightBlack = "#4C566A"; brightRed = "#BF616A"; brightGreen = "#A3BE8C"; brightYellow = "#EBCB8B"; brightBlue = "#81A1C1"; brightPurple = "#B48EAD"; brightCyan = "#8FBCBB"; brightWhite = "#ECEFF4"
    }
    dracula = @{
        name = "Dracula"; background = "#282A36"; foreground = "#F8F8F2"; cursorColor = "#F8F8F2"; selectionBackground = "#44475A"
        black = "#21222C"; red = "#FF5555"; green = "#50FA7B"; yellow = "#F1FA8C"; blue = "#BD93F9"; purple = "#FF79C6"; cyan = "#8BE9FD"; white = "#F8F8F2"
        brightBlack = "#626483"; brightRed = "#FF6E6E"; brightGreen = "#69FF94"; brightYellow = "#FFFFA5"; brightBlue = "#D6ACFF"; brightPurple = "#FF92DF"; brightCyan = "#A4FFFF"; brightWhite = "#FFFFFF"
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
        name = "Kanagawa"; background = "#1F1F28"; foreground = "#DCD7BA"; cursorColor = "#DCD7BA"; selectionBackground = "#223249"
        black = "#16161D"; red = "#C34043"; green = "#76946A"; yellow = "#C0A36E"; blue = "#7E9CD8"; purple = "#957FB8"; cyan = "#6A9589"; white = "#C8C093"
        brightBlack = "#727169"; brightRed = "#C34043"; brightGreen = "#76946A"; brightYellow = "#C0A36E"; brightBlue = "#7E9CD8"; brightPurple = "#957FB8"; brightCyan = "#6A9589"; brightWhite = "#DCD7BA"
    }
    solarized = @{
        name = "Solarized Dark"; background = "#002B36"; foreground = "#839496"; cursorColor = "#839496"; selectionBackground = "#073642"
        black = "#073642"; red = "#DC322F"; green = "#859900"; yellow = "#B58900"; blue = "#268BD2"; purple = "#D33682"; cyan = "#2AA198"; white = "#EEE8D5"
        brightBlack = "#586E75"; brightRed = "#CB4B16"; brightGreen = "#586E75"; brightYellow = "#657B83"; brightBlue = "#839496"; brightPurple = "#6C71C4"; brightCyan = "#93A1A1"; brightWhite = "#FDF6E3"
    }
    onedark = @{
        name = "One Dark"; background = "#282C34"; foreground = "#ABB2BF"; cursorColor = "#ABB2BF"; selectionBackground = "#3E4451"
        black = "#3E4451"; red = "#E06C75"; green = "#98C379"; yellow = "#E5C07B"; blue = "#61AFEF"; purple = "#C678DD"; cyan = "#56B6C2"; white = "#ABB2BF"
        brightBlack = "#545862"; brightRed = "#BE5046"; brightGreen = "#98C379"; brightYellow = "#D19A66"; brightBlue = "#61AFEF"; brightPurple = "#C678DD"; brightCyan = "#56B6C2"; brightWhite = "#ABB2BF"
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
        name = "Ayu Dark"; background = "#0F1419"; foreground = "#BFBDB6"; cursorColor = "#FFB454"; selectionBackground = "#272D38"
        black = "#131721"; red = "#F07178"; green = "#B8CC52"; yellow = "#FFB454"; blue = "#59C2FF"; purple = "#D2A6FF"; cyan = "#95E6CB"; white = "#BFBDB6"
        brightBlack = "#BFBDB6"; brightRed = "#FF8F40"; brightGreen = "#B8CC52"; brightYellow = "#E6B673"; brightBlue = "#59C2FF"; brightPurple = "#D2A6FF"; brightCyan = "#95E6CB"; brightWhite = "#F3F4F5"
    }
    ayu_mirage = @{
        name = "Ayu Mirage"; background = "#242936"; foreground = "#CCCAC2"; cursorColor = "#FFCC66"; selectionBackground = "#33415E"
        black = "#191E2A"; red = "#F28779"; green = "#D5FF80"; yellow = "#FFCC66"; blue = "#5CCFE6"; purple = "#D4BFFF"; cyan = "#95E6CB"; white = "#CCCAC2"
        brightBlack = "#707A8C"; brightRed = "#F28779"; brightGreen = "#D5FF80"; brightYellow = "#FFD173"; brightBlue = "#73D0FF"; brightPurple = "#D4BFFF"; brightCyan = "#95E6CB"; brightWhite = "#FFFFFF"
    }
    vesper = @{
        name = "Vesper"; background = "#101010"; foreground = "#FFFFFF"; cursorColor = "#FFC799"; selectionBackground = "#232323"
        black = "#101010"; red = "#FF8080"; green = "#99FFE4"; yellow = "#FFC799"; blue = "#99FFE4"; purple = "#FFC799"; cyan = "#99FFE4"; white = "#FFFFFF"
        brightBlack = "#7E7E7E"; brightRed = "#FF8080"; brightGreen = "#99FFE4"; brightYellow = "#FFC799"; brightBlue = "#99FFE4"; brightPurple = "#FFC799"; brightCyan = "#99FFE4"; brightWhite = "#FFFFFF"
    }
    poimandres = @{
        name = "Poimandres"; background = "#1B1E28"; foreground = "#E4F0FB"; cursorColor = "#A6ACCD"; selectionBackground = "#303340"
        black = "#171922"; red = "#D0679D"; green = "#5DE4C7"; yellow = "#FFFAC2"; blue = "#89DDFF"; purple = "#ADD7FF"; cyan = "#5FB3A1"; white = "#E4F0FB"
        brightBlack = "#506477"; brightRed = "#FCC5E9"; brightGreen = "#5DE4C7"; brightYellow = "#FFFAC2"; brightBlue = "#89DDFF"; brightPurple = "#ADD7FF"; brightCyan = "#5DE4C7"; brightWhite = "#FFFFFF"
    }
    nightfox = @{
        name = "Nightfox"; background = "#192330"; foreground = "#CDCECF"; cursorColor = "#CDCECF"; selectionBackground = "#2B3B51"
        black = "#393B44"; red = "#C94F6D"; green = "#81B29A"; yellow = "#DBC074"; blue = "#719CD6"; purple = "#9D79D6"; cyan = "#63CDCF"; white = "#DFDFE0"
        brightBlack = "#575860"; brightRed = "#D16983"; brightGreen = "#8EBAA4"; brightYellow = "#E0C989"; brightBlue = "#7AD5D6"; brightPurple = "#BAA1E2"; brightCyan = "#7AD5D6"; brightWhite = "#E4E4E5"
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
        name = "Horizon"; background = "#1C1E26"; foreground = "#DCDFE4"; cursorColor = "#DCDFE4"; selectionBackground = "#2E303E"
        black = "#232530"; red = "#E95678"; green = "#29D398"; yellow = "#FAB795"; blue = "#26BBD9"; purple = "#EE64AC"; cyan = "#59E1E3"; white = "#DCDFE4"
        brightBlack = "#6F6F70"; brightRed = "#F09383"; brightGreen = "#29D398"; brightYellow = "#FAC29A"; brightBlue = "#26BBD9"; brightPurple = "#EE64AC"; brightCyan = "#59E1E3"; brightWhite = "#E3E6EE"
    }
    palenight = @{
        name = "Palenight"; background = "#292D3E"; foreground = "#959DCB"; cursorColor = "#FFCB6B"; selectionBackground = "#444267"
        black = "#292D3E"; red = "#FF5370"; green = "#C3E88D"; yellow = "#FFCB6B"; blue = "#82AAFF"; purple = "#C792EA"; cyan = "#89DDFF"; white = "#959DCB"
        brightBlack = "#676E95"; brightRed = "#FF5370"; brightGreen = "#C3E88D"; brightYellow = "#FFCB6B"; brightBlue = "#82AAFF"; brightPurple = "#C792EA"; brightCyan = "#89DDFF"; brightWhite = "#FFFFFF"
    }
    zenburn = @{
        name = "Zenburn"; background = "#3F3F3F"; foreground = "#DCDCCC"; cursorColor = "#7CB8BB"; selectionBackground = "#21322F"
        black = "#3F3F3F"; red = "#DCA3A3"; green = "#709080"; yellow = "#F0DFAF"; blue = "#8CD0D3"; purple = "#DCA3A3"; cyan = "#7CB8BB"; white = "#DCDCCC"
        brightBlack = "#606060"; brightRed = "#DCA3A3"; brightGreen = "#C3BF9F"; brightYellow = "#F0DFAF"; brightBlue = "#8CD0D3"; brightPurple = "#DC8CC3"; brightCyan = "#7CB8BB"; brightWhite = "#FFFFFF"
    }
    challengerdeep = @{
        name = "Challenger Deep"; background = "#1E1C31"; foreground = "#CBE3E7"; cursorColor = "#CBE3E7"; selectionBackground = "#565575"
        black = "#141228"; red = "#FF5458"; green = "#62D196"; yellow = "#FFB378"; blue = "#65B2FF"; purple = "#906CFF"; cyan = "#63F2F1"; white = "#CBE3E7"
        brightBlack = "#565575"; brightRed = "#FF8080"; brightGreen = "#95FFA4"; brightYellow = "#FFE9AA"; brightBlue = "#91DDFF"; brightPurple = "#C991E1"; brightCyan = "#AAFFE4"; brightWhite = "#FBFCFC"
    }
    flexoki = @{
        name = "Flexoki Dark"; background = "#1C1B1A"; foreground = "#CECDC3"; cursorColor = "#CECDC3"; selectionBackground = "#575653"
        black = "#1C1B1A"; red = "#D14D41"; green = "#879A39"; yellow = "#D0A215"; blue = "#4385BE"; purple = "#CE5D97"; cyan = "#3AA99F"; white = "#CECDC3"
        brightBlack = "#575653"; brightRed = "#D14D41"; brightGreen = "#879A39"; brightYellow = "#D0A215"; brightBlue = "#4385BE"; brightPurple = "#CE5D97"; brightCyan = "#3AA99F"; brightWhite = "#FFFCF0"
    }
    flexoki_light = @{
        name = "Flexoki Light"; background = "#FFFCF0"; foreground = "#100F0F"; cursorColor = "#100F0F"; selectionBackground = "#CECDC3"
        black = "#100F0F"; red = "#AF3029"; green = "#66800B"; yellow = "#AD8301"; blue = "#205EA6"; purple = "#A02F6F"; cyan = "#24837B"; white = "#CECDC3"
        brightBlack = "#575653"; brightRed = "#D14D41"; brightGreen = "#879A39"; brightYellow = "#D0A215"; brightBlue = "#4385BE"; brightPurple = "#CE5D97"; brightCyan = "#3AA99F"; brightWhite = "#F2F0E5"
    }
    github_dark = @{
        name = "GitHub Dark"; background = "#101216"; foreground = "#C9D1D9"; cursorColor = "#C9D1D9"; selectionBackground = "#3B5070"
        black = "#101216"; red = "#F78166"; green = "#56D364"; yellow = "#E3B341"; blue = "#58A6FF"; purple = "#DB61A2"; cyan = "#2B7489"; white = "#C9D1D9"
        brightBlack = "#8B949E"; brightRed = "#F78166"; brightGreen = "#56D364"; brightYellow = "#E3B341"; brightBlue = "#58A6FF"; brightPurple = "#DB61A2"; brightCyan = "#388BFD"; brightWhite = "#FFFFFF"
    }
    iceberg = @{
        name = "Iceberg Dark"; background = "#161821"; foreground = "#C6C8D1"; cursorColor = "#C6C8D1"; selectionBackground = "#1E2132"
        black = "#1E2132"; red = "#E27878"; green = "#B4BE82"; yellow = "#E2A478"; blue = "#84A0C6"; purple = "#A093C7"; cyan = "#89B8C2"; white = "#C6C8D1"
        brightBlack = "#6B7089"; brightRed = "#E98989"; brightGreen = "#C0CA8E"; brightYellow = "#E9B189"; brightBlue = "#91ACD1"; brightPurple = "#ADA0D3"; brightCyan = "#95C4CE"; brightWhite = "#D2D4DE"
    }
    iceberg_light = @{
        name = "Iceberg Light"; background = "#E8E9EC"; foreground = "#33374C"; cursorColor = "#33374C"; selectionBackground = "#DCDFE7"
        black = "#DCDFE7"; red = "#CC517A"; green = "#668E3D"; yellow = "#C57339"; blue = "#2D539E"; purple = "#7759B4"; cyan = "#327698"; white = "#33374C"
        brightBlack = "#8389A3"; brightRed = "#CC3768"; brightGreen = "#598030"; brightYellow = "#B6662D"; brightBlue = "#22478E"; brightPurple = "#6845AD"; brightCyan = "#3F83A6"; brightWhite = "#262A3F"
    }
    material_darker = @{
        name = "Material Darker"; background = "#212121"; foreground = "#EEFFFF"; cursorColor = "#EEFFFF"; selectionBackground = "#353535"
        black = "#212121"; red = "#FF5370"; green = "#C3E88D"; yellow = "#FFCB6B"; blue = "#82AAFF"; purple = "#C792EA"; cyan = "#89DDFF"; white = "#EEFFFF"
        brightBlack = "#4A4A4A"; brightRed = "#F07178"; brightGreen = "#C3E88D"; brightYellow = "#FFCB6B"; brightBlue = "#82AAFF"; brightPurple = "#C792EA"; brightCyan = "#89DDFF"; brightWhite = "#FFFFFF"
    }
    oxocarbon = @{
        name = "Oxocarbon Dark"; background = "#161616"; foreground = "#F2F4F8"; cursorColor = "#F2F4F8"; selectionBackground = "#393939"
        black = "#262626"; red = "#EE5396"; green = "#42BE65"; yellow = "#08BDBA"; blue = "#78A9FF"; purple = "#BE95FF"; cyan = "#33B1FF"; white = "#DDE1E6"
        brightBlack = "#525252"; brightRed = "#FF7EB6"; brightGreen = "#42BE65"; brightYellow = "#3DDBD9"; brightBlue = "#82CFFF"; brightPurple = "#BE95FF"; brightCyan = "#33B1FF"; brightWhite = "#F2F4F8"
    }
    oxocarbon_light = @{
        name = "Oxocarbon Light"; background = "#F2F4F8"; foreground = "#161616"; cursorColor = "#161616"; selectionBackground = "#DDE1E6"
        black = "#161616"; red = "#EE5396"; green = "#42BE65"; yellow = "#FF6F00"; blue = "#0F62FE"; purple = "#673AB7"; cyan = "#08BDBA"; white = "#DDE1E6"
        brightBlack = "#525252"; brightRed = "#FF7EB6"; brightGreen = "#42BE65"; brightYellow = "#FF6F00"; brightBlue = "#0F62FE"; brightPurple = "#BE95FF"; brightCyan = "#08BDBA"; brightWhite = "#F2F4F8"
    }
    spaceduck = @{
        name = "Spaceduck"; background = "#16172D"; foreground = "#ECF0C1"; cursorColor = "#ECF0C1"; selectionBackground = "#30365F"
        black = "#16172D"; red = "#E33400"; green = "#5CCC96"; yellow = "#F2CE00"; blue = "#7A5CCC"; purple = "#CE6F8F"; cyan = "#00A3CC"; white = "#ECF0C1"
        brightBlack = "#686F9A"; brightRed = "#E33400"; brightGreen = "#5CCC96"; brightYellow = "#F2CE00"; brightBlue = "#B3A1E6"; brightPurple = "#CE6F8F"; brightCyan = "#00A3CC"; brightWhite = "#FFFFFF"
    }
}
