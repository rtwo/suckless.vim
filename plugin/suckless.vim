"|
"| File          : ~/.vim/plugin/suckless.vim
"| Project page  : https://github.com/fabi1cazenave/suckless.vim
"| Author        : Fabien Cazenave
"| Licence       : WTFPL
"|
"| Tiling window management that sucks less - see http://suckless.org/
"| This emulates wmii/i3 in Vim as much as possible.
"|

" Preferences: window resizing
let g:SucklessMinWidth = 24       " minimum window width
let g:SucklessIncWidth = 12       " width increment
let g:SucklessIncHeight = 6       " height increment

" Preferences: wrap-around modes for window selection
let g:SucklessWrapAroundJK = 1    " 0 = no wrap
                                  " 1 = wrap in current column (wmii-like)
                                  " 2 = wrap in current tab    (dwm-like)
let g:SucklessWrapAroundHL = 1    " 0 = no wrap
                                  " 1 = wrap in current tab    (wmii-like)
                                  " 2 = wrap in all tabs

" in gVim, Alt sets the 8th bit; otherwise, assume the terminal is 8-bit clean
if !exists("g:MetaSendsEscape")
  let g:MetaSendsEscape = !has("gui_running")
endif

"|============================================================================
"|    Tabs / views: organize windows in tabs                               <<<
"|============================================================================

" Tab line in Vim <<<
set tabline=%!SucklessTabLine()

function! SucklessTabLine()
  let line = ''
  for i in range(tabpagenr('$'))
    " select the highlighting
    if i+1 == tabpagenr()
      let line .= '%#TabLineSel#'
    else
      let line .= '%#TabLine#'
    endif

    " set the tab page number (for mouse clicks)
    let line .= '%' . (i+1) . 'T'
    let line .= ' [' . (i+1)

    " modified since the last save?
    let buflist = tabpagebuflist(i+1)
    for bufnr in buflist
      if getbufvar(bufnr, '&modified')
        let line .= '*'
        break
      endif
    endfor
    let line .= ']'

    " add the file name without path information
    let buf = buflist[tabpagewinnr(i+1) - 1]
    let name = bufname(buf)
    if getbufvar(buf, '&modified') == 1
      let name .= " +"
    endif
    let line .= fnamemodify(name, ':t') . ' '
  endfor

  " after the last tab fill with TabLineFill and reset tab page nr
  let line .= '%#TabLineFill#%T'

  " right-align the label to close the current tab page
  if tabpagenr('$') > 1
    let line .= '%=%#TabLine#%999X X'
  endif
  "echomsg 's:' . s
  return line
endfunction

" SucklessTabLine >>>

" Tab labels in gVim <<<
set guitablabel=%{SucklessTabLabel()}

function! SucklessTabLabel()
  " see: http://blog.golden-ratio.net/2008/08/19/using-tabs-in-vim/

  " add the Tab number
  let label = '['.tabpagenr()

  " modified since the last save?
  let buflist = tabpagebuflist(v:lnum)
  for bufnr in buflist
    if getbufvar(bufnr, '&modified')
      let label .= '*'
      break
    endif
  endfor

  " count number of open windows in the Tab
  "let wincount = tabpagewinnr(v:lnum, '$')
  "if wincount > 1
    "let label .= ', '.wincount
  "endif
  let label .= '] '

  " add the file name without path information
  let name = bufname(buflist[tabpagewinnr(v:lnum) - 1])
  let label .= fnamemodify(name, ':t')
  if &modified == 1
    let label .= " +"
  endif

  return label
endfunction

" SucklessTabLabel >>>

" MoveToTab: move/copy current window to another tab <<<

function! MoveToTab(viewnr, copy)
  " get the current buffer ref
  let bufnr = bufnr("%")

  " remove current window if 'copy' isn't set
  if a:copy == 0
    wincmd c
  endif

  " get a window in the requested Tab
  if a:viewnr > tabpagenr('$')
    " the requested Tab doesn't exist, create it
    tablast
    tabnew
  else
    " select the requested Tab an add a window with the current buffer
    exe "tabn " . a:viewnr
    wincmd l
    " TODO: if the buffer is already displayed in this Tab, select its window
    " TODO: if this tab is in 'stacked' or 'fullscreen' mode, expand window
    " TODO: if there's already an empty window, reuse it
    wincmd n
  endif

  " display the current buffer
  exe "b" . bufnr
