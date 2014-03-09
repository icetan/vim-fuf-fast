"=============================================================================
" Copyright (c) 2013
"
" This file is based on fuf/file.vim
"
" Place this file in autoload/fuf/ and add "call fuf#addMode('fast')" to your
" .vimrc
"
"=============================================================================
" LOAD GUARD {{{1

if !l9#guardScriptLoading(expand('<sfile>:p'), 0, 0, [])
  finish
endif

" }}}1
"=============================================================================
" GLOBAL VARIABLES {{{1

call l9#defineVariableDefault('g:fuf_fast_use_cache', 1)

" }}}1
"=============================================================================
" GLOBAL FUNCTIONS {{{1

"
function fuf#fast#createHandler(base)
  return a:base.concretize(copy(s:handler))
endfunction

"
function fuf#fast#getSwitchOrder()
  return g:fuf_file_switchOrder
endfunction

"
function fuf#fast#getEditableDataNames()
  return []
endfunction

"
function fuf#fast#renewCache()
  let s:cacheTime = {}
  let s:cache = {}
endfunction

"
function fuf#fast#requiresOnCommandPre()
  return 0
endfunction

"
function fuf#fast#onInit()
  call fuf#defineLaunchCommand('FufFast', s:MODE_NAME, '""', [])
  call fuf#defineLaunchCommand('FufFastWithFullCwd', s:MODE_NAME, 'fnamemodify(getcwd(), '':p'')', [])
  call fuf#defineLaunchCommand('FufFastWithCurrentBufferDir', s:MODE_NAME, 'expand(''%:~:.'')[:-1-len(expand(''%:~:.:t''))]', [])
endfunction

"
function g:fuf_fast_find(dir, exclude)
  return s:find(a:dir, a:exclude)
endfunction

" }}}1
"=============================================================================
" LOCAL FUNCTIONS/VARIABLES {{{1

let s:MODE_NAME = expand('<sfile>:t:r')

function s:getRunningOS()
  if has('win32') || has ('win64')
    return 'win'
  endif
  if has('unix')
    if system('uname')=~'Darwin'
      return 'mac'
    else
      return 'linux'
    endif
  endif
endfunction

let s:OS = s:getRunningOS()

