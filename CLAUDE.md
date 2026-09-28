# CLAUDE.md

Working notes for this repository: **airnvim**, a Neovim packaged with
**Nix** (flake) through BirdeeHub's `nix-wrapper-modules`, using the
**`lze`** / **`lzextras`** plugin loader.

## What this project is

Not a Neovim config to drop into `~/.config/nvim`: a **Nix flake** that
produces a self-contained package with plugins, language servers, linters
and CLI tools already on its `PATH`. The Lua config lives in this
repository (`settings.config_directory = ./.`) and is injected into the
wrapper.

- `flake.nix` — inputs (`nixpkgs`, `wrappers`, `flake-parts`,
  `plugins-lze`, `plugins-lzextras`) and outputs: `packages.default`,
  `wrappers.airnvim`, `nixosModules`, `homeModules`, `overlays`.
- `module.nix` — the Nix core: declares `options.settings` (feature flags),
  the `nvim-lib.pluginsFromPrefix` helper, and the `specs`, i.e. the plugin
  and package groups. Plugins, language servers and linters are added here.
- `init.lua` — bootstrap: configures `lze`, registers the custom handlers,
  loads `core.*` and `tools`, then the specs under `lua/plugins/`.

The wrapper is named `airnvim` but the binary stays **`nvim`**, as set by
`binName`, with `nv` as its only alias.

The guiding constraint is lightness: the target profile is Nix, Bash and
Markdown daily, Lua occasionally. Anything heavier belongs behind a feature
flag that defaults to off.

### Load order (init.lua)

1. `vim.loader.enable()`.
2. Exposes `_G.nixInfo`, the bridge to the wrapper's information. Outside
   the wrapper it installs a stub returning the defaults, so the config
   still runs. `nixInfo.get_nix_plugin_path(name)` looks the plugin up in
   `plugins.lazy` / `plugins.start`.
3. Registers the `lze` handlers:
   - `auto_enable` — disables the spec when the plugin does not exist on
     the Nix side (accepts `true`, a string, or a list of names).
   - `for_cat` — enables based on `settings.cats.<name>`.
   - `nixInfo.lze.lsp` — the LSP handler from `lzextras`.
4. `require("core.options" | "core.keymaps" | "core.autocmds")` and
   `require("tools")`.
5. Collects specs from `lua/plugins/*.lua` with `mod_dir_to_spec`, flattens
   the lists, and calls `nixInfo.lze.load(specs)`.
6. `require("core.theme")`, which reads the palette, hands it to
   `base16-nvim` and applies the transparency. It comes last because the
   colorscheme plugin has to be loaded before it can be fed.

### The `nixInfo` API in Lua

`nixInfo(default, ...path)` reads a value from the Nix config with a
fallback:

```lua
nixInfo(75, "settings", "markdown", "line_length")
nixInfo("kitty", "settings", "render-backend")
nixInfo("", "settings", "obsidian", "vault")
nixInfo(false, "settings", "cats", "ai")       -- for_cat handler
```

## File layout

```text
init.lua              # lze bootstrap + spec loading
flake.nix             # inputs/outputs, wrappers.airnvim
module.nix            # feature flags, specs, plugins and packages
selene.toml           # lua lint; the "vim" std lives in vim.toml
vim.toml              # selene standard library for neovim

lua/core/
  options.lua         # vim.opt and vim.g. leader = Space
  keymaps.lua         # global maps (H, L)
  autocmds.lua        # filetype, indentation
  mdwrap.lua          # markdown text wrapping, :MdWrap
  mdlink.lua          # follow links (<CR>, Ctrl+click), insert (␣il)
  spell.lua           # opt-in spell checking, :SpellToggle
  rumdl.lua           # rumdl rules path, the markdown save pipeline
  paths.lua           # resolves the real config directory
  palette.lua         # desktop colours, Material names -> ours
  theme.lua           # applies the palette, transparent background

lua/tools/
  init.lua            # loads the modules below
  open.lua            # vim.ui.open -> configurable programs
  lze.lua             # :LzeNix, :LzeStatus
  docs.lua            # :MdGuide, :NvCheat -> guides/
  markdown.lua        # :PreviewMd, :PasteImage and its name popup
  mdformat.lua        # :MdFormatDir[Recursive], format .md files

lua/plugins/
  ui.lua              # lualine, alpha, devicons, fidget, todo, colorizer
  edit.lua            # sleuth, surround, autopairs, spectre, undotree,
                      # lazydev, actions-preview, plenary
  files.lua           # oil, telescope + extensions
  git.lua             # gitsigns, lazygit, diffview
  cmp.lua             # nvim-cmp, sources, luasnip
  lsp.lua             # nvim-lspconfig + one spec per server
  lint.lua            # nvim-lint
  format.lua          # conform
  treesitter.lua      # treesitter + textobjects
  markdown.lua        # render-markdown, image.nvim, live-preview,
                      # img-clip
  notes.lua           # obsidian.nvim
  ai.lua              # codecompanion
  colors.lua          # base16-nvim, the only spec with no trigger

guides/               # :MdGuide and :NvCheat sheets, plus assets/
queries/              # treesitter query overrides
spell/                # dictionaries (.spl only)
```

## Plugin spec conventions

Every file in `lua/plugins/` returns `{ ... }` with one `lze` spec or a
list of them. Recurring fields:

- `"plugin-name"` — first positional element, the Nix plugin name.
- `enabled`, `lazy` — standard booleans (note: `enabled`, not `enable`).
- `auto_enable` — enables only when the plugin exists on the Nix side.
  **Must be `false` when the setup lives in `after`**, otherwise the spec
  loads immediately.