endfunction

" MoveToTab >>>

">>>

"|============================================================================
"|    Window tiles: selection, movement, resizing                          <<<
"|============================================================================

function! GetTilingMode(mode) "<<<
  if !exists("t:windowMode")
    let t:windowMode = a:mode
  endif
endfunction ">>>

function! SetTilingMode(mode) "<<<
  " apply new window mode
  if a:mode == "F"        " Fullscreen mode
    let t:windowSizes = winrestcmd()
    wincmd |              "   maximize current window vertically and horizontally
    wincmd _
  elseif a:mode == "D"    " Divided mode
    wincmd n              "   create a new window and delete it
    wincmd c
  elseif a:mode == "S"    " Stacked mode
    wincmd _              "   maximize current window vertically
  endif

  " when getting back from fullscreen mode, restore all minimum widths
  if t:windowMode == "F" && a:mode != "F"
    if exists("t:windowSizes")
      exe t:windowSizes
    else
      " store current window number
      let winnr = winnr()
      " check all columns
      wincmd t
      let tmpnr = 0
      while tmpnr != winnr()
        " restore min width if this column is collapsed
        if winwidth(0) < g:SucklessMinWidth
          exe "set winwidth=" . g:SucklessMinWidth
        endif
        " balance window heights in this column if switching to 'Divided' mode
        if a:mode == "D"
          wincmd n
          wincmd c
        endif
        " next column
        let tmpnr = winnr()
        wincmd l
      endwhile
      " select window #winnr
      exe winnr . "wincmd w"
    endif
  endif

  " store the new window mode in the current tab's global variables
  let t:windowMode = a:mode
endfunction ">>>

function! WindowCmd(cmd) "<<<

  " issue the corresponding 'wincmd'
  let winnr = winnr()
  exe "wincmd " . a:cmd

  " wrap around if needed
  if winnr() == winnr
    " vertical wrapping <<<
    if "jk" =~ a:cmd
      " wrap around in current column
      if g:SucklessWrapAroundJK == 1
        let tmpnr = -1
        while tmpnr != winnr()
          let tmpnr = winnr()
          if a:cmd == "j"
            wincmd k
          elseif a:cmd == "k"
            wincmd j
          endif
        endwhile
      " select next/previous window
      elseif g:SucklessWrapAroundJK == 2
        if a:cmd == "j"
          wincmd w
        elseif a:cmd == "k"
          wincmd W
        endif
      endif
    endif ">>>
    " horizontal wrapping <<<
    if "hl" =~ a:cmd
      " wrap around in current window
      if g:SucklessWrapAroundHL == 1
        let tmpnr = -1
        while tmpnr != winnr()
          let tmpnr = winnr()
          if a:cmd == "h"
            wincmd l
          elseif a:cmd == "l"
            wincmd h
          endif
        endwhile
      " select next/previous tab
      elseif g:SucklessWrapAroundHL == 2
        if a:cmd == "h"
          if tabpagenr() > 1
            tabprev
            wincmd b
          endif
        elseif a:cmd == "l"
          if tabpagenr() < tabpagenr('$')
            tabnext
            wincmd t
          endif
        endif
      endif
    endif ">>>
  endif

  " if the window height is modified, switch to divided mode
  if "+-" =~ a:cmd
    let t:windowMode = "D"
  endif

  " resize window according to the current window mode
  if t:windowMode == "F"
    " 'Fullscreen' mode
    wincmd _   " maximize window height
    wincmd |   " maximize window width
  elseif winheight(0) <= 1
    " window is collapsed, this column must be in 'stacked' mode
    wincmd _   " maximize window height
  endif

  " ensure the window width is greater or equal to the minimum
  if "hl" =~ a:cmd && winwidth(0) < g:SucklessMinWidth
    exe "set winwidth=" . g:SucklessMinWidth
  endif
endfunction ">>>

