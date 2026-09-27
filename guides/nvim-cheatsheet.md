# Neovim Cheatsheet

Daily keys for Neovim and for what airnvim adds on top. Reopen this page
with `:NvCheat`, close it with `q`. The markdown syntax guide is
`:MdGuide`.

---

## How to read this sheet

- `^x` means hold `Ctrl` and press `x`
- `␣` is the space bar, the **leader key**. `␣sf` means: press `Space`,
  release it, then `s`, then `f`, one after the other. Plugins and the
  Neovim docs write it as `<leader>sf`; the local leader is `\`
- a number in front repeats a command: `5j` moves five lines down
- `m` stands for any motion, `c` for any character
- capital letters mean `Shift`: `G` is `Shift-g`
- `:` commands end with `Enter`
- airnvim's own commands start with a capital, and `Tab` completes them
  only from one: `:Md` then `Tab` lists `:MdGuide` and `:MdWrap`, while
  `:md` finds nothing. The full list is under airnvim commands below

---

## Modes

- `i` `a` insert before, after the cursor
- `I` `A` insert at the start, end of the line
- `o` `O` open a new line below, above
- `v` `V` `^v` visual: characters, lines, block
- `R` replace mode, overwrites as you type
- `:` command line
- `Esc` back to normal mode

---

## Movement

### Characters and words

- `h` `j` `k` `l` left, down, up, right
- `w` `b` start of next, previous word
- `e` `ge` end of next, previous word
- `W` `B` `E` the same, but words are split by spaces only
- `fc` `Fc` jump to the next, previous `c` on the line
- `tc` `Tc` jump to just before the next, previous `c`
- `;` `,` repeat the last `f` `t` forward, backward
- `%` jump to the matching bracket

### Lines

- `0` `^` `$` first column, first character, end of line
- `H` `L` start, end of line (airnvim; `dL` deletes to the end)
- `n|` column `n` of the line
- `nj` `nk` `n` lines down, up: the gutter shows relative numbers
- `gg` `G` first, last line
- `nG` or `:n` line `n`
- `{` `}` previous, next paragraph
- `(` `)` previous, next sentence

### Jumps

- `^o` `^i` back, forward through the places you jumped from
- `` `. `` where the last change was made
- `gi` back into insert mode where you last left it

### Scrolling

- `^d` `^u` half a page down, up
- `^f` `^b` a full page down, up
- `^e` `^y` one line down, up, the cursor stays
- `zz` `zt` `zb` put the cursor line at the centre, top, bottom
- mouse wheel: 5 lines per step, `settings.mouse.scroll_lines` in Nix

---

## Editing

### Operators

An operator waits for a motion or a text object: `dw` deletes a word, `y$`
copies to the end of the line, `gUiw` uppercases a word. Doubled, it works
on the whole line.

- `d` delete (cut)
- `c` change: delete, then insert
- `y` yank (copy)
- `>` `<` indent, dedent
- `=` reindent
- `gu` `gU` lowercase, uppercase
- `gq` rewrap to the text width
- `dd` `cc` `yy` delete, change, copy the whole line
- `D` `C` `Y` delete, change, copy to the end of the line

### Small edits

- `x` `X` delete the character under, before the cursor
- `rc` replace the character under the cursor with `c`
- `~` toggle the case of a character
- `J` join the line below onto this one
- `.` repeat the last change

### Text objects

Use them after an operator or in visual mode. `i` is inside, `a` includes
the surroundings.

- `iw` `aw` word
- `ip` `ap` paragraph
- `is` sentence
- `i"` `a"` inside, around quotes; also `'` and `` ` ``
- `i(` `a(` inside, around brackets; also `[`, `{` and `<`
- `it` `at` inside, around an HTML tag
- `im` `am` function (treesitter)
- `ic` `ac` class (treesitter)
- `as` local scope (treesitter; replaces "a sentence")

Examples: `ci"` rewrites a quoted string, `dap` deletes a paragraph, `yiw`
copies a word.

### Undo and redo

- `u` undo
- `^r` redo
- `U` undo every change on the last changed line
- `␣u` undo tree: every past state, even undone branches

### Copy and paste

- `p` `P` paste after, before the cursor
- `"ay` `"ap` copy into, paste from register `a`
- `:reg` all registers; `:reg a` register `a` only
- `^r"` paste the last copy while in insert mode

Every copy also lands in the system clipboard, and `p` pastes what you
copied in other programs.

### Macros

- `qa` start recording into register `a`
- `q` stop recording
- `@a` play it; `5@a` five times
- `@@` play the last macro again
- `qA` append to the macro in `a`
- `:@a` run register `a` as a `:` command

### Surround

- `ysiw"` surround a word with `"`; any motion works after `ys`
- `ds"` delete the surrounding `"`
- `cs"'` change the surrounding `"` into `'`
- `S"` in visual mode: surround the selection

### Comments

- `gcc` comment, uncomment the line
- `gc` with a motion or a selection: `gcap` comments a paragraph

### Completion (insert mode)

- `^n` `^p` next, previous suggestion
- `^y` or `Enter` accept
- `^e` close the menu
- `^Space` open the menu by hand
- `^d` `^u` scroll the documentation

---

## Markdown

### Emphasis (visual mode)

- `^b` wrap the selection in `**bold**`
- `^i` wrap it in `*italic*`; `Tab` does the same
- `` ^` `` wrap it in `` `code` ``; needs WezTerm, kitty or similar

They go through the clipboard: afterwards it holds the selected words.

### Images

- `␣ip` or `:PasteImage` paste the image in the clipboard: a popup asks for
  a name, the file is saved as `assets/YYYY-MM-DD_HH-MM-SS_name.png` next
  to the note, and the link is written for you. An empty name keeps the
  date only
- pasted links end in `{ width=15cm }`: the image width in the PDF, set by
  `settings.markdown.images.paste_width` in Nix
- images show inside the buffer, below their link, as wide as the text
- dropping an image file onto the terminal inserts a link to it

### Preview and layout

- `:PreviewMd` live preview in the browser, follows the cursor
- `:PreviewMd stop` end the preview
- `:MdWrap` rewrap every paragraph; saving does it too
- `:MdFormatDir` format every `.md` in the current file's directory as
  saving would, subdirectories excluded; see airnvim commands below
- `:RenderMarkdown toggle` show the raw text instead of the rendering

### Headings and folds

- `]]` `[[` next, previous heading
- `␣t` or `gO` table of contents: every heading, indented by level; `Enter`
  jumps to it, `:q` closes the list
- headings show as 1, 1.1, 1.1.1: the numbers are drawn, not written in the
  file, so a PDF export does not number them twice
- a number with a 0 in it (1.0.1) means a skipped level: the linter warns
  about it too, fix the number of `#` in the source
- `za` open or close the fold under the cursor
- `zc` `zo` close, open the fold under the cursor
- `zM` close every fold: only headings stay visible
- `zR` open every fold
- `zM` then `zo` on a heading: that heading and its subheadings

### Spelling

- `␣z` or `:SpellToggle` spell checking on, off (this buffer only)
- Italian and English are checked together: a word passes if either
  dictionary has it. Markdown files only; code is skipped
- it checks spelling, not grammar
- `]s` `[s` next, previous misspelled word
- `z=` suggestions for the word under the cursor
- `1z=` take the first suggestion straight away
- `zG` accept a word for this session

### Links

- `Enter` or `Ctrl`+click on a link: a note opens here, at its `#heading`
  if the link names one; a web address goes to the browser, other files to
  their program. `^o` comes back
- a link to a note that does not exist asks to create it, next to the note
  holding the link
- `␣il` insert a link: pick a note, `[](path.md)` is written with the
  cursor between the brackets for the text (`Esc` leaves it empty)
- `␣il` on a selection: the selected words become the link text
- `gx` open the link with the system program instead
- `gf` open the file whose name is under the cursor

---

## Search

### In the file

- `/text` `?text` search forward, backward
- `n` `N` next, previous match
- `*` `#` search the word under the cursor forward, backward
- `␣/` fuzzy search in the file, with a list of matches

### In the project

Search starts from the directory Neovim was opened in (`:pwd`).

- `␣sf` find a file by name
- `␣sg` search text in every file (live grep)
- `␣sw` search the word under the cursor
- `␣s.` recent files
- `␣sb` or `␣␣` open buffers
- `␣sh` help pages
- `␣sk` keymaps
- `␣sc` commands
- `␣sd` diagnostics
- `␣sr` reopen the last search
- `␣sn` airnvim's own config files
- `␣ss` every search picker

### Inside a search window

- `^n` `^p` or arrows move through the results
- `Enter` or `^y` open
- `^v` `^x` `^t` open in a vertical split, a split, a tab
- `^q` send every result to the quickfix list
- `Esc` `Esc` or `q` close

---

## Find and replace

### In the file

- `:s/old/new/` first match on the current line
- `:%s/old/new/g` every match in the file
- `:%s/old/new/gc` ask for each one: `y` yes, `n` no, `a` all, `q` quit
- `:'<,'>s/old/new/g` inside the selection: select, then press `:`
- `:'<,'>s/\%Vold/new/g` inside a block selection (`^v`) only
- `:%s/\<old\>/new/g` whole words only
- `:%s//new/g` reuse the last `/` search as the pattern
- `&` `g&` repeat the last replace on this line, on the whole file

### In every file of a directory

Spectre searches the current directory and all its subdirectories.

- `␣S` open Spectre: type the search, `Tab` to the replace field
- `␣sR` start from the word under the cursor, or the selection
- `␣sF` limit it to the current file
- `dd` in the results: leave that match out
- `␣rc` replace only the match under the cursor
- `␣R` replace everything listed
- `ti` `th` toggle ignore case, hidden files
- `Enter` open the file at that match

### With the quickfix list

- `␣sg`, type the search, then `^q` to collect the matches
- `:cfdo %s/old/new/gc | update` replace in every collected file
- `:cdo s/old/new/g | update` replace on the collected lines only
- `:copen` `:cclose` show, hide the list
- `]q` `[q` next, previous entry

---

## Files (Oil)

- `-` open the file explorer on the current file's directory

### Inside the explorer

- `-` or `Enter` open the file or enter the directory (forward)
- `.` go to the parent directory (back)
- `_` go to the directory Neovim was started in
- `^s` `^h` `^t` open in a vertical split, a split, a tab
- `^p` preview the file on the right, it follows the cursor; `^p` again
  closes it. Text files only, their first screenful of lines; the mouse
  wheel scrolls it. `settings.oil.preview` in Nix opens it by default
- the explorer width is `settings.oil.width` in Nix (a percentage)
- `g.` show, hide hidden files
- `gx` open with the system program
- `g?` every explorer key
- `^c` or `:q` close

### Edit the directory like text

- `i` then edit a name: rename
- `dd` delete a file
- `o` then a name: new file; a name ending in `/` makes a directory
- `dd` here and `p` elsewhere: move; `yy` and `p`: copy
- `:w` apply the changes, after a confirmation

---

## Windows, tabs and buffers

### Windows

- `^wv` or `:vsplit` split vertically
- `^ws` or `:split` split horizontally
- `^wh` `^wj` `^wk` `^wl` move to the window left, below, above, right
- `^ww` cycle through the windows
- `^wq` close this window; `^wo` close all the others
- `^w=` make every window the same size
- `^w>` `^w<` wider, narrower; `10^w>` ten columns at once
- `^w+` `^w-` taller, shorter

### Tabs

- `:tabnew` new tab
- `gt` `gT` next, previous tab; `2gt` tab number 2
- `:tabclose` close the tab

### Buffers and files

- `:e path` open a file
- `]b` `[b` next, previous buffer
- `:bd` close the buffer
- `:w` save; `:wa` save all
- `:q` quit; `:qa` quit all
- `:wq` or `ZZ` save and quit
- `:q!` or `ZQ` quit and discard the changes

---

## Code

These work when a language server is attached (Nix, Lua, Markdown).

- `gd` go to the definition
- `gD` go to the declaration
- `gr` list the references
- `gI` go to the implementation
- `K` documentation of the word under the cursor
- `^k` signature help
- `␣D` type definition
- `␣ds` `␣ws` symbols in the file, in the workspace
- `␣rn` rename everywhere
- `␣ca` code actions, with a preview
- `␣e` show the diagnostic under the cursor
- `]d` `[d` next, previous diagnostic
- `:Format` format the file; saving formats too

---

## Git

- `␣gg` LazyGit
- `␣gd` open the diff view; `␣gq` close it
- `␣gh` history of the current file
- `␣gc` commits
- `␣gs` changed files
- `␣gb` branches

---

## Notes (Obsidian)

Available when a vault is set in Nix.

- `␣oo` open a note; `␣os` search the notes
- `␣on` new note; `␣ot` insert a template
- `␣ob` backlinks; `␣ol` links in this note; `␣otg` tags
- `␣od` daily notes; `␣odtd` `␣ody` `␣odtm` today, yesterday, tomorrow
- `␣orn` rename the note and fix its links
- `␣opi` paste an image into the vault
- `␣og` open in the Obsidian app; `␣ow` switch vault
- `gf` follow the link under the cursor
- `␣ol` in visual mode: link the selection to a note
- `␣onl` in visual mode: new note from the selection

---

## AI

Available when `settings.ai.enable` is on.

- `␣a` open, close the chat
- `^s` actions menu
- `ga` in visual mode: add the selection to the chat

---

## airnvim commands

Type the capital: `:Md` then `Tab` completes, `:md` does not. `␣sc`
searches every command, these included.

- `:NvCheat` this cheatsheet
- `:MdGuide` the markdown syntax guide
- `:SpellToggle` spell checking on, off; `␣z` does the same
- `:MdWrap` rewrap every paragraph of a markdown file
- `:MdFormatDir` format every `.md` in a directory, like saving each one:
  - no argument: the current file's directory, or the one Oil shows
  - `:MdFormatDir path` another directory; `Tab` completes it
  - asks first; only files that change are written
  - subdirectories are left alone
  - a file open with unsaved changes is skipped
  - a bar shows the progress; `q` stops after the current file
- `:PreviewMd` browser preview; `:PreviewMd stop` ends it
- `:PasteImage` paste the clipboard image; `␣ip` does the same
- `:LzeStatus` installed plugins and whether they are loaded
- `:LzeNix` plugins provided by Nix

---

## Miscellaneous

- `:!cmd` run a shell command; `:r !cmd` insert its output
- `␣z` spell checking, see Markdown above
- `:help topic` or `␣sh` the manual
- `:checkhealth` diagnose problems
- start screen: `n` new file, `f` find file, `g` find word, `r` recent, `s`
  settings, `q` quit

---

## Advanced commands

Everything above is the daily set. What follows completes it: the rest of
the classic Vim reference card, checked against this editor. `:help`
followed by any key or command explains it in full.

### More movement

- `M` middle of the window. Vim's `H` and `L` (top, bottom of the window)
  are taken by airnvim for start and end of line
- `-` `+` or `Enter` previous, next line, on its first character
- `gE` end of the previous space-separated word
- `g0` `gm` `g^` `g$` start, middle, first character, end of the screen
  line (useful with long wrapped lines)
- `gj` `gk` down, up one screen line instead of one file line
- `ngg` line `n`, like `nG`

### Insert and replace

- `gI` insert in the first column, before any indentation
- `S` change the whole line, like `cc`
- `gR` replace mode that respects tabs and layout
- `ga` show the code of the character under the cursor; `g8` its bytes

### Keys in insert mode

With the completion menu open, `^n` `^p` `^y` `^e` `^d` `^u` act on the
menu; with it closed they do what is listed here.

- `^w` delete the word before the cursor
- `^u` delete everything typed on this line
- `^t` `^d` indent, dedent the line by one step
- `^r` then `a` paste register `a`; `^r` `^r` `a` literally
- `^a` insert the text typed in the last insert
- `^@` the same, then leave insert mode
- `^o` then a command: run one normal-mode command, then back
- `^v` then a key: insert it literally (`^v` `Tab` a real tab)
- `^v` `u` and a hex code: a unicode character (`^vu00e8` is è)
- `^k` and two characters: a digraph (`^k` `e` `:` is ë); `:digraphs` lists
  them
- `^x` `^e` `^x` `^y` scroll the window, the cursor stays
- `^[` same as `Esc`

### Completion in insert mode

- `^x` `^l` whole lines from this file
- `^x` `^n` `^x` `^p` words from this file
- `^x` `^i` words from this file and the files it includes
- `^x` `^f` file names
- `^x` `^o` smart completion from the language server
- `^x` `^v` command-line words
- `^x` `s` spelling suggestions, when spell checking is on
- `^x` `^]` tags

### Visual mode

- `o` jump to the other end of the selection
- `gv` select the last selection again
- `ab` `aB` a block in `( )`, in `{ }`; `ib` `iB` its inside
- `J` `gJ` join the selected lines, with, without spaces
- `u` `U` `~` lowercase, uppercase, toggle case
- `^a` `^x` add, subtract 1 in every selected line; `g^a` counts up
- `:` then a command: run it on the selected lines (`:'<,'>`)

### Deleting, copying, pasting

- `gJ` join lines without adding a space
- `:5,10d` delete lines 5 to 10; `:5,10d a` into register `a`
- `:5,10y` copy lines 5 to 10
- `]p` `[p` paste after, before, matching the current indentation
- `gp` `gP` paste, leaving the cursor after the pasted text
- `"_d` delete without touching the clipboard (the black hole)
- `"0p` paste the last copy, even after deleting something else
- `"+y` `"+p` explicit system clipboard (already the default here)
- `:put a` paste register `a` on a line of its own

### Repeating and counting

- `n.` repeat the last change `n` times
- `^a` `^x` add, subtract 1 from the number under the cursor
- `g^g` count words, characters and lines (whole file or selection)
- `^g` file name and position

### Case

- `g~` with a motion: toggle case (`g~iw` a word)
- `gu` `gU` with a motion; `guu` `gUU` the whole line

### Search, more

- `/text/e` put the cursor at the end of the match; `/text/+1` on the line
  after it
- `/` `Enter` repeat the last search forward; `?` `Enter` backward
- `g*` `g#` like `*` `#`, matching inside longer words too
- `gd` `gD` local, global declaration of the word under the cursor; with a
  language server attached they go to its definition instead
- `^l` clear the search highlight and redraw the screen
- `:noh` clear the search highlight only
- `:set hlsearch!` highlight every match on, off

### Patterns (regular expressions)

In `/` and `:s`. Vim's syntax differs from Perl's: `\v` at the start makes
it close to Perl, with `()`, `+`, `?`, `{}` and `|` unescaped.

- `.` any character; `\_.` any character, line breaks included
- `^` `$` start, end of line
- `\<` `\>` start, end of a word
- `*` `\+` `\=` zero or more, one or more, zero or one
- `\{2,4}` two to four times; `\{-}` as few as possible
- `\|` or: `cat\|dog`
- `\(` `\)` a group; `\%(` `\)` a group that is not captured
- `[abc]` `[^abc]` `[a-z]` one of, none of, a range
- `\d` `\s` `\w` digit, space, word character; capitals negate
- `\a` `\l` `\u` letter, lowercase, uppercase letter
- `\c` `\C` ignore, respect case for this search
- `\zs` `\ze` the match starts, ends here: `foo\zsbar` finds `bar`
- `\(foo\)\@<=bar` `bar` after `foo`; `foo\(bar\)\@=` `foo` before `bar`;
  `\@<!` `\@!` the same, negated
- `\%V` inside the visual selection; `\%^` `\%$` start, end of file
- `\%23l` on line 23; `\%>5l` after line 5
- `\n` a line break; `\t` a tab; `\e` escape; `\r` carriage return
- `\%x41` the character with hex code 41
- `\i` `\k` `\f` `\p` identifier, keyword, file-name, printable character;
  the capitals exclude digits
- `\1` in the pattern: group 1 again (`\(\a\)\1` finds doubled letters)
- `\&` both sides must match at the same place
- `\@>` take the group whole, never give part of it back
- `\_^` `\_$` start, end of line anywhere in the pattern
- `\_[a-z]` a class that also matches a line break
- `\%[abc]` optional sequence: `fu\%[nction]` finds fu, fun, func…
- `\%'a` at the position of mark `a`

### Substitute, more

- `&` in the replacement: the whole match; `\1` `\2` the groups
- `\u` `\l` next character upper, lower; `\U` `\L` until `\E`
- `\r` in the replacement: a line break
- `:s/\n//` join lines (a line break is matched as `\n`)
- `:%s/x/y/gi` ignore case; `n` only count the matches
- `:%s//~/` reuse the last replacement too
- `:5,10s/a/b/g` only on lines 5 to 10
- `:&&` repeat the last `:s` with its flags

### Global commands

- `:g/pat/d` delete every line matching `pat`
- `:v/pat/d` or `:g!/pat/d` delete every line not matching it
- `:g/pat/normal Ax` run normal-mode keys on each matching line
- `:g/pat/m0` move the matching lines to the top (reversed)
- `:g/^$/d` delete empty lines

### Line ranges

- `:5` `:$` line 5, the last line; `.` the current line
- `:5,10` `:.,+3` lines 5 to 10, this line and the next three
- `:%` the whole file; `:'<,'>` the visual selection
- `:'a,'b` from mark `a` to mark `b`
- `:/foo/,/bar/` from the next `foo` to the next `bar`; `?foo?` searches
  backward
- `;` instead of `,` sets the cursor on the first line before reading the
  second

### Moving and copying lines

- `:m +1` `:m -2` move this line down, up; `:m 0` to the top
- `:t .` duplicate this line; `:5,10t $` copy lines 5-10 to the end
- `:'<,'>m 20` move the selection after line 20

### Formatting and filtering

- `gqq` `gqap` rewrap the line, the paragraph; `gw` the same, the cursor
  stays
- `:center` `:left` `:right` align lines (`:center 75`)
- `>>` `<<` indent, dedent the line; `5>>` five lines
- `!` with a motion, then a command: filter text through it (`!ip sort`
  sorts a paragraph)
- `!!cmd` filter the current line
- `:%!sort` `:%!sort -u` sort the file, removing duplicates
- `:sort` `:sort u` `:sort n` sort lines, unique, numeric

### Marks and jumps

- `ma` set mark `a` in this file; `mA` a mark valid across files
- `` `a `` go to mark `a`; `'a` to the start of its line
- ``` `` ``` or `''` back to where the last jump started
- `` `" `` where the cursor was when the file was last closed
- `` `[ `` `` `] `` start, end of the last changed or copied text
- `` `^ `` where insert mode was last left
- `'0` the position of the last session's last file
- `:marks` list the marks; `:delmarks a` delete one
- `:jumps` the jump list; `:changes` the change list
- `g;` `g,` older, newer change position

### Tags and help links

- `^]` follow the link or tag under the cursor (in `:help` too)
- `^t` go back
- `:ts name` pick among matching tags; `:tj name` jump if only one
- `:tags` the stack of tags jumped through

### Buffers

- `:ls` or `:buffers` list the open buffers
- `:b 3` or `:b name` switch to buffer 3, to a buffer by name
- `:badd file` load a file into a buffer without showing it
- `:bd 3` close buffer 3
- `:bfirst` `:blast` first, last buffer
- `:e #` or `^^` the alternate (previous) buffer
- `:tab ball` every buffer in its own tab

### Windows, more

- `:new` `:vnew` a new empty window, below, beside
- `:only` keep only this window
- `^w` `W` previous window
- `^w` `_` `^w` `|` maximise height, width
- `^w` `H` `J` `K` `L` move the window to the left, bottom, top, right
- `^w` `r` rotate the windows; `^w` `x` swap with the next one
- `^w` `T` move the window to a new tab
- `zh` `zl` scroll one column left, right (without line wrap)
- `zH` `zL` half a screen left, right

### Folds, more

Folds follow the syntax tree here (`foldmethod=expr`): `zf` `zd` `zE` only
work after `:set fdm=manual` or `:set fdm=marker`.

- `zO` `zC` open, close the fold and every fold inside it
- `zA` toggle it recursively; `zv` open just enough to see the cursor
- `zm` `zr` fold one level more, less
- `zj` `zk` move to the next, previous fold
- `[z` `]z` start, end of the open fold
- `zn` `zN` `zi` no folds, folds back, toggle folding
- `zf` with a motion: create a fold; `zd` delete it; `zE` delete all
- `:5,10fold` fold lines 5 to 10 (manual folds too)
- `:set fdm=indent` fold by indentation instead
- `:set foldcolumn=2` show the folds in a side column

### Spelling, more

Turn it on with `␣z` first.

- `zg` add the word to your personal list; `zw` mark it wrong
- `zug` `zuw` undo either
- `zG` `zW` the same, for this session only
- `z=` suggestions; `1z=` the first one

### Files and commands

- `:e` reload the file; `:e!` reload, discarding the changes
- `:x` save if changed, then quit (like `ZZ`)
- `:w file` save as; `:5,10w file` save lines 5 to 10 to a file
- `:5,10w >> file` append them to a file
- `:r file` insert a file below the cursor
- `:saveas file` save under a new name and keep editing it
- `:help holy-grail` every `:` command
- `:viusage` a summary of every normal-mode command
- `K` without a language server: the man page of the word
- Vim's `:hardcopy` does not exist in Neovim: print through the PDF export

### Build and errors

- `:make` run the project's build, collect the errors
- `:compiler name` choose how errors are read (`:compiler tsc`)
- `:copen` the list; `:cn` `:cp` next, previous error
- `:cl` list the errors; `:cf file` read errors from a file

### Terminal

Vim's `:sh` does not exist in Neovim: a terminal runs in a window.

- `:terminal` or `:term` open a shell in a window
- `i` start typing in it; `^\` `^n` back to normal mode
- `:split | term` a terminal in a split below

### Options and views

- `:set list` show tabs and trailing spaces
- `:set cuc` highlight the cursor column
- `:set nu!` `:set rnu!` line numbers, relative numbers on, off
- `:set wrap!` line wrap on, off
- `:set ff=unix` `:set ff=dos` line endings; `:e ++ff=dos` reread
- `:set option?` show a value; `:set option&` back to the default
- `:mkview` `:loadview` save, restore folds and cursor of a file
- `^l` redraw the screen