- `for_cat = "<cat>"` — enables based on `settings.cats`, whose keys are
  the names of the top-level specs in `module.nix` (`ai`, `obsidian`,
  `general`, `lsp`, `lze`).
- `ft`, `cmd`, `event`, `keys` — lazy-loading triggers. **Every plugin
  needs one**: the project rule is that nothing loads unless used.
- `dep_of = { ... }` — declares the plugin as a dependency of others.
- `before` / `after(plugin)` — run before/after load; `after` is where
  `require("<plugin>").setup(plugin.opts)` goes.
- `opts` — a table **or a function** (a function must be evaluated, see
  `format.lua`).
- `version`, `branch` — pins (telescope uses `branch = '0.1.x'`).

Adding a plugin takes **two steps**: declare it in `module.nix`
(`specs.general.data` or a dedicated spec) **and** create its Lua spec in
`lua/plugins/`.

### LSP conventions (`lua/plugins/lsp.lua`)

LSP specs are not plugins: the first element is the **server name** and the
config lives in the `lsp = { ... }` field. The `lze.lsp` handler turns them
into `vim.lsp.config()` + `vim.lsp.enable()`.

```lua
{ "nixd", ft = { "nix" }, lsp = { root_markers = { "flake.nix" } } }
```

The `nvim-lspconfig` spec acts as the container: it injects the
`cmp_nvim_lsp` capabilities and, in `before`, configures `vim.diagnostic`
and the `LspAttach` autocmd with the buffer-local keymaps.

Always-on servers: `nixd`, `lua_ls`, `rumdl` (markdown). Optional servers
(`ruff`, `ts_ls`, `html`) use `enabled = vim.fn.executable("...") == 1`, so
they switch themselves on when the matching Nix flag puts the binary on the
`PATH`.

**Do not touch the `nixd` configuration**: it is an explicit project
constraint.

## Feature flags (module.nix → settings)

| Option                 | Default          | Effect                                         |
| ---------------------- | ---------------- | ---------------------------------------------- |
| `ai.enable`            | `false`          | CodeCompanion                                  |
| `ai.adapter`           | `copilot`        | Model backend                                  |
| `obsidian.enable`      | `true`           | obsidian.nvim                                  |
| `obsidian.vault`       | `""`             | Vault; empty keeps the plugin out of the build |
| `markdown.line_length` | `75`             | `textwidth`, MD013, inline image width (cells) |
| `markdown.images.enable` | `true`         | image.nvim; off saves 137 MB                   |
| `markdown.images.max_height` | `80`       | Image height cap, % of the window              |
| `markdown.images.paste_width` | `"15cm"`  | `{ width=... }` on pasted images, for the PDF  |
| `spell.enable`         | `true`           | Whether `:SpellToggle` may turn spell on       |
| `spell.languages`      | `[ "it" "en" ]`  | Dictionaries                                   |
| `spell.filetypes`      | `[ "markdown" ]` | Where the toggle works                         |
| `theme.colors_file`    | `""`             | Palette path; empty means the XDG cache        |
| `mouse.scroll_lines`   | `5`              | Lines per mouse wheel step                     |
| `oil.preview`          | `false`          | Open Oil's preview with the list               |
| `oil.width`            | `75`             | Oil window width, % of the editor              |
| `nerd_font.enable`     | `true`           | Include file-type icons                        |
| `langs.python.enable`  | `false`          | `ruff`                                         |
| `langs.web.enable`     | `false`          | ts/js and html servers; costs ~225 MB of node  |
| `langs.web.formatter.enable` | `false`    | biome formats ts/js, html, css, json; ~64 MB   |
| `startup.cowsay`       | `false`          | `fortune \| cowsay` header; on costs 60 MB     |
| `render-backend`       | `kitty`          | Image backend                                  |
| `open.*`               | `""`             | External programs for `vim.ui.open`            |

The two web flags are deliberately independent. `langs.web.enable` buys
*understanding*: `ts_ls` and the html server give diagnostics, completion,
go-to-definition and rename, and they cost ~225 MB because both are
JavaScript and drag node in. `langs.web.formatter.enable` buys *layout*
only, through one rust binary at ~64 MB with no node. Wanting a tidy
`.json` is not the same as wanting type checking, so neither implies the
other.

The formatter also covers more ground than the servers. With `lsp_format`
set to `"fallback"` in `format.lua`, `web.enable` alone already formats
ts/js and html on save by delegating to the servers, but nothing reaches
`.css` and `.json`, whose servers are shipped in
`vscode-langservers-extracted` and never wired into `lsp.lua`. Biome is the
only route to those two.

`settings.cats` is **readOnly**: every top-level spec becomes a "cat"
usable with `for_cat`.

```nix
settings.cats = mapAttrs (_: v: v.enable) config.specs;
```

`specMods` adds the `runtimePkgs` field to all specs, and the final
`runtimePkgs` is the concatenation of all of them via `config.specCollect`.

## Keybindings

