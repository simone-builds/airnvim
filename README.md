# Airnvim

A small, fast Neovim packaged with Nix. Not a config you copy into
`~/.config/nvim` — a flake that produces one self-contained binary with
every plugin, language server, linter and formatter already inside it.

Clone it, run `nix run`, and you have a working editor. Nothing to install,
nothing to bootstrap on first launch, no plugin manager downloading half of
GitHub while you wait.

## Why this exists

Most Neovim setups install a plugin manager which then fetches plugins at
runtime, and expect you to install language servers separately with your
system package manager. That leaves two moving parts that drift apart: the
config assumes tools that may not be there.

Here, Nix builds everything together. The plugins, the language servers,
the formatters and the CLI tools are pinned in one lockfile and end up on
the editor's own `PATH`. The same commit produces the same editor on any
machine — and uninstalling is deleting one symlink.

The design goal is **lightness**. The target profile is Nix, Bash and
Markdown daily, Lua occasionally; anything heavier is behind a flag that is
off by default. Every plugin is lazy-loaded on a trigger, so nothing that
goes unused costs startup time.

## Quick start

You need [Nix](https://nixos.org/download) with flakes enabled.

```sh
# Try it without installing anything
nix run github:<user>/airnvim

# Or build it and get ./result/bin/nvim
nix build github:<user>/airnvim
```

## Installing

The binary is called `nvim`, with `nv` as a shorter alias.

### NixOS

```nix
{
  inputs.airnvim.url = "github:<user>/airnvim";

  # in your system configuration
  imports = [ inputs.airnvim.nixosModules.default ];
  wrappers.airnvim.enable = true;
}
```

### Home Manager

```nix
{
  imports = [ inputs.airnvim.homeModules.default ];
  wrappers.airnvim.enable = true;
}
```

### As an overlay

```nix
nixpkgs.overlays = [ inputs.airnvim.overlays.default ];
environment.systemPackages = [ pkgs.airnvim ];
```

### Configuring it

Every option lives under `wrappers.airnvim.settings`:

```nix
wrappers.airnvim = {
  enable = true;
  settings = {
    markdown.line_length = 80;
    obsidian.vault = "~/notes";
    langs.python.enable = true;
  };
};
```

See [Options](#options) for the full list.

## What's inside

Neovim 0.12 plus the following. Everything is lazy-loaded: plugins load on
a filetype, a command, a keypress or an event, never at startup unless they
have to be.

**Interface** — [lualine](https://github.com/nvim-lualine/lualine.nvim)
statusline, [alpha](https://github.com/goolord/alpha-nvim) dashboard,
[fidget](https://github.com/j-hui/fidget.nvim) for LSP progress,
[web-devicons](https://github.com/nvim-tree/nvim-web-devicons),
[colorizer](https://github.com/norcalli/nvim-colorizer.lua) for inline hex
colours, [todo-comments](https://github.com/folke/todo-comments.nvim).

**Files and search** — [oil.nvim](https://github.com/stevearc/oil.nvim)
edits the filesystem as if it were a buffer,
[telescope](https://github.com/nvim-telescope/telescope.nvim) with the
native fzf sorter and `ui-select` for fuzzy finding everything else.

**Editing** — [nvim-surround](https://github.com/kylechui/nvim-surround),
[autopairs](https://github.com/windwp/nvim-autopairs),
[spectre](https://github.com/nvim-pack/nvim-spectre) for search-and-replace
across a project, [undotree](https://github.com/mbbill/undotree),
[actions-preview](https://github.com/aznhe21/actions-preview.nvim),
[vim-sleuth](https://github.com/tpope/vim-sleuth) for indentation
detection.

**Git** — [gitsigns](https://github.com/lewis6991/gitsigns.nvim) with
inline blame, [lazygit](https://github.com/kdheepak/lazygit.nvim) for the
full UI, [diffview](https://github.com/sindrets/diffview.nvim) for diffs
and file history.

**Language support** — `nvim-lspconfig` with servers for Nix
([nixd](https://github.com/nix-community/nixd)), Lua
(`lua-language-server`) and Markdown
([rumdl](https://github.com/rvben/rumdl)) always on, plus optional Python
and web servers. [nvim-lint](https://github.com/mfussenegger/nvim-lint)
runs `shellcheck`, `selene`, `statix` and `deadnix`;
[conform](https://github.com/stevearc/conform.nvim) formats on save with
`stylua`, `shfmt`, `nixfmt` and `rumdl`.

**Completion** — [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) with LSP,
snippet, path and buffer sources, command-line completion, and
[LuaSnip](https://github.com/L3MON4D3/LuaSnip) with `friendly-snippets`.

**Treesitter** — grammars are built by Nix, never compiled at runtime, so
there is no C toolchain in the closure. Provides precise highlighting,
folds, indentation and textobjects.

**Markdown** —
[render-markdown](https://github.com/MeanderingProgrammer/render-markdown.nvim)
renders headings, code blocks, tables, checkboxes (numbered ones keep their
number) and `==highlights==` in the buffer;
[image.nvim](https://github.com/3rd/image.nvim) shows images inline in
terminals that support the kitty graphics protocol (kitty, WezTerm). It is
the single heaviest thing in the build — see
[Weight](#weight-and-what-it-is-made-of).

**Optional** —
[obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim) for note
taking, [CodeCompanion](https://github.com/olimorris/codecompanion.nvim)
for in-editor AI chat.

### CLI tools on the editor's PATH

`ripgrep`, `fd`, `lazygit`, `nixd`, `nixfmt`, `statix`, `deadnix`,
`shellcheck`, `shfmt`, `lua-language-server`, `stylua`, `selene`, `rumdl`,
plus `imagemagick` when inline images are on and `fortune`/`cowsay` when
the dashboard header is.

They are visible to the editor only — they do not leak into your shell.

## Features worth knowing about

### Markdown is the centre of gravity

Wrapping is handled internally rather than by an external formatter.
`textwidth` wraps as you type, and on save the prose is reflowed one
Treesitter node at a time, so code blocks, tables and headings are left
alone and nested list indentation survives. `:MdWrap` does it on demand.

Style rules come from `rumdl`, which acts as a language server, a fixer,
and a formatter. The rules are generated by Nix into the store, not read
from a project `.rumdl.toml` — which means they apply in every directory,
not just inside this repository.

Saving runs `rumdl`, then the reflow, then `rumdl` again. The first pass
fixes list indentation and markers before the prose is measured, so a file
reaches its final form in a single save instead of changing again on the
next one. `:MdFormatDir` runs the same pipeline on every `.md` of a
directory (the current file's by default, subdirectories excluded), and
`:MdFormatDirRecursive` on its whole tree, hidden files and directories
left out: both ask first, show a progress bar that `q` cancels, write only
the files that change and skip any with unsaved edits.

The reflow knows what it must not touch. The header line of an Obsidian
callout, the one holding `[!type]` and the title, is left alone, so the
body never turns into the title. `$$` display math stays on its own lines.
Hard line breaks — two trailing spaces or a backslash, the way verse and
subtitles are written — survive, and three or more spaces are cut to two
rather than lost. `#tag` stays an Obsidian tag even at the start of a line,
while `##Title` typed without its space becomes a proper `## Title`.

A wrap never lands right before a `-`, `#`, `>` or `1.` in the middle of a
sentence, where it would turn the rest of the sentence into a list item, a
heading or a quote, and never splits a `[[wikilink]]` or `$inline math$`. A
line of `---` or `===` right under a line of text is a rule, not a heading:
saving turns `===` into `---` and puts blank lines around it.

Headings are numbered in the buffer, never in the file, since the PDF
export numbers them itself: `1`, `1.1`, `1.1.1`. A document with a single
level-1 heading treats it as its title, shows it without a number and
counts from the level below (`1`, `2`, `2.1`). A skipped level shows as `0`
(`1.0.1`), so a broken hierarchy is visible rather than hidden.

`:MdGuide` opens a markdown syntax guide, callouts included from the
simplest to nested ones, and `:NvCheat` a cheatsheet: the daily keys first,
then the rest of the classic Vim reference card, checked against this
build.

### Spell checking is opt-in

Off everywhere until you ask for it. `:SpellToggle` or `<leader>z` turns it
on for the current buffer and the current session only — nothing is written
to disk.

Italian and English are checked at once by default: a word passes if any
dictionary contains it, so mixed-language notes work. Code is never checked
— fenced blocks, indented blocks and inline `` `code` `` are all excluded,
as are URLs and link targets.

Vim's own spell keys apply: `z=` for suggestions, `zg` to add a word, `]s`
and `[s` to jump between mistakes.

The dictionaries are binary `.spl` files checked into `spell/`, so the
build stays reproducible and works offline. Only `.spl` is shipped: the
companion `.sug` suggestion caches were dropped because `z=` derives
suggestions from the `.spl` itself and the Italian cache alone weighed 19
MB.

To add a language, drop its `.spl` next to the others and add the code to
`spell.languages`. Vim's git repository only publishes English under
`runtime/spell/`; every other language lives on the Vim FTP mirrors:

```bash
curl -fL -o spell/en.utf-8.spl \
  https://raw.githubusercontent.com/vim/vim/master/runtime/spell/en.utf-8.spl
curl -fL -o spell/it.utf-8.spl \
  https://ftp.nluug.nl/pub/vim/runtime/spell/it.utf-8.spl

head -c 8 spell/it.utf-8.spl   # a valid file starts with VIMspell
```

Keep the `-f`: without it a 404 is written into the file as an HTML error
page and Neovim fails with `E757: This does not look like a spell file`.

### Search and replace across the project

Telescope finds; [spectre](https://github.com/nvim-pack/nvim-spectre) finds
*and* rewrites. It walks the tree from the current directory down, so every
subfolder is included, and it edits every file in one go.

Three ways in — `<leader>S` opens it empty, `<leader>sR` starts from the
word under the cursor (or, in visual mode, from the selection), and
`<leader>sF` restricts the search to the current file. `:Spectre` does the
same as the first.

The panel has three editable lines at the top: what to search, what to
replace it with, and a glob to narrow the files. Results refresh as you
type. Then:

| Key | Action |
| --- | ------ |
| `<leader>R` | Replace everywhere |
| `<leader>rc` | Replace only the match under the cursor |
| `dd` | Exclude a match from the replacement |
| `<CR>` | Jump to the file |
| `<leader>q` | Send every result to the quickfix list |
| `ti` | Toggle case sensitivity |
| `th` | Include hidden files |
| `?` | Full help |

Patterns are ripgrep regexes: `\bword\b` matches whole words only,
`(foo|bar)` alternates, and `$1` refers to a capture group in the
replacement.

Two things worth knowing. The search obeys `.gitignore` and skips hidden
files, which is ripgrep's behaviour and the usual reason a match seems to
be missing — `th` widens it. And the replacement runs through `sed`, which
comes from the host rather than the build: where it is missing, `tro`
switches to the bundled `oxi` engine, which needs no external binary and
uses the same regex flavour as the search. `trs` switches back.

For renaming a symbol in code — a function, a variable, a Nix option —
prefer `<leader>rn`. It goes through the language server, so it renames
what is actually that symbol instead of every string that looks like it.

### Nothing loads until it is used

Every plugin declares a trigger — a filetype, a command, a keymap or an
event. Opening a Bash script does not load the Markdown renderer, and the
note-taking plugin stays out of the build entirely unless you set a vault
path.

`:LzeStatus` shows which plugins are installed and which are currently
loaded. `:LzeNix` shows what the Nix wrapper handed to the Lua side.

### It still works outside Nix

The Lua config degrades gracefully. Outside the wrapper, the Nix bridge is
replaced by a stub that returns defaults, so the config can be read and run
as an ordinary Neovim setup.

### The palette follows the desktop

The colours come from
[DankMaterialShell](https://github.com/AvengeMedia/DankLinux-Docs), the
Quickshell desktop suite whose dynamic theming is powered by `matugen` and
derives its palette from the wallpaper. `lua/core/palette.lua` reads
`dms-colors.json`, the file matugen regenerates on every wallpaper change,
and `lua/core/theme.lua` paints it on through `base16-nvim`.

That file is the one input deliberately **not** read from the Nix store: it
is looked up under `$XDG_CACHE_HOME`, or wherever
`settings.theme.colors_file` points. A filesystem watcher reloads it in
place, so changing the wallpaper recolours an editor that is already open,
with no restart. Everything else stays pinned in the store; only the
palette is allowed to move.

`dms-colors.json` is matugen's canonical output, the one every
DankMaterialShell integration consumes, which is why it is preferred over
the colorscheme the shell also generates for Neovim: that one is written
from a per-editor template, expects a specific plugin, and has already
moved once.

The JSON names its colours after Material Design 3 roles —
`on_surface_variant`, `primary_fixed_dim` — which describe a place in a
phone UI rather than in an editor. `palette.lua` renames them once, so the
rest of the config only ever speaks of `fg`, `accent` and `muted`. When the
file is missing, a built-in palette takes over and the editor is still
readable.

### Reader themes

For long reading sessions `:ReaderLight` and `:ReaderDark` switch to
[Gruvbox](https://github.com/ellisonleao/gruvbox.nvim); `:ReaderOff` goes
back to the desktop palette, and `<leader>v` cycles light, dark, off. They
sit on top of the palette rather than replacing it: while a reader theme is
on, the palette watcher stands aside, and a wallpaper change is picked up
on the way out. Markdown keeps its look, headings in the accent colour and
emphasis halfway to the text, recoloured from Gruvbox by the same rules.
The page is the terminal's own background, set to Gruvbox's along with the
cursor, so it keeps the terminal's transparency and the frame around it
matches; both are handed back when nvim exits or is suspended. The theme
is global and lasts for the session only. The plugin is loaded on the
first call.

### Weight and what it is made of

The closure is 376 MB with the defaults, and two knobs move most of it.
Measured, not estimated — each figure is a real build compared against the
baseline:

| Turning on | Adds | Why |
| ---------- | ---: | --- |
| `markdown.images.enable` | 137 MB | image.nvim reaches imagemagick through `luajit-magick`, which pulls x265, librsvg, glib, libaom, libjxl |
| `startup.cowsay` | 60 MB | cowsay is a perl script, so it brings the interpreter |

The cow costs time as well as space: `fortune | cowsay` is a blocking
`io.popen` and perl takes ~33 ms to start, which is why the header is off
by default. Startup is ~76 ms with it off against ~113 ms with it on.

A note for anyone trying to trim further: removing `imagemagick` from the
package list saves **nothing**. It is not on the PATH that pulls it in but
the plugin, so the flag has to gate `image.nvim` itself.

What is left after that is mostly `nixd` — about 160 MB of closure, since
it links the Nix libraries and ICU. That is the cost of first-class Nix
support, which is the point of the editor.

## Options

Set these under `wrappers.airnvim.settings`.

| Option                 | Type | Default          | Effect                                              |
| ---------------------- | ---- | ---------------- | --------------------------------------------------- |
| `ai.enable`            | bool | `false`          | In-editor AI chat (CodeCompanion)                   |
| `ai.adapter`           | str  | `"copilot"`      | Which model backend to talk to                      |
| `obsidian.enable`      | bool | `true`           | Note taking with obsidian.nvim                      |
| `obsidian.vault`       | str  | `""`             | Vault path; empty keeps the plugin out of the build |
| `markdown.line_length` | int  | `75`             | Wrap column and the MD013 limit                     |
| `markdown.images.enable` | bool | `true`         | Inline images; `false` saves 137 MB                 |
| `markdown.images.max_height` | int | `80`        | Image height cap, % of the window                   |
| `markdown.images.paste_width` | str | `"15cm"`   | `{ width=... }` on pasted images, for the PDF       |
| `spell.enable`         | bool | `true`           | Whether `:SpellToggle` may turn spell on            |
| `spell.languages`      | list | `[ "it" "en" ]`  | Dictionaries to check against                       |
| `spell.filetypes`      | list | `[ "markdown" ]` | Where `:SpellToggle` works                          |
| `theme.colors_file`    | str  | `""`             | Palette path; empty looks it up under XDG cache     |
| `mouse.scroll_lines`   | int  | `5`              | Lines per mouse wheel step                          |
| `oil.preview`          | bool | `false`          | Open oil's file preview together with the list      |
| `oil.width`            | int  | `75`             | Oil window width, % of the editor                   |
| `nerd_font.enable`     | bool | `true`           | Set to `false` if your font has no icon glyphs      |
| `langs.python.enable`  | bool | `false`          | Python LSP, linter and formatter (ruff)             |
| `langs.web.enable`     | bool | `false`          | ts/js and html servers; ~225 MB of node             |
| `langs.web.formatter.enable` | bool | `false`    | biome formats ts/js, html, css, json; ~64 MB        |
| `startup.cowsay`       | bool | `false`          | Dashboard header from `fortune \| cowsay`           |
| `render-backend`       | enum | `"kitty"`        | Image backend: `kitty` or `ueberzug`                |
| `open.*`               | str  | `""`             | External programs, see below                        |

### External programs

`vim.ui.open` is what Neovim calls to hand a file or URL to another program
— `gx`, markdown links, `gx` inside oil. Every handler defaults to empty,
which leaves Neovim's own behaviour in place: it falls back to `xdg-open`
and your desktop associations decide.

Override only what you want:

```nix
settings.open = {
  browser = "firefox";
  pdf     = "zathura";
  image   = "imv";
  video   = "mpv";

  # A directory needs both: xdg-open can reach a graphical file
  # manager but never a terminal one.
  terminal    = "wezterm start --";
  filemanager = "yazi";
};
```

### AI adapters

`ai.adapter` accepts any CodeCompanion adapter. They come in two kinds:

- **API key** — `anthropic`, `openai`, `gemini`, `deepseek`, `mistral`,
  `ollama` and others read a key from the environment.
- **Subscription** — `copilot`, `claude_code`, `gemini_cli`, `codex` and
  other ACP adapters reuse a CLI you have already signed into, so no API
  key is involved.

The default is `copilot`. No credential is stored in this repository.

## Keybindings

`<leader>` is `Space`; `<localleader>` is `\` (backslash).

| Key         | Mode    | Action                        |
| ----------- | ------- | ----------------------------- |
| `H` / `L`   | n, x, o | Start / end of line           |
| `-`         | n       | Open oil in a floating window |
| `<leader>u` | n       | Toggle the undo tree          |
| `<leader>z` | n       | Toggle spell checking         |
| `<leader>v` | n       | Reader: light, dark, off      |

**Search** — `<leader>s` is the telescope prefix: `sf` files, `sg` grep,
`sw` word under cursor, `sb` buffers, `sh` help, `sk` keymaps, `sd`
diagnostics, `sr` resume, `s.` recent, `sn` config files. `<leader>/`
searches the current buffer, `<leader><leader>` lists buffers.

**Replace** — uppercase goes to spectre: `<leader>S` opens it empty, `sR`
starts from the word under the cursor or the visual selection, `sF` stays
in the current file. Inside the panel, `<leader>R` replaces everywhere,
`<leader>rc` only under the cursor, `dd` excludes a match and `?` shows the
rest. See [Search and replace across the
project](#search-and-replace-across-the-project).

**Git** — `<leader>gg` lazygit, `gd` open diffview, `gq` close it, `gh`
file history, `gc` commits, `gs` status, `gb` branches.

**LSP** (only in buffers with a server attached) — `gd` definition, `gD`
declaration, `gr` references, `gI` implementation, `K` hover, `<C-k>`
signature, `<leader>rn` rename, `<leader>ca` code actions, `<leader>e` show
diagnostic, `<leader>ds` document symbols, `<leader>ws` workspace symbols.

**Treesitter textobjects** — `am` / `im` function, `ac` / `ic` class, `as`
local scope. `<leader>ps` and `<leader>pS` swap parameters.

**Markdown** — in visual mode the selection can be wrapped in place:
`<C-b>` for `**bold**`, `<C-i>` for `*italic*` and ``<C-`>`` for `` `code`
``. For anything else, nvim-surround's `S` wraps a selection in any
delimiter.

Two terminal quirks worth knowing. `<C-i>` and `<Tab>` are the same byte,
so Tab italicises too. ``<C-`>`` is not an ASCII control code and only
reaches Neovim from terminals speaking the kitty keyboard protocol (kitty,
WezTerm, Ghostty, foot); anywhere else use `S`. `<C-[>` is deliberately
unmapped: it is byte-identical to Escape.

**Notes** (when a vault is set) — `<leader>o` is the obsidian prefix: `oo`
open, `on` new note, `os` search, `ob` backlinks, `ot` template, `od`
dailies.

**AI** (when enabled) — `<C-s>` actions, `<leader>a` toggle chat, `ga` in
visual adds the selection to the chat.

## Layout

```text
flake.nix            # inputs and outputs
module.nix           # feature flags, plugins, packages
init.lua             # bootstrap: lze handlers, spec loading

lua/core/            # options, keymaps, autocmds, markdown wrap and
                     # links, save pipeline, spell, theme, reader
                     # themes, paths
lua/plugins/         # one file per area, each returning lze specs
lua/tools/           # user commands: external open, lze debugging,
                     # guides, markdown preview and paste, :MdFormatDir

guides/              # :MdGuide and :NvCheat pages
queries/             # Treesitter query overrides
spell/               # binary .spl dictionaries, checked in
selene.toml          # lua lint config; vim.toml holds its std
```

Adding a plugin takes two steps: declare it in `module.nix` so Nix builds
it, then write its spec in `lua/plugins/`.

## Development

```sh
nix build                                  # build the package
nix run                                    # launch the editor
nix flake check
nix flake update                           # refresh the lockfile

selene init.lua lua/                       # lint lua
nixfmt module.nix flake.nix                # format nix
nix path-info --closure-size -h .#default  # measure the build
```

Flakes only copy git-tracked files into the store, so **run `git add`
before rebuilding after creating a file** — otherwise the new module is
missing from the package and the editor starts with `module '...' not
found`.

## Notes

- Some binaries deliberately come from the host rather than the build:
  `git`, and whatever you point the `open.*` handlers at.
- The palette is read from the desktop at runtime rather than pinned in the
  store — see [The palette follows the
  desktop](#the-palette-follows-the-desktop).
- `exrc` is on, so project-local `.nvim.lua` files are executed.
- The clipboard is synced with the system via `unnamedplus`.
- Three plugins are patched at build time in `module.nix`: live-preview (a
  nested event loop froze the editor), image.nvim (one full re-scan of the
  document per edit made a big save take minutes) and render-markdown (to
  pass the buffer to the heading numbers). Each patch uses
  `--replace-fail`, so a plugin update that changes the patched code breaks
  the build instead of silently dropping the fix.

## License

Apache 2.0. See [LICENSE](LICENSE).
