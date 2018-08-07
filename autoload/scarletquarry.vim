if exists('g:autoloaded_scarletquarry')
    finish
endif
let g:autoloaded_scarletquary = 1

function! s:throw(string) abort
    let v:errmsg = 'scarletquarry: '.a:string
    throw v:errmsg
endfunction

function! s:shellesc(arg) abort
    if a:arg =~ '^[A-Za-z0-9_/.-]\+$'
        return a:arg
    elseif &shell =~# 'cmd' && a:arg !~# '"'
        return '"'.a:arg.'"'
    else
        return shellescape(a:arg)
    endif
endfunction

function! scarletquarry#json_parse(string) abort
    if exists('*json_decode')
        return json_decode(a:string)
    endif
    let [null, false, true] = ['', 0, 1]
    let stripped = substitute(a:string,'\C"\(\\.\|[^"\\]\)*"','','g')
    if stripped !~# "[^,:{}\\[\\]0-9.\\-+Eaeflnr-u \n\r\t]"
        try
            return eval(substitute(a:string,"[\r\n]"," ",'g'))
        catch
        endtry
    endif
    call s:throw("invalid JSON: ".a:string)
endfunction

function! s:config() abort
    let buffer = fugitive#buffer()

    let url = buffer.repo().config('redmine.url')
    let key = buffer.repo().config('redmine.apikey')
    if empty(url)
        throw 'Missing redmine.url'
    elseif empty(key)
        throw 'Missing redmine.apikey'
    endif
    return [url, key]
endfunction

function! s:homepage() abort
    return s:config()[0]
endfunction

function s:curl_arguments(url, key, ...) abort
    let options = a:0 ? a:1 : {}
    let args = ['-q', '--silent']
    call extend(args, ['-H', 'Accept: application/json'])
    call extend(args, ['-H', 'Content-Type: application/json'])
    call extend(args, ['-H', 'X-Redmine-API-Key: '.a:key])
    call extend(args, ['-A', 'scarletquarry.vim'])
    call extend(args, ['-XGET', a:url])

    return args
endfunction!

function! scarletquarry#request(path, ...) abort
    if !executable('curl')
        call s:throw('cURL is required')
    endif

    let [url, key] = s:config()
    let args = s:curl_arguments(url . a:path, key)
    let raw = system('curl '.join(map(copy(args), 's:shellesc(v:val)'), ' '))
    if raw ==# ''
        return raw
    else
        return scarletquarry#json_parse(raw)
    endif
endfunction

function! scarletquarry#search(type, query, prefix) abort
    let query = substitute(a:query, '#', '', '')
    " redmine api is too slow, we need to cache this
    if !exists('b:scarletquarry_search')
        if !exists('g:scarletquarry_valid_statuses')
            let g:scarletquarry_valid_statuses = [1,2]
        endif
        let params = '?assigned_to_id=me&limit=100&f\[\]=status_id&op\[status_id\]=%3D'
        for status in g:scarletquarry_valid_statuses
            let params .= '&v\[status_id\]\[\]=' . status
        endfor
        let params .= '&sort=updated_on:desc'
        let res = scarletquarry#request('/issues.json'.params)
        if empty(res)
            call s:throw('Failed to query redmine api')
        endif

        let total = res.total_count

        " return map(copy(issues), '{"word": prefix.v:val.id, "abbr": "#".v:val.id, "menu": v:val.title . " (".v:val.status.")", "info": substitute("*" . v:val.project . "*\n*" . v:val.author . "*\n" . v:val.description,"\\r","","g")}')
        let b:scarletquarry_search = []
        let issues = map(res.issues, '{"word": a:prefix . v:val.id, "menu": v:val.subject . " (" . v:val.status.name . ")", "info": substitute("*" . v:val.project.name . "*\n*" . v:val.author.name . "*\n" . v:val.description, "\\r", "","g")}')
        for issue in issues
            if match(issue.word, '\c'.query) > -1
                call complete_add(issue)
            elseif match(issue.menu, '\c'.query) > -1
                call complete_add(issue)
            elseif match(issue.info, '\c'.query) > -1
                call complete_add(issue)
            endif
        endfor
        call complete_check()
        call extend(b:scarletquarry_search, issues)

        " while len(b:scarletquarry_search) < total
        "     let res = scarletquarry#request('/issues.json'.params.'&offset=' . len(b:scarletquarry_search))
        "     let issues = map(res.issues, '{"word": a:prefix . v:val.id, "menu": v:val.subject . " (" . v:val.status.name . ")", "info": substitute("*" . v:val.project.name . "*\n*" . v:val.author.name . "*\n" . v:val.description, "\\r", "","g")}')
        "     for issue in issues
        "         call complete_add(issue)
        "     endfor
        "     call complete_check()
        "     call extend(b:scarletquarry_search, issues)
        "     echo "len: ".len(b:scarletquarry_search)
        " endwhile
        return []
    endif

    let issues = b:scarletquarry_search
    for issue in issues
        if match(issue.menu, '\c'.query) > -1
            call complete_add(issue)
        elseif match(issue.info, '\c'.query) > -1
            call complete_add(issue)
        elseif match(issue.word, '\c'.query) > -1
            call complete_add(issue)
        endif
    endfor
    call complete_check()

    return []
endfunction

let s:reference = '\<\%(\c\%(clos\|resolv\|refs\|referenc\)e[sd]\=\|\cfix\%(e[sd]\)\=\)\>'
function! scarletquarry#omnifunc(findstart,base) abort
    let [url, key] = s:config()

    if a:findstart
        let existing = matchstr(getline('.')[0:col('.')-1],s:reference.'\s\+\zs[^#/,.;]*$\|[#[:alnum:]-]*$')
        return col('.')-1-strlen(existing)
    endif
    try
        if a:base =~# '^#'
            let prefix = '#'
        else
            let prefix = url.'/issues/'
        endif
        let query = a:base
        let response = scarletquarry#search('issues', query, prefix)
        if type(response) != type([])
            call s:throw('unknown error')
        endif
        return response
    catch /^\%(fugitive\|scarletquarry\):/
        echoerr v:errmsg
    endtry
endfunction