`mapleader` is **Space**, `maplocalleader` is **`\`** (nothing uses it yet;
it stays free for filetype plugins). `core/keymaps.lua` maps a lone
`<Space>` to `<Nop>` in n and x, so an unknown leader chord does not fall
through to the native `l`. Keep every `<leader>` map out of insert and
terminal mode: there it would delay every typed space.

### Core global maps

| Key         | Mode    | Source           | Action                |
| ----------- | ------- | ---------------- | --------------------- |
| `H` / `L`   | n, x, o | core/keymaps.lua | Start / end of line   |
| `-`         | n       | files.lua        | Oil in a float        |
| `<leader>z` | n       | core/spell.lua   | Toggle spell checking |
| `<leader>ip`| n       | markdown.lua     | Paste clipboard image |
| `<leader>t` | n (.md) | core/keymaps.lua | Table of contents (`gO`) |
| `<CR>`, `<C-LeftMouse>` | n (.md) | core/mdlink.lua | Follow link |
| `<leader>il`| n, x (.md) | core/mdlink.lua | Insert link to a note |

Following links is `core/mdlink.lua`. Plain `gf` and `gx` could not do it:
render-markdown hides the path, `gf` on the link text looked for a file
called "note", `gx` handed the bare word to `xdg-open`, and rumdl's
definition request returned nothing. The link is found through the
`markdown_inline` treesitter tree; its path is resolved from the note's own
directory (`%20` decoded); `#anchor` is matched against headings by slug. A
missing `.md` asks to be created (default No) and is written at once, so
the link is never left dangling. `<CR>` off a link falls back to itself.
Ctrl+click replays `<LeftMouse>` before following: `getmousepos().column`
ignores concealed text, and past the first link it picked the wrong one.
`<leader>il` searches from the cwd like `<leader>sf`, or from the note's
directory when the note lies outside it, and writes paths relative to the
note, with `../` where needed.

`<leader>p` is taken as a prefix by the treesitter swaps, which is why the
image paste lives under `<leader>i`.

### Markdown emphasis (`.md` only, core/keymaps.lua)

Visual mode, three keys, each a plain `c<delim><C-r>"<delim><Esc>` mapping
registered from a `FileType markdown` autocmd:

| Key       | Wraps in     |
| --------- | ------------ |
| `<C-b>`   | `**bold**`   |
| `<C-i>`   | `*italic*`   |
| ``<C-`>`` | `` `code` `` |

Key encodings, checked against the bytes each one produces:

- `<C-b>` is byte `02`. Mapping it costs the page-back scroll in visual
  mode, which `<C-u>` still covers. Bold was on plain `B` at first, which
  is why it appeared broken: the other two are Ctrl chords, so `<C-b>` is
  what anyone actually reaches for.
- `<C-i>` is byte `09`, i.e. `<Tab>`. Tab therefore italicises too;
  harmless, since Tab does nothing in visual mode.
- `<C-[>` is byte `1B`, i.e. `<Esc>`. **Never map it** — it would take away
  leaving visual mode.
- ``<C-`>`` encodes as `80 FC 04 60`, which is not ASCII: it only arrives
  from terminals speaking the kitty keyboard protocol (kitty, WezTerm,
  Ghostty, foot). Elsewhere `nvim-surround`'s `S` is the fallback.

These mappings go through `c` and the unnamed register, which
`clipboard=unnamedplus` ties to the system clipboard: emphasising a word
replaces what you had copied. Swapping to a named register
(`"zc**<C-r>z**<Esc>`) avoids it if that ever becomes annoying.

### Visual / operator pending

| Key                      | Mode | Source         | Action                       |
| ------------------------ | ---- | -------------- | ---------------------------- |
| `<C-s>`                  | n, v | ai.lua         | CodeCompanion Actions        |
| `<leader>a`              | n, v | ai.lua         | AI chat                      |
| `ga`                     | v    | ai.lua         | Add to CodeCompanion         |
| `<leader>ca`             | n, v | edit.lua       | Code action with preview     |
| `<leader>sR`             | n, v | edit.lua       | Spectre on word or selection |
| `<leader>ol`             | v    | notes.lua      | Link the selection           |
| `<leader>onl`            | v    | notes.lua      | New note from the selection  |
| `S`                      | x    | nvim-surround  | Surround the selection       |
| `am` `im` `ac` `ic` `as` | x, o | treesitter.lua | Textobjects                  |

### Prefixes

- `<leader>s` — telescope (`sf`, `sg`, `sw`, `sb`, `sh`, `sk`, `sd`, `sr`,
  `s.`, `sn`) plus spectre in uppercase (`sR`, `sF`).
- `<leader>g` — git: `gg` LazyGit, `gd` Diffview open, `gq` close, `gh`
  history, `gc`/`gs`/`gb` telescope pickers.
- `<leader>o` — obsidian.
- `<leader>p` — `ps`/`pS` treesitter parameter swap.
- LSP buffer-local: `gd`, `gD`, `gr`, `gI`, `K`, `<C-k>`, `<leader>D`,
  `ds`, `ws`, `wa`, `wr`, `wl`, `e`, `rn`, `:Format`.

### Conflicts already resolved — do not reintroduce

| Key          | Assigned to        | What moved                     |
| ------------ | ------------------ | ------------------------------ |
| `<leader>a`  | CodeCompanion      | treesitter swap → `<leader>ps` |
| `<leader>sw` | telescope grep     | Spectre → `<leader>sR`         |
| `<leader>gc` | telescope commits  | Diffview close → `<leader>gq`  |
| `<leader>gb` | telescope branches | fugitive removed               |
| `<leader>ca` | actions-preview    | duplicate LSP nmap dropped     |

Buffer-local maps win over global ones; between two global maps the last
registered wins, so load order matters.

### Filetype-bound keymaps

Use a `FileType` autocmd with `vim.keymap.set(..., { buffer = args.buf })`,
so other filetypes are left alone.

## Markdown

- `render-markdown.nvim` colours the buffer, but names no colour itself.
  Three groups defined in `core/theme.lua` carry the whole look:
  `MdHeading` (accent, bold) for headings, `MdAccent` (accent, no weight)
  for bullets, ordered markers and checkboxes, and `MdSoft` for bold and
  italic — `accent_mid`, mixed halfway between the accent and the body text
  so emphasis does not compete with the headings. Tune the mix with
  `ACCENT_MIX` in `core/palette.lua`. A fourth, `MdHighlight`, marks
  `==text==`: body text on `palette.mark`, 25% accent mixed into the
  background of the current variant (`HIGHLIGHT_MIX`), 8:1 on dark and
  10.6:1 on light. render-markdown's default linked it to the inline code
  colour, and the two could not be told apart.
- Emphasis colours used to be set from a `ColorScheme` autocmd registered
  in the `after` of the render-markdown spec. **That never ran**: `after`
  fires when the first markdown buffer opens, long after the colorscheme
  was applied, and no further `ColorScheme` event follows. Anything that
  has to react to the theme belongs in `core/theme.lua`.
- Headings are numbered 1, 1.1, 1.1.1 from level 1, **rendered only**:
  `heading_number()` in `markdown.lua` returns `ctx.sections` joined with
  dots as render-markdown's `icons` function. Never write numbers into the
  file: the PDF export numbers headings itself and would do it twice. A
  skipped level shows as 0 (`1.0.1`) on purpose, next to rumdl's MD001,
  which the rules mark `unfixable`: `rumdl fmt` on save used to raise the
  level silently. `position = "inline"`, since a number is wider than the
  `#` marks it replaces and `overlay` would cover the text.
- **A document with a single H1 treats it as its title**: the H1 gets no
  number and the levels below count from it (`1`, `2`, `2.1` instead of
  `1.1`, `1.2`, `1.2.1`). With two or more H1 they are chapters, numbered
  as above; with none, the hierarchy still shows (`0.1`), on purpose. The
  PDF keeps numbering from H1 in every case: only the editor changes.
  render-markdown passes the `icons` callback no buffer, so module.nix
  patches `buf = self.context.buf` into its context (`--replace-fail`).
  `h1_count()` reads only the direct children of the top-level sections,
  cached per changedtick: a Treesitter query over the whole tree took 66 ms
  on a 635 KB file at every change, this takes 0.09 ms. Using the current
  buffer instead of `ctx.buf` would number a split by the rules of the
  other window.
- Levels 1-3 carry a rule under the text: render-markdown's heading
  "background" set to `MdHeadingRule1-3` (core/theme.lua), which are
  underlines with `sp` in the heading colour and no fill: solid, dashed,
  dotted. `width = "block"` with no padding or `min_width` ends it on the
  last letter. The styles and the colour need Smulx/Setulc in terminfo:
  under `TERM=xterm-256color`, WezTerm's default, all three came out as the
  same plain light underline (checked by zooming screenshots). The
  wrapper's `runShell` in module.nix therefore sets `TERM=wezterm`, with
  the 4 KB terminfo from `pkgs.wezterm.passthru.terminfo`, when
  `TERM_PROGRAM=WezTerm`. Undercurl diagnostics got fixed on the way.
- Bullet icons are one glyph per nesting level (`•`, `⬩`, `-`, `-`). With
  the `overlay` position the icon **replaces** the marker, so an icon made
  of a single space renders the line blank: that is what made list dashes
  look missing everywhere except under the cursor and inside a visual
  selection, the two places anti-conceal turns rendering off.
- Checkboxes have the same trap. The icon is drawn over the `[ ]` and the
  space after it, and whatever it does not cover is concealed, the `-`
  marker included: the empty unchecked icon made `- [ ] task` render as a
  bare `task`. The icons are `󰄱` / `󰱒`, or `☐` / `☑` with
  `nerd_font.enable` off, each followed by a space. Hiding the marker also
  took the number off `1. [ ]`; module.nix patches render-markdown's
  checkbox renderer (`--replace-fail`) to draw numbered markers (`1.`,
  `1)`) as bullets do, while `-`, `+` and `*` stay hidden. The plugin's own
  `checkbox.bullet` would have put `•` before every `- [ ]` too.
- Code carries no background, inline or fenced. `RenderMarkdownCode` and
  `RenderMarkdownCodeInline` are set with `bg = "NONE"` instead of being
  left alone, because their default link is `ColorColumn`, which the
  transparency pass clears and a link would drag back in.
- Inline code uses `palette.code`, not `palette.red`. matugen derives the
  ANSI colours from the wallpaper, so how legible the red happens to be is
  luck — one measured at 5.11:1 against its background while the body text
  sat at 14.35:1. `palette.readable()` fades it toward `fg` until it clears
  `CODE_CONTRAST` (7:1, the WCAG AAA bar for body-size text) and leaves
  colours that already pass untouched. Do not pin a lighter shade by hand:
  it would hold only until the next wallpaper.
- Both `RenderMarkdownCodeInline` **and** `@markup.raw.markdown_inline` get
  that colour. Setting only the first makes inline code change colour as
  the cursor moves: render-markdown draws the extmark, anti-conceal drops
  it on the cursor line, and the text falls back to the treesitter capture
  underneath.
- `rumdl` handles linting (as an LSP server), fixing and formatting on save
  via `conform`. **The rules are generated by `module.nix`**
  (`settings.markdown.rules_file`, a `writeText` in the store) rather than
  by a project `.rumdl.toml`: only this way do they apply outside this
  repository too.
- The LSP server **ignores overrides passed on the command line**
  (`--config`): the only channel that works is `settings.rumdl.configPath`.
  Verified by comparing diagnostics with and without. `disableRules` works,
  the `MD013` options do not.
- `MD013` trap: with `strict = true` the `headings`, `code-blocks` and
  `tables` exemptions **are ignored**. The generated file sets `strict` to
  `false`, otherwise long headings and code lines get flagged again.
- Disabled rules: `MD018` (`#tag` is not a heading missing its space, see
  below), `MD024` (headings with the same text), `MD025` (multiple level-1
  headings), `MD041` (first line need not be a heading), `MD045` (images
  need no alt text: pasted screenshots rarely get one). The line limit
  applies to prose only.
- `lua/core/rumdl.lua` is the single place exposing the rules file path to
  `lsp.lua` and `format.lua`, and holds the **save pipeline**,
  `format(bufnr)`, used by both `:w` (format_on_save, which returns nil for
  markdown) and `:MdFormatDir`: trailing spaces cut to two, blank lines
  around `---`, rumdl, mdwrap, rumdl. The first rumdl pass exists so mdwrap
  measures lines after list indentation and markers are fixed; with mdwrap
  first, rumdl moved a 4-space nested item to 2 and the next save rewrapped
  it. Measured with every plugin attached, the extra pass costs ~40-50 ms
  per save at 64 KB and 0.05-0.2 s at 635 KB.
- The cut to two spaces must come first: rumdl's MD009 fix **deletes** a
  run of 3+ trailing spaces, hard break included (a verse ending in three
  spaces joined the next one), and has no option to shorten it instead.
- `---` and `===` at column 0 are always a rule: `separate_rules()` in
  mdwrap gives them a blank line on each side before rumdl's first pass,
  and rewrites `===` as `---`, since markdown has no `===` rule. Right
  under a line of text either is a setext underline, and rumdl rewrote the
  text as `## text` or `# text`: a rule typed without its blank line took
  the paragraph with it. Longer runs (`-------`) count too.
- rumdl runs through conform with `TIMEOUT_MS` (10 s). The 3 s default was
  exceeded by the first save of a 635 KB file, and conform then dropped
  rumdl silently: the file was saved half formatted.
- Benchmark a save with every plugin attached, timed until the event loop
  drains (a `vim.schedule` flag after the work). A `nofile` scratch buffer
  skips the LSP and image.nvim and gave numbers several times too low; work
  queued by edits also runs inside the *next* conform wait, so per-step
  timings blame the wrong step.
- Text wrapping is handled by `core/mdwrap.lua`, not prettier. The module
  does three things: sets `textwidth` (wrap as you type), removes the `t`
  flag from `formatoptions` inside code blocks (checked on line change, not
  on every keystroke), and reflows existing text with `gq` on save, plus on
  demand via `:MdWrap`.
- `mdwrap` reflows **one `inline` node at a time** (the real text of a
  paragraph or list item), skipping `fenced_code_block`,
  `indented_code_block`, `pipe_table`, `html_block` and headings. Ranges
  are applied bottom-up so line numbers stay valid. Formatting the whole
  `list` node at once does **not** work: nested list indentation breaks.
- **Hard line breaks are preserved.** A line ending in two spaces or in a
  backslash is a markdown hard break: pandoc and typst keep it on a line of
  its own without making it a paragraph, which is how verse, lyrics and
  subtitle-style lists are written. `gq` would collapse the whole block
  into one paragraph and leave the two spaces stranded mid-line, so
  `mdwrap` splits an `inline` node into one segment per break and wraps
  each on its own. The marker is taken off before `gq` and put back after,
  and the segment wraps at `line_length - 2`, because MD013 counts those
  trailing columns too. Space markers are normalised to exactly two, the
  most MD009 allows. A logical line longer than the limit is wrapped onto
  continuation lines with no marker of their own, so the export still shows
  it as a single line — the source obeys the 75 columns, the PDF keeps one
  line per line, and no blank lines are needed between them.
- The reflow runs in an **unattached scratch buffer**, and the result is
  written back **hunk by hunk** (`vim.text.diff`, bottom-up), never with
  one `nvim_buf_set_lines(0, -1)` over the whole buffer. A full replace
  collapses every extmark: image.nvim's padding under an image vanished,
  text was drawn over the picture, and its render on save failed with
  `E966: Invalid line number`. Do not move `gq` back onto the real buffer:
  every paragraph becomes its own buffer change, and each change costs a
  full Treesitter reparse of the document. On a 504-line file that was 126
  reparses — `:w` took 5.2s against 0.2s now. Profiling attributed it
  correctly: parse 0ms, range collection 2ms, `gq` loop 3.4s at 27ms per
  paragraph. Disabling autocmds, the LSP client or render-markdown changed
  nothing; only stopping Treesitter did. Doing it in a scratch buffer also
  makes the reflow one undo step instead of one per paragraph.
- A line holding only an image (`![..](..)` or `![[..]]`, column 0, outside
  fenced code) gets a blank line on each side before the reflow. Text next
  to it is otherwise the same paragraph: `gq` pulls it onto the image line,
  and pandoc only turns an image alone in its paragraph into a figure with
  a caption. The spaced text is parsed with a string parser, since it is
  not in the buffer yet. Lone image lines are never wrapped.
- **`#word` is an Obsidian tag, `##Word` a heading missing its space.**
  rumdl's MD018 made a heading of any line starting with `#word`, a tag the
  reflow had moved there included, so MD018 is disabled. The same pass that
  spaces images (`space_blocks()`) turns 2-6 marks followed by a letter
  into `## Word` with a blank line on each side; before that, `gq` merged
  `##Word` into the paragraph and MD018 then made a heading of the whole
  merged line. A single `#` is never touched: a `#Title` typed without its
  space stays a tag, by choice. Front matter (`##` is a YAML comment) and
  fenced code are skipped. rumdl's MD026 still reports a lone `#tag ... .`
  line as a heading ending in punctuation; its fix changes nothing, so it
  is only a false warning.
- **Obsidian callout headers and display math are never reflowed.**
  Treesitter sees `> [!note]` as quote text, and joining the body onto it
  made the body the callout's title (text on the header line is the title
  in Obsidian). `segments()` leaves out a header line, so the body wraps
  below it, and `$$` lines plus what they enclose, which `gq` had collapsed
  into one `$$ ... $$` line. Pandoc definition lists (`: def`) and fenced
  divs (`:::`) are still joined like prose: left alone on purpose, since
  they are not used here.
- Because the scratch buffer has no filetype, the options `gq` reads
  (`formatoptions`, `formatlistpat`, `comments`, indentation) are copied
  across explicitly. Setting `filetype` there instead would fire `FileType`
  and attach Treesitter again, undoing the whole point.
- **A wrap must never land before a word that opens a block.** `gq` breaks
  at any space, so ` - `, ` + `, ` * `, ` 1. `, ` # `, ` > `, a run like
  `---`, a code fence or `<` could start a continuation line and turn the
  rest of the sentence into a list, a heading or a quote; rumdl then made
  it permanent (MD032 blank lines around the "list", MD026 the heading's
  full stop gone). Measured: 16 of 119 placements. Likewise `[[a b]]` split
  over two lines stopped being a link (37 of 62), and `$a + b$` was split
  too. `protect()` swaps those spaces for a glue character `gq` does not
  break at (no-break space, or figure space / narrow no-break space when
  the text already has one) and the loop swaps it back after `gqq`.
  Indentation, quote leaders, the list marker and a checkbox are left out.
  Inline code may still wrap: that is valid. Wikilinks and math are bound
  only outside code spans, and math only as pandoc reads it (no space
  inside either dollar, no digit after the closing one): a `` `$$` `` in
  backticks once paired with a later one and made half a sentence one
  unbreakable word. Block openers are glued inside code spans too, since
  blocks are parsed before inline code.
- Four traps solved in there, not to be reintroduced:
  - `gq` over a multi-line range reads **every** line matching
    `formatlistpat` as a new list item: a wrapped line opening with a year
    and a period (1954.) got a hanging indent, and a quote came out with
    its `>` doubled. Each segment is `:join`ed into one line first (`j` in
    `formatoptions` drops the `>` leaders) and `gqq` wraps that, so only
    the real marker on the first line counts;
  - when an LSP server attaches it sets `formatexpr` to
    `v:lua.vim.lsp.formatexpr()`, so `gq` asks the server to format and
    `rumdl` does **not** wrap prose;
  - `nvim-treesitter` sets `indentexpr`, which `gq` uses to indent the
    lines it generates: the result is that only the first continuation line
    keeps the list indentation and the rest fall back to zero;
  - the markdown ftplugin puts `-`, `*` and `+` into `comments`, and with
    the `c`/`q` flags active `gq` treats them as comment markers and gets
    numbered-list indentation wrong: keep only `comments = "n:>"` for
    quotes and leave the rest to `formatlistpat` plus the `n` flag.
- Because of the LSP and Treesitter traps, markdown buffers get
  `formatexpr` and `indentexpr` cleared on `LspAttach` and `BufWinEnter`,
  and again inside `M.wrap` for safety.
- `image.nvim` uses the `kitty` backend, which also covers WezTerm, and
  requires `imagemagick`. It is gated by `markdown.images.enable`: the
  plugin reaches imagemagick through `luajit-magick`, so the weight rides
  on the plugin and **removing the CLI package alone saves nothing**
  (measured: identical closure before and after).
- **module.nix patches image.nvim's `on_lines` handler** to merge renders:
  upstream queues a full re-query of every image in the document
  (treesitter over the whole buffer) per edit. A save writing 150 hunks ran
  150 of them: 2.6 s on a 64 KB file, over two minutes on 635 KB, with
  either save pipeline. Patched, one render per event-loop turn: 0.95 s at
  64 KB. `--replace-fail` breaks the build if upstream changes the handler;
  check it still needs the patch before adapting it.
- Images are drawn below their link all the time
  (`only_render_image_at_cursor = false`), not in a float on hover.
  `max_width` is in terminal cells, not pixels, so it reuses
  `markdown.line_length`: an image is never wider than the prose. Height is
  capped by `markdown.images.max_height`, 80% of the window. Proportions
  are kept, so whichever cap is reached first sets the size: at 50% a 16:9
  screenshot in a 28-row window stopped at 50 columns instead of 75
  (measured: cells 11×22 px, 75 columns need 22 rows). In a short window or
  split the image still shrinks below the text width; that is the cap
  working. `window_overlap_clear_enabled` hides images under floats, which
  WezTerm otherwise leaves on top.
- **WezTerm leaves torn copies of images behind when nvim scrolls.** It
  attaches kitty images to text cells, so a terminal scroll carries them
  along, and it ignores image.nvim's delete-by-id: after the redraw the old
  copy survives in strips over the text. Reproduced by typing lines under
  an image and by `^e`. `wezterm_image_redraw()` in `markdown.lua` runs
  `:mode` (which clears the cells) and re-places every image, on
  `WinScrolled` and when the line count changes, debounced 120 ms and only
  under `TERM_PROGRAM=WezTerm`. Verified with screenshots before and after.
  Do not extend it to every keystroke: typing inside a line moves nothing
  and each `:mode` is a full redraw.
- It clears through `backend.clear(id, true)`, **never `image:clear()`**:
  that one also deletes the extmark whose `virt_lines` reserve the space
  under the image. Nvim lost those lines on every redraw and put the view
  back, so the mouse wheel stuck just above an image and never crossed it.
  Tested by sending SGR wheel codes (`ESC[<65;x;yM`) with WezTerm's
  `send-text` command and reading `line("w0")` and `topfill` over
  `--listen`: without images or with the fix, 5 lines per tick through the
  image's filler rows.
- **The wheel scrolls markdown with `scrolloff = 0`**, restored 400 ms
  after the last step (`wheel_without_margin()`, buffer-local expr maps on
  `<ScrollWheelDown>`/`<ScrollWheelUp>`). With the global margin of 10, a
  step that dragged the cursor onto an image line made nvim move the view
  to fit the margin around 22 rows of image: going down one step went
  *back* a line, going up one jumped 14 lines instead of 5. Native nvim,
  reproduced with images and with `scrolloff` 5 too; only 0 gave a uniform
  5 lines per step both ways. Restoring the option does not move the view,
  so the keyboard keeps its margin.
- Browser preview is `live-preview.nvim` (4 MB, pure lua), started with
  `:PreviewMd` and ended with `:PreviewMd stop`. **module.nix patches out
  the `uv.run()` at the end of its `Server:start`**: that nested loop never
  returns while the socket listens, so pages were served while the editor
  froze and ignored even SIGTERM. Do not drop the patch when bumping the
  plugin without checking the line is gone upstream. `dynamic_root = true`
  serves from the file's own directory, so `assets/` resolves wherever nvim
  was started; `../` paths do not. Callouts and wikilinks are not rendered
  in the browser.
- `img-clip.nvim` pastes clipboard images. `tools/markdown.lua` asks for a
  name in a float and saves `assets/YYYY-MM-DD_HH-MM-SS_<name>.png` beside
  the file. The plugin defines its own `:PasteImage` on load; the spec's
  `after` redefines it to go through the popup. The clipboard is read with
  the host's `wl-paste`, like `git` a host dependency: `wl-clipboard` would
  add ~200 MB of closure to the build.
- The markdown paste template appends `{ width=<paste_width> }`
  (`settings.markdown.images.paste_width`, default `15cm`, empty drops it).
  Pandoc turns it into `image(..., width: 15cm)` for typst; the editor
  ignores it (the treesitter `image` node ends at `)`, so image.nvim still
  finds the picture) and rumdl raises nothing. `mdwrap`'s image-line
  pattern accepts a trailing `{...}` for this.
- `guides/` ships in the store with the config and is opened read-only by
  `:MdGuide` / `:NvCheat`. Keep both files clean under the generated rumdl
  rules; the cheatsheet uses headings and plain lists, no tables.
- `:MdFormatDir` (`tools/mdformat.lua`) runs the save pipeline,
  `core.rumdl.format()`, on every `.md` of one directory, subdirectories
  excluded. Default: the current file's directory, Oil's, or `:pwd`. Each
  file is loaded into a buffer, formatted, and written with `noautocmd`
  only if its text changed (BufWritePre would format it twice); clean files
  keep their mtime. Buffers it loaded are wiped after. It skips a buffer
  with unsaved changes, and a file whose swap file shows another nvim has
  it (`SwapExists` answers read-only). One file per `vim.defer_fn(0)` tick,
  not `vim.schedule`: only a timer lets typed keys in, so `q` in the
  progress float can cancel. Output identical to `:w` file by file. 60
  small files took 4.6 s with the earlier two-pass pipeline; not
  re-measured with three passes.
- `:MdFormatDirRecursive` is the same run over the whole tree under that
  directory (`vim.fs.dir` with `depth = math.huge`). Hidden files and
  directories are skipped, and only lowercase `.md` counts. Symlinked
  directories are not followed, so a link pointing up cannot loop. The
  float and the report show paths relative to the starting directory.
- `startup.cowsay` defaults to off. It costs 60 MB, because cowsay is perl,
  and ~39 ms of blocking `io.popen` at every startup. Do not turn the
  default back on: the static header in `ui.lua` is the fallback.

## Spell checking

- Off everywhere by default. `:SpellToggle` / `<leader>z` enables it for
  the current buffer and session only; nothing is persisted.
- User commands **must** start with a capital (`E183`) and exist only in
  that form. Lowercase aliases (`:spelltoggle`, `:mdguide`, ...) used to be
  `cnoreabbrev` entries from a `core/cmdalias.lua`; they were removed on
  purpose. Cmdline completion is case-sensitive and never lists
  abbreviations, so `:md<Tab>` offered nothing and the aliases only worked
  typed in full. Do not bring them back; `:Md<Tab>` is the way.
- Several dictionaries apply at once (`spelllang = it,en`): a word passes
  if any of them contains it.
- Code exclusion needs both halves. Neovim's core queries capture
  `(inline)` as `@spell`, which *adds* prose to the checker without
  excluding anything, and `(code_span) @nospell` for inline code. Fenced
  blocks are **not** covered by that: the injected language parser carries
  no spell capture, so `queries/markdown/highlights.scm` adds `@nospell` on
  `fenced_code_block` and `indented_code_block`. Do not remove it.
- Only `.spl` files are shipped. The `.sug` suggestion caches were dropped:
  `z=` works without them and the Italian one alone was 19.5 MB.
- Vim only publishes English under `runtime/spell/` in git; other languages
  come from the FTP mirrors. Use `curl -f` when fetching, or a 404 page
  lands in the file and Neovim reports `E757`.

## Build and checks

```sh
nix build            # build the package
nix run              # launch the editor
nix flake check
nix flake update     # refresh the lockfile
```

Useful during development:

```sh
nix eval .#packages.x86_64-linux.default.drvPath   # evaluate everything
selene init.lua lua/                               # lint lua
nixfmt module.nix flake.nix                        # format nix
nix build --dry-run .#default                      # download size
nix path-info --closure-size -h .#default          # build size
```

**After creating new files, `git add -A` before rebuilding**: flakes only
copy git-tracked files into the store, so a Lua module missing from the
index will not reach the package and the editor starts with a "module not
found" error.

On the wrapper's `PATH`: `nixfmt`, `statix`, `deadnix` for Nix; `stylua`,
`selene` for Lua; `rumdl` for Markdown; `shellcheck`, `shfmt` for Bash.

## Code style

- Comments in **English**, short, and only at the points that need them.
- **Maximum 75 characters per comment line**, indentation included.
- Section headings:

  ```nix
  # SECTION NAME
  # ------------------------------------------------
  # --- Subsection name ---
  ```

  ```lua
  -- SECTION NAME
  --------------------------------------------------
  -- Subsection name --
  ```

- Markdown: 75-column lines, `-` for lists, ATX headings, fenced code
  blocks with triple backticks.

## Notes and traps

- `clipboard = unnamedplus`: the unnamed register is synced with `+`.
- `vim.o.exrc = true`: project-local `.nvim.lua` files are executed.
- The palette comes from **DankMaterialShell**, whose `matugen` theming
  derives it from the wallpaper. `core/palette.lua` reads
  `dms-colors.json`, matugen's canonical output. **Do not switch to the
  colorscheme DMS also generates for Neovim**: it is written from a
  per-editor template, needs their `base46` fork, and is not on the
  wrapper's runtimepath. That template already moved once — it used to
  write `lua/plugins/dankcolors.lua`, and when it stopped, the palette
  silently froze for weeks. The JSON is the stable contract.
- **Icons are Nerd Font `nf-md` glyphs only, U+F0000 and up.** Every glyph
  in U+E000-F8FF was lost before the first commit, left as a bare space or
  an empty string: diagnostic signs, 11 cmp kinds, the dashboard buttons,
  todo-comments, the neovim.io link, the unchecked checkbox. The ones above
  U+F0000 survived. No font causes that: the bytes were missing from the
  files. Pick glyphs by name from Nerd Fonts' `glyphnames.json` and check
  the codepoints after saving (`grep -P '[\x{E000}-\x{F8FF}]'` must find
  nothing in `lua/`). The Neovim logo exists only in the lost range, so
  neovim.io links take the plain web icon.
- Floating windows get no statusline. Since 0.12 a float shows one when its
  local 'statusline' is set, and lualine sets it on every window it
  refreshes: Oil's preview grew a `[No Name]` bar and stood a row taller
  than the list beside it. `ui.lua` wraps `lualine.statusline` to return
  nil inside floats. Oil's float is 75% wide with the preview (`^p`) on the
  right. Oil creates the preview `focusable = false`, which also lets mouse
  events fall through to the window behind; a `BufWinEnter` autocmd in
  `files.lua` sets `mouse = true` on the window marked `oil_preview`, so
  the wheel scrolls it and the cursor stays in the list. The preview is
  `fast_scratch`: only the first `&lines` lines of the file are read, so
  the wheel reaches no further than that.
- Oil previews text files only (`not_text()` in `files.lua`, passed as
  `preview_win.disable_preview`): a list of binary extensions, then a NUL
  byte in the first 8 KB, as git and grep test it. `fast_scratch` reads
  "the first screenful of lines", and a PNG has almost no newlines: a
  multi-MB screenshot was read nearly whole and shown as garbage. SVG stays
  previewable. Width is `settings.oil.width` (%); `settings.oil.preview`
  makes `-` call `open_float(nil, { preview = {} })`, otherwise `^p`
  toggles it.
- The statusline theme is built by `theme.lualine()`, not by lualine's own
  `auto`. `auto` derives its colours from the colorscheme **at the moment
  it is built**, and lualine loads before the palette is applied, so it was
  picking up the stock Neovim greys and the bar never matched the desktop.
  Every section is `bg = "NONE"`: lualine paints a background per section
  and the editor has none. Only `a`, `b` and `c` are defined — `z` reuses
  `a`, `y` reuses `b`, `x` reuses `c`. `ui.lua` rebuilds the whole config
  from a `ColorScheme` autocmd, because lualine caches its highlight
  groups.
- matugen **replaces** the palette file instead of editing it in place, so
  the watcher in `core/theme.lua` loses its inode at the first change and
  has to be restarted after every event. A single-shot watcher updates the
  theme once and then goes deaf.
- `vim.fn.stdpath("config")` points at a directory a wrapper user usually
  does not have — the Lua config lives in the Nix store, and that path is
  not even on the runtimepath. Use `require("core.paths").config()`. The
  palette is the one thing deliberately read from outside the store, and it
  goes through `$XDG_CACHE_HOME`, not `stdpath`.
- Some binaries are not in the build and come from the host: `git`, plus
  whatever the `settings.open.*` handlers point at.
- `nvim-lint` runs only on `BufReadPost` and `BufWritePost`: do not add
  `BufEnter` or `InsertLeave` back, it was a source of CPU spikes.
- Treesitter grammars come from Nix and are not compiled at runtime: to add
  one, edit the list in `module.nix`.
