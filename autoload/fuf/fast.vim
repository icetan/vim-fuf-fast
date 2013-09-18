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
  "let s:cache = {}
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
  if has('unix')
    if empty(a:exclude)
      return 'find ' . a:dir
    else
      if s:OS ==# 'mac'
        return 'find -E ' . a:dir . ' ! -regex ".*(' . a:exclude . ').*"'
      elseif s:OS ==# 'linux'
        return 'find ' . a:dir . ' -regextype posix-extended ! -regex ".*(' . a:exclude . ').*"'
      endif
    endif
  "elseif s:OS =~ 'win'
  "  return 'dir ' . a:dir
  endif
  echoerr 'No find command for OS.'
  throw
endfunction

" returns list of paths.
function s:find(expr, exclude)
  let exp = substitute(a:expr, '\', '/', 'g')
  if empty(exp)
    let exp = '*'
  elseif exp !=# '/'
    let exp = '"' . substitute(exp, '/*$', '', 'g') . '"'
  endif
  let cmd_ = s:getOSFind(exp, a:exclude)
  echom cmd_
  let res = system(cmd_)
  if v:shell_error
    echoerr 'Shell error when executing find.'
    return []
  endif
  return split(res, '\n')
endfunction

"
function s:enumExpandedDirsEntries(dir, exclude)
  let entries = s:find(a:dir, a:exclude)
  " removes "*/." and "*/.."
  " XXX: do we need this?
  "call filter(entries, 'v:val !~ ''\v(^|[/\\])\.\.?$''')
  call map(entries, 'fuf#makePathItem(v:val, "", 1)')
  " TODO: exclude in fast command
  "if len(a:exclude)
  "  call filter(entries, 'v:val.word !~ a:exclude')
  "endif
  return entries
endfunction

"
function s:enumItems(dir)

  " No cache
  let tmp = s:enumExpandedDirsEntries(a:dir, g:fuf_file_exclude)
  call fuf#mapToSetSerialIndex(tmp, 1)
  call fuf#mapToSetAbbrWithSnippedWordAsPath(tmp)
  return tmp

  " With cache
  "let key = join([getcwd(), g:fuf_ignoreCase, g:fuf_file_exclude, a:dir], "\n")
  "if !exists('s:cache[key]')
  "  let s:cache[key] = s:enumExpandedDirsEntries(a:dir, g:fuf_file_exclude)
  "  call fuf#mapToSetSerialIndex(s:cache[key], 1)
  "  call fuf#mapToSetAbbrWithSnippedWordAsPath(s:cache[key])
  "endif
  "return s:cache[key]
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
