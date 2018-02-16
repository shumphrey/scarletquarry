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

function! scarletquarry#search(type, query) abort
    " redmine api is too slow, we need to cache this
    if !exists('b:scarletquarry_search')
        if !exists('g:scarletquarry_valid_statuses')
            let g:scarletquarry_valid_statuses = [1,2]
        endif
        let params = '?limit=100&f\[\]=status_id&op\[status_id\]=%3D'
        for status in g:scarletquarry_valid_statuses
            let params .= '&v\[status_id\]\[\]=' . status
        endfor
        let res = scarletquarry#request('/issues.json'.params)
        if empty(res)
            call s:throw('Failed to query redmine api')
        endif

        let b:scarletquarry_search = map(res.issues, '{"id": v:val.id, "title": v:val.subject, "status": v:val.status.name, "project": v:val.project.name, "author": v:val.author.name, "description": v:val.description}')
    endif

    if !empty(a:query)
        let search = substitute(a:query, '#', '', '')
        let issues = filter(copy(b:scarletquarry_search), 'v:val.id =~# "^'.search.'"')
    else
        let issues = b:scarletquarry_search
    endif

    return {'items': issues}
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
        let response = scarletquarry#search('issues', query)
        if type(response) != type({})
            call s:throw('unknown error')
        elseif has_key(response, 'message')
            call s:throw(response.message)
        else
            let issues = get(response, 'items', [])
        endif
        return map(copy(issues), '{"word": prefix.v:val.id, "abbr": "#".v:val.id, "menu": v:val.title . " (".v:val.status.")", "info": substitute("*" . v:val.project . "*\n*" . v:val.author . "*\n" . v:val.description,"\\r","","g")}')
    catch /^\%(fugitive\|scarletquarry\):/
        echoerr v:errmsg
    endtry
endfunction
