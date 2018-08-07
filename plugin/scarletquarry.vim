if exists("g:loaded_scarletquarry") || v:version < 700 || &cp
    finish
endif
let g:loaded_scarletquarry = 1


function! s:config() abort
    let repo = fugitive#buffer().repo()

    let type = repo.config('issuetracker.type')
    if !empty(type) && type != 'redmine'
        return ''
    endif

    let url = repo.config('redmine.url')
    let key = repo.config('redmine.apikey')

    if empty(url) || empty(key)
        return ''
    elseif empty(key)
        return ''
    endif
    return [url, key]
endfunction

augroup scarletquarry
  autocmd!
  autocmd User Fugitive
        \ if expand('%:p') =~# '\.git[\/].*MSG$' &&
        \   exists('+omnifunc') &&
        \   &omnifunc =~# '^\%(syntaxcomplete#Complete\)\=$' &&
        \   !empty(s:config()) |
        \   setlocal omnifunc=scarletquarry#omnifunc |
        \ endif
  autocmd BufEnter *
        \ if expand('%') ==# '' && &previewwindow && pumvisible() && getbufvar('#', '&omnifunc') ==# 'scarletquarry#omnifunc' |
        \    setlocal nolist linebreak filetype=markdown |
        \ endif
augroup END