function! WindowMove(direction) "<<<
  let winnr = winnr()
  let bufnr = bufnr("%")

  if a:direction == "j"        " move window to the previous row
    wincmd j
    if winnr() != winnr
      "exe "normal <C-W><C-X>"
      wincmd k
      wincmd x
      wincmd j
    endif

  elseif a:direction == "k"    " move window to the next row
    wincmd k
    if winnr() != winnr
      wincmd x
    endif

  elseif "hl" =~ a:direction   " move window to the previous/next column
    exe "wincmd " . a:direction
    let newwinnr = winnr()
    if newwinnr == winnr
      " move window to a new column
      exe "wincmd " . toupper(a:direction)
    else
      " move window to an existing column
      wincmd p
      wincmd c
      if t:windowMode == "S"
        wincmd _ " maximize window height
      endif
      exe newwinnr . "wincmd w"
      wincmd n
      if t:windowMode == "S"
        wincmd _ " maximize window height
      endif
      exe "b" . bufnr
    endif

  endif
endfunction ">>>

function! WindowResize(direction) "<<<
  let winnr = winnr()

  if a:direction == "j"
    wincmd j
    if winnr() != winnr
      wincmd p
      "wincmd +
      exe g:SucklessIncHeight . "wincmd +"
    else
      "wincmd -
      exe g:SucklessIncHeight . "wincmd -"
    endif

  elseif a:direction == "k"
    wincmd j
    if winnr() != winnr
      wincmd p
      "wincmd -
      exe g:SucklessIncHeight . "wincmd -"
    else
      "wincmd +
      exe g:SucklessIncHeight . "wincmd +"
    endif

  elseif a:direction == "h"
    wincmd l
    if winnr() != winnr
      wincmd p
      "wincmd <
      exe g:SucklessIncHeight . "wincmd <"
    else
      "wincmd >
      exe g:SucklessIncHeight . "wincmd >"
    endif

  elseif a:direction == "l"
    wincmd l
    if winnr() != winnr
      wincmd p
      "wincmd >
      exe g:SucklessIncHeight . "wincmd >"
    else
      "wincmd <
      exe g:SucklessIncHeight . "wincmd <"
    endif

  endif
endfunction ">>>

function! WindowCollapse() "<<<
  "if t:windowMode == "D"
    res0
  "endif
endfunction ">>>

function! WindowClose() "<<<
  "exe "bd"
  wincmd c
  if t:windowMode == "S"
    wincmd _
  endif
endfunction ">>>

">>>

"|============================================================================
"|    keyboard mappings, Tab management                                    <<<
"|============================================================================

function! DefineWindowMappingsWith(pre, post)

" Alt+[hjkl]: select window <<<
  execute 'noremap <silent> ' . a:pre . 'h' . a:post . ' :call WindowCmd("h")<CR>'
  execute 'noremap <silent> ' . a:pre . 'j' . a:post . ' :call WindowCmd("j")<CR>'
  execute 'noremap <silent> ' . a:pre . 'k' . a:post . ' :call WindowCmd("k")<CR>'
  execute 'noremap <silent> ' . a:pre . 'l' . a:post . ' :call WindowCmd("l")<CR>'
">>>

" Alt+[HJKL]: move current window <<<

  " Todo, maybe we need to translate <A-H> to <S-A-h>, but I can't test this atm
  execute 'noremap <silent>  ' . a:pre . 'H' . a:post . ' :call WindowMove("h")<CR>'
  execute 'noremap <silent>  ' . a:pre . 'J' . a:post . ' :call WindowMove("j")<CR>'
  execute 'noremap <silent>  ' . a:pre . 'K' . a:post . ' :call WindowMove("k")<CR>'
  execute 'noremap <silent>  ' . a:pre . 'L' . a:post . ' :call WindowMove("l")<CR>'
">>>

" Alt+[0..9]: select Tab [1..10] <<<
  execute 'noremap <silent> ' . a:pre . '1' . a:post . ' :tabn  1<CR>'
  execute 'noremap <silent> ' . a:pre . '2' . a:post . ' :tabn  2<CR>'
  execute 'noremap <silent> ' . a:pre . '3' . a:post . ' :tabn  3<CR>'
  execute 'noremap <silent> ' . a:pre . '4' . a:post . ' :tabn  4<CR>'
  execute 'noremap <silent> ' . a:pre . '5' . a:post . ' :tabn  5<CR>'
  execute 'noremap <silent> ' . a:pre . '6' . a:post . ' :tabn  6<CR>'
  execute 'noremap <silent> ' . a:pre . '7' . a:post . ' :tabn  7<CR>'
  execute 'noremap <silent> ' . a:pre . '8' . a:post . ' :tabn  8<CR>'
  execute 'noremap <silent> ' . a:pre . '9' . a:post . ' :tabn  9<CR>'
  execute 'noremap <silent> ' . a:pre . '0' . a:post . ' :tabn 10<CR>'