function s:getOSFind(dir, exclude)
  let cmd_ = ''
  if has('unix')
    if empty(a:exclude)
      let cmd_ = 'find {}'
    else
      if s:OS ==# 'mac'
        let cmd_ = 'find -E {} ! -regex ".*(' . a:exclude . ').*"'
      elseif s:OS ==# 'linux'
        let cmd_ = 'find {} -regextype posix-extended ! -regex ".*(' . a:exclude . ').*"'
      endif
    endif

    if empty(a:dir)
      " TODO: clean this workaround for avoiding "./" prefix in result.
      let cmd_ = 'ls -A1 | xargs -L1 -I{} ' . cmd_
    else
      let dir = substitute(a:dir, '\', '/', 'g')
      if dir !=# '/'
        let dir = '"' . substitute(dir, '/*$', '', 'g') . '"'
      endif
      let cmd_ = substitute(cmd_, '{}', dir, '')
    endif
  "elseif s:OS ==# 'win'
  "  return 'dir ' . a:dir
  endif
  return cmd_
endfunction

function s:changed(dir, exclude, since)
  let dir = empty(a:dir) ? '.' : a:dir
  if has('unix')
    let cmd_ = s:getOSFind(dir, a:exclude) . ' -type d -ctime -' . a:since . 's'
    return !empty(system(cmd_))
  "elseif s:OS ==# 'win'
  "  return 'dir ' . a:dir
  endif
  return 1
endfunction

" returns list of paths.
function s:find(expr, exclude)
  let cmd_ = s:getOSFind(a:expr, a:exclude)
  if empty(cmd_)
    " Fallback to internal glob function.
    let entries = fuf#glob(a:expr . '*') + fuf#glob(a:expr . '.*')
    " removes "*/." and "*/.."
    call filter(entries, 'v:val !~ ''\v(^|[/\\])\.\.?$''')
    if !empty(a:exclude)
      call filter(entries, 'v:val !~ a:exclude')
    endif
    return entries
  else
    let res = system(cmd_)
    if v:shell_error
      echoerr 'Shell error when executing find.'
      return []
    endif
    return split(res, '\n')
  endif
endfunction

"
function s:enumExpandedDirsEntries(dir, exclude)
  let entries = s:find(a:dir, a:exclude)
  call map(entries, 'fuf#makePathItem(v:val, "", 1)')
  return entries
endfunction

"
function s:enumItems(dir)
  if g:fuf_fast_use_cache
    " With cache
    let key = join([getcwd(), g:fuf_ignoreCase, g:fuf_file_exclude, a:dir], "\n")
    let curtime = strftime('%s')
    if has_key(s:cacheTime, key) && s:changed(a:dir, '', curtime - s:cacheTime[key])
      " Reset cache if changes to subdir's have been made since last search.
      unlet s:cache[key]
    endif
    if !has_key(s:cache, key)
      let s:cacheTime[key] = curtime
      let s:cache[key] = s:enumExpandedDirsEntries(a:dir, g:fuf_file_exclude)
      call fuf#mapToSetSerialIndex(s:cache[key], 1)
      call fuf#mapToSetAbbrWithSnippedWordAsPath(s:cache[key])
    endif
    return s:cache[key]
  else
    " No cache
    let tmp = s:enumExpandedDirsEntries(a:dir, g:fuf_file_exclude)
    call fuf#mapToSetSerialIndex(tmp, 1)
    call fuf#mapToSetAbbrWithSnippedWordAsPath(tmp)
    return tmp
  endif
endfunction

"
function s:enumNonCurrentItems(dir, bufNrPrev, cache)
  let key = a:dir . 'AVOIDING EMPTY KEY'
  if !exists('a:cache[key]')
    " NOTE: Comparing filenames is faster than bufnr('^' . fname . '$')
    let bufNamePrev = bufname(a:bufNrPrev)
    let a:cache[key] =
          \ filter(copy(s:enumItems(a:dir)), 'v:val.word !=# bufNamePrev')
  endif
  return a:cache[key]
endfunction

" }}}1
"=============================================================================
" s:handler {{{1

let s:handler = {}

"
function s:handler.getModeName()
  return s:MODE_NAME
endfunction

"
function s:handler.getPrompt()
  return fuf#formatPrompt(g:fuf_file_prompt, self.partialMatching, '')
endfunction

"
function s:handler.getPreviewHeight()
  return g:fuf_previewHeight
endfunction

"
function s:handler.isOpenable(enteredPattern)
  return a:enteredPattern =~# '[^/\\]$'
endfunction

"
function s:handler.makePatternSet(patternBase)
  return fuf#makePatternSet(a:patternBase, 's:interpretPrimaryPatternForPathTail',
        \                   self.partialMatching)
endfunction

"
function s:handler.makePreviewLines(word, count)
  return fuf#makePreviewLinesForFile(a:word, a:count, self.getPreviewHeight())
endfunction

"
function s:handler.getCompleteItems(patternPrimary)
  return s:enumNonCurrentItems(
        \ fuf#splitPath(a:patternPrimary).head, self.bufNrPrev, self.cache)
endfunction

"
function s:handler.onOpen(word, mode)
  call fuf#openFile(a:word, a:mode, g:fuf_reuseWindow)
endfunction

"
function s:handler.onModeEnterPre()
endfunction

"
function s:handler.onModeEnterPost()
  let self.cache = {}
endfunction

"
function s:handler.onModeLeavePost(opened)
endfunction

" }}}1
"=============================================================================
" vim: set fdm=marker:
