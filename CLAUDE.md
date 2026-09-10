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

The wrapper is named `airnvim` but the binary stays **`nvim`**
(`binName = "nvim"`), with `nv` as its only alias.

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
5. Collects specs from `lua/plugins/*.lua` with `mod_dir_to_spec`,
   flattens the lists, and calls `nixInfo.lze.load(specs)`.
6. `require("core.theme")`, which reads the palette, hands it to
   `base16-nvim` and applies the transparency. It comes last because
   the colorscheme plugin has to be loaded before it can be fed.

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
  options.lua         # vim.opt and vim.g. leader = '\'
  keymaps.lua         # global maps (H, L)
  autocmds.lua        # filetype, indentation
  mdwrap.lua          # markdown text wrapping, :MdWrap
  spell.lua           # opt-in spell checking, :SpellToggle
  rumdl.lua           # path to the generated rumdl rules file
  paths.lua           # resolves the real config directory
  palette.lua         # desktop colours, Material names -> ours
  theme.lua           # applies the palette, transparent background

lua/tools/
  init.lua            # loads the modules below
  open.lua            # vim.ui.open -> configurable programs
  lze.lua             # :LzeNix, :LzeStatus

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
  markdown.lua        # render-markdown, image.nvim
  notes.lua           # obsidian.nvim
  ai.lua              # codecompanion
  colors.lua          # base16-nvim, the only spec with no trigger

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
| `markdown.line_length` | `75`             | `textwidth` in `.md` and MD013                 |
| `markdown.images.enable` | `true`         | image.nvim; off saves 137 MB                   |
| `spell.enable`         | `true`           | Whether `:SpellToggle` may turn spell on       |
| `spell.languages`      | `[ "it" "en" ]`  | Dictionaries                                   |
| `spell.filetypes`      | `[ "markdown" ]` | Where the toggle works                         |
| `theme.colors_file`    | `""`             | Palette path; empty means the XDG cache        |
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

The formatter also covers more ground than the servers. With
`lsp_format = "fallback"` in `format.lua`, `web.enable` alone already
formats ts/js and html on save by delegating to the servers, but nothing
reaches `.css` and `.json`, whose servers are shipped in
`vscode-langservers-extracted` and never wired into `lsp.lua`. Biome is
the only route to those two.

`settings.cats` is **readOnly**, derived from
`mapAttrs (_: v: v.enable) config.specs`: every top-level spec becomes a
"cat" usable with `for_cat`. `specMods` adds the `runtimePkgs` field to all
specs, and the final `runtimePkgs` is the concatenation of all of them via
`config.specCollect`.

## Keybindings

`mapleader` and `maplocalleader` are both **`\`**.

### Core global maps

| Key         | Mode    | Source           | Action                |
| ----------- | ------- | ---------------- | --------------------- |
| `H` / `L`   | n, x, o | core/keymaps.lua | Start / end of line   |
| `-`         | n       | files.lua        | Oil in a float        |
| `<leader>z` | n       | core/spell.lua   | Toggle spell checking |

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
  italic — `accent_mid`, mixed halfway between the accent and the body
  text so emphasis does not compete with the headings. Tune the mix with
  `ACCENT_MIX` in `core/palette.lua`.
- Emphasis colours used to be set from a `ColorScheme` autocmd registered
  in the `after` of the render-markdown spec. **That never ran**: `after`
  fires when the first markdown buffer opens, long after the colorscheme
  was applied, and no further `ColorScheme` event follows. Anything that
  has to react to the theme belongs in `core/theme.lua`.
- Bullet icons are one glyph per nesting level (`•`, `⬩`, `-`, `-`) and
  headings use numbered circles rather than hashes. With
  `position = "overlay"` the icon **replaces** the marker, so an icon of
  `" "` renders the line blank: that is what made list dashes look
  missing everywhere except under the cursor and inside a visual
  selection, the two places anti-conceal turns rendering off.
- Code carries no background, inline or fenced. `RenderMarkdownCode` and
  `RenderMarkdownCodeInline` are set with `bg = "NONE"` instead of being
  left alone, because their default link is `ColorColumn`, which the
  transparency pass clears and a link would drag back in.
- Inline code uses `palette.code`, not `palette.red`. matugen derives the
  ANSI colours from the wallpaper, so how legible the red happens to be is
  luck — one measured at 5.11:1 against its background while the body text
  sat at 14.35:1. `palette.readable()` fades it toward `fg` until it
  clears `CODE_CONTRAST` (7:1, the WCAG AAA bar for body-size text) and
  leaves colours that already pass untouched. Do not pin a lighter shade
  by hand: it would hold only until the next wallpaper.
- Both `RenderMarkdownCodeInline` **and**
  `@markup.raw.markdown_inline` get that colour. Setting only the first
  makes inline code change colour as the cursor moves: render-markdown
  draws the extmark, anti-conceal drops it on the cursor line, and the
  text falls back to the treesitter capture underneath.
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
  `tables` exemptions **are ignored**. The generated file sets
  `strict = false`, otherwise long headings and code lines get flagged
  again.
- Disabled rules: `MD024` (headings with the same text), `MD025` (multiple
  level-1 headings), `MD041` (first line need not be a heading). The line
  limit applies to prose only.
- `lua/core/rumdl.lua` is the single place exposing the rules file path to
  `lsp.lua` and `format.lua`.
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
  backslash is a markdown hard break: pandoc and typst keep it on a line
  of its own without making it a paragraph, which is how verse, lyrics
  and subtitle-style lists are written. `gq` would collapse the whole
  block into one paragraph and leave the two spaces stranded mid-line, so
  `mdwrap` splits an `inline` node into one segment per break and wraps
  each on its own. The marker is taken off before `gq` and put back
  after, and the segment wraps at `line_length - 2`, because MD013 counts
  those trailing columns too. Space markers are normalised to exactly
  two, the most MD009 allows. A logical line longer than the limit is
  wrapped onto continuation lines with no marker of their own, so the
  export still shows it as a single line — the source obeys the 75
  columns, the PDF keeps one line per line, and no blank lines are
  needed between them.
- The reflow runs in an **unattached scratch buffer**, and the result is
  written back with a single `nvim_buf_set_lines`. Do not move `gq` back
  onto the real buffer: every paragraph becomes its own buffer change, and
  each change costs a full Treesitter reparse of the document. On a
  504-line file that was 126 reparses — `:w` took 5.2s against 0.2s now.
  Profiling attributed it correctly: parse 0ms, range collection 2ms, `gq`
  loop 3.4s at 27ms per paragraph. Disabling autocmds, the LSP client or
  render-markdown changed nothing; only stopping Treesitter did. Doing it
  in a scratch buffer also makes the reflow one undo step instead of one
  per paragraph.
- Because the scratch buffer has no filetype, the options `gq` reads
  (`formatoptions`, `formatlistpat`, `comments`, indentation) are copied
  across explicitly. Setting `filetype` there instead would fire `FileType`
  and attach Treesitter again, undoing the whole point.
- Three traps solved in there, not to be reintroduced:
  - when an LSP server attaches it sets
    `formatexpr = v:lua.vim.lsp.formatexpr()`, so `gq` asks the server to
    format and `rumdl` does **not** wrap prose;
  - `nvim-treesitter` sets `indentexpr`, which `gq` uses to indent the
    lines it generates: the result is that only the first continuation line
    keeps the list indentation and the rest fall back to zero;
  - the markdown ftplugin puts `-`, `*` and `+` into `comments`, and with
    the `c`/`q` flags active `gq` treats them as comment markers and gets
    numbered-list indentation wrong: keep only `comments = "n:>"` for
    quotes and leave the rest to `formatlistpat` plus the `n` flag.
- Because of the first two, markdown buffers get `formatexpr` and
  `indentexpr` cleared on `LspAttach` and `BufWinEnter`, and again inside
  `M.wrap` for safety.
- `image.nvim` uses the `kitty` backend, which also covers WezTerm, and
  requires `imagemagick`. It is gated by `markdown.images.enable`: the
  plugin reaches imagemagick through `luajit-magick`, so the weight rides
  on the plugin and **removing the CLI package alone saves nothing**
  (measured: identical closure before and after).
- `startup.cowsay` defaults to off. It costs 60 MB, because cowsay is perl,
  and ~39 ms of blocking `io.popen` at every startup. Do not turn the
  default back on: the static header in `ui.lua` is the fallback.

## Spell checking

- Off everywhere by default. `:SpellToggle` / `<leader>z` enables it for
  the current buffer and session only; nothing is persisted.
- `:spelltoggle` and `:spellToggle` work too. User commands **must** start
  with a capital (`E183`), so the lowercase forms are `cnoreabbrev`
  entries in `core/spell.lua`, not commands. They are guarded with
  `getcmdline() ==#` so they only fire when the word is the whole command
  line: an unguarded abbreviation would also rewrite the word inside
  `:s//` patterns and command arguments. Cmdline completion stays
  case-sensitive, so `:spell<Tab>` still offers only the builtins —
  the aliases work when typed in full.
- Several dictionaries apply at once (`spelllang = it,en`): a word passes
  if any of them contains it.
- Code exclusion needs both halves. Neovim's core queries provide
  `(inline) @spell`, which *adds* prose to the checker without excluding
  anything, and `(code_span) @nospell` for inline code. Fenced blocks are
  **not** covered by that: the injected language parser carries no spell
  capture, so `queries/markdown/highlights.scm` adds `@nospell` on
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
index will not reach the package and the editor starts with
`module '...' not found`.

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
- The statusline theme is built by `theme.lualine()`, not by lualine's
  own `auto`. `auto` derives its colours from the colorscheme **at the
  moment it is built**, and lualine loads before the palette is applied,
  so it was picking up the stock Neovim greys and the bar never matched
  the desktop. Every section is `bg = "NONE"`: lualine paints a
  background per section and the editor has none. Only `a`, `b` and `c`
  are defined — `z` reuses `a`, `y` reuses `b`, `x` reuses `c`.
  `ui.lua` rebuilds the whole config from a `ColorScheme` autocmd,
  because lualine caches its highlight groups.
- matugen **replaces** the palette file instead of editing it in place, so
  the watcher in `core/theme.lua` loses its inode at the first change and
  has to be restarted after every event. A single-shot watcher updates the
  theme once and then goes deaf.
- `vim.fn.stdpath("config")` points at a directory a wrapper user usually
  does not have — the Lua config lives in the Nix store, and that path is
  not even on the runtimepath. Use `require("core.paths").config()`.
  The palette is the one thing deliberately read from outside the store,
  and it goes through `$XDG_CACHE_HOME`, not `stdpath`.
- Some binaries are not in the build and come from the host: `git`, plus
  whatever the `settings.open.*` handlers point at.
- `nvim-lint` runs only on `BufReadPost` and `BufWritePost`: do not add
  `BufEnter` or `InsertLeave` back, it was a source of CPU spikes.
- Treesitter grammars come from Nix and are not compiled at runtime: to add
  one, edit the list in `module.nix`.