">>>

" Alt+[sdf]: Window mode selection <<<
  execute 'noremap <silent> ' . a:pre . 's' . a:post . ' :call SetTilingMode("S")<CR>'
  execute 'noremap <silent> ' . a:pre . 'd' . a:post . ' :call SetTilingMode("D")<CR>'
  execute 'noremap <silent> ' . a:pre . 'f' . a:post . ' :call SetTilingMode("F")<CR>'
">>>

" Alt+[oO]: new horizontal/vertical window
" Alt+[cC]: collapse/close current window
  execute 'noremap <silent>  ' . a:pre . 'o' . a:post . ' :call WindowCmd("n")<CR>'
  "execute 'noremap <silent>  ' . a:pre . 'O' . a:post . ' :call WindowCmd("n")<CR>:call WindowMove("l")<CR>'
  execute 'noremap <silent>  ' . a:pre . 'c' . a:post . ' :call WindowCollapse()<CR>'
  execute 'noremap <silent>  ' . a:pre . 'C' . a:post . ' :call WindowCmd("c")<CR>'
">>>
endfunction

" Todo: Implement
call DefineWindowMappingsWith('<Esc>','')
call DefineWindowMappingsWith('<A-', '>')
call DefineWindowMappingsWith('<leader>','')

" <Leader>t[1..0]: move current window to Tab [1..10] <<<
noremap <silent> <Leader>t1 :call MoveToTab( 1,0)<CR>
noremap <silent> <Leader>t2 :call MoveToTab( 2,0)<CR>
noremap <silent> <Leader>t3 :call MoveToTab( 3,0)<CR>
noremap <silent> <Leader>t4 :call MoveToTab( 4,0)<CR>
noremap <silent> <Leader>t5 :call MoveToTab( 5,0)<CR>
noremap <silent> <Leader>t6 :call MoveToTab( 6,0)<CR>
noremap <silent> <Leader>t7 :call MoveToTab( 7,0)<CR>
noremap <silent> <Leader>t8 :call MoveToTab( 8,0)<CR>
noremap <silent> <Leader>t9 :call MoveToTab( 9,0)<CR>
noremap <silent> <Leader>t0 :call MoveToTab(10,0)<CR>
">>>

" <Leader>T[1..0]: copy current window to Tab [1..10] <<<
noremap <silent> <Leader>T1 :call MoveToTab( 1,1)<CR>
noremap <silent> <Leader>T2 :call MoveToTab( 2,1)<CR>
noremap <silent> <Leader>T3 :call MoveToTab( 3,1)<CR>
noremap <silent> <Leader>T4 :call MoveToTab( 4,1)<CR>
noremap <silent> <Leader>T5 :call MoveToTab( 5,1)<CR>
noremap <silent> <Leader>T6 :call MoveToTab( 6,1)<CR>
noremap <silent> <Leader>T7 :call MoveToTab( 7,1)<CR>
noremap <silent> <Leader>T8 :call MoveToTab( 8,1)<CR>
noremap <silent> <Leader>T9 :call MoveToTab( 9,1)<CR>
noremap <silent> <Leader>T0 :call MoveToTab(10,1)<CR>
">>>

">>>

"|============================================================================
"|    keyboard mappings, Window management                                 <<<
"|============================================================================

" Alt+[HJKL]: move current window <<<
if g:MetaSendsEscape

else
  noremap <silent> <S-A-h> :call WindowMove("h")<CR>
  noremap <silent> <S-A-j> :call WindowMove("j")<CR>
  noremap <silent> <S-A-k> :call WindowMove("k")<CR>
  noremap <silent> <S-A-l> :call WindowMove("l")<CR>
endif
">>>

" Ctrl+Alt+[hjkl]: resize current window <<<
if g:MetaSendsEscape
  noremap <silent> <Esc><C-h> :call WindowResize("h")<CR>
  noremap <silent> <Esc><C-j> :call WindowResize("j")<CR>
  noremap <silent> <Esc><C-k> :call WindowResize("k")<CR>
  noremap <silent> <Esc><C-l> :call WindowResize("l")<CR>
else
  noremap <silent>    <C-A-h> :call WindowResize("h")<CR>
  noremap <silent>    <C-A-j> :call WindowResize("j")<CR>
  noremap <silent>    <C-A-k> :call WindowResize("k")<CR>
  noremap <silent>    <C-A-l> :call WindowResize("l")<CR>
endif
">>>

">>>

"|============================================================================
"|    other mappings                                                       <<<
"|============================================================================

" Alt+[oO]: new horizontal/vertical window
" Alt+[cC]: collapse/close current window
if g:MetaSendsEscape

else
  noremap <silent>   <A-o> :call WindowCmd("n")<CR>
  "noremap <silent> <S-A-o> :call WindowCmd("n")<CR>:call WindowMove("l")<CR>
  noremap <silent>   <A-c> :call WindowCollapse()<CR>
  noremap <silent> <S-A-c> :call WindowCmd("c")<CR>
endif
">>>

"|============================================================================
"|    TODO (not working yet)                                               <<<
"|============================================================================

" tiling modes <<<
" Two modes should be possible:
"  * wmii: use as many columns as you want
"  *  dwm: one master window + one column for all other windows
"
" The wmii-mode is working properly, though there are a few difference with wmii:
"  * no 'maximized' mode (*sigh*)
"  * there's one stacking mode per tab, whereas wmii has one stacking mode per column.
"
" The dwm-mode would need some work to become usable:
"  * the master area should be able to have more than one window (ex: help)
"  * a specific event handler should prevent to create another column
"  * a specific column next to the master area (on the left) would be required
"    for other plugins such as project.tar.gz, ctags, etc.
"
" I think the wmii-mode makes much more sense for Vim anyway. ;-)
" >>>

" preferences <<<
" Preferences: key mappings to handle windows and tabs
" Warning, using <Alt-key> shortcuts is very handy but it can be tricky:
"  * may conflict with dwm/wmii - set the <Mod> key to <win> for your wm
"  * may conflict with gVim     - disable the menu to avoid this
"  * may raise problems in your terminal emulator (e.g. <A-s> on rxvt)
"  * Shift+Alt+number only works on the US-Qwerty keyboard layout
let g:SucklessWinKeyMappings = 3  " 0 = none - define your own!
                                  " 1 = <Leader> + key(s)
                                  " 2 = <Alt-key>
                                  " 3 = both
let g:SucklessTabKeyMappings = 3  " 0 = none - define your own!
                                  " 1 = <Leader> + key(s)
                                  " 2 = <Alt-key>
                                  " 3 = both
let g:SucklessTilingEmulation = 1 " 0 = none - define your own!
                                  " 1 = wmii-style (preferred)
                                  " 2 = dwm-style (not working yet)
" >>>

" Master window (dwm mode) <<<
function! WindowMaster()
  " swap from/to master area
  " get the current buffer ref
  let bufnr1 = bufnr("%")
  let winnr1 = winnr()

  wincmd l
  let bufnr2 = bufnr("%")
  let winnr2 = winnr()

  "if bufnr("%") != bufnr1
  if winnr1 != winnr2
    " we were in the master area
    exe "b" . bufnr1
    wincmd h
    exe "b" . bufnr2
    "" get back (cancel action)
    "wincmd p
  else
    " we were in the secondary area
    wincmd h
    let bufnr2 = bufnr("%")
    exe "b" . bufnr1
    wincmd p
    exe "b" . bufnr2
    wincmd h
  endif
endfunction ">>>

" 'Project' sidebar <<<
function! Sidebar()
  if g:loaded_project == 1 && (!exists('g:proj_running') || bufwinnr(g:proj_running) == -1)
    Project   " call Project if hidden
  elseif bufwinnr(winnr()) < 0
    wincmd p  " we're in the Sidebar, get back to the buffer window
  else
    wincmd t  " we're in a buffer window, go to the Project Sidebar
  endif
endfunction ">>>

" >>>

if has("autocmd")
  " source this file on save to apply all changes immediately
  "autocmd! bufwritepost suckless.vim source ~/.vim/plugin/suckless.vim
  " 'Divided' mode by default - each tab has its own window mode
  autocmd! TabEnter * call GetTilingMode("D")
endif
call GetTilingMode("D")

" vim: set fdm=marker fmr=<<<,>>> fdl=0:
