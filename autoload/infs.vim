let save_cpo = &cpo
set cpo&vim


function infs#start(...)
  let s:saveview = winsaveview()
  let save_fen = &foldenable
  if save_fen
    setlocal nofoldenable
  endif

  call setloclist(0, [], ' ', #{title: 'infs: ', quickfixtextfunc: function('s:infs_text')})
  lopen
  call s:do_user_autocmd('InfsLoclistOpen')
  wincmd p
  redraw

  let orig_maps = {}
  for item in s:get_config('map.next', ['<C-N>'])
    let orig_maps[item] = maparg(item, 'c', 0, 1)
    execute 'cnoremap <buffer>' item '<Cmd>silent! lnext<CR><Cmd>normal! zz<CR><Cmd>redraw<CR>'
  endfor
  for item in s:get_config('map.previous', ['<C-P>'])
    let orig_maps[item] = maparg(item, 'c', 0, 1)
    execute 'cnoremap <buffer>' item '<Cmd>silent! lprevious<CR><Cmd>normal! zz<CR><Cmd>redraw<CR>'
  endfor
  for item in s:get_config('map.cancel', [])
    let orig_maps[item] = maparg(item, 'c', 0, 1)
    execute 'cnoremap <buffer>' item '<Esc>'
  endfor
  for item in s:get_config('map.confirm', [])
    let orig_maps[item] = maparg(item, 'c', 0, 1)
    execute 'cnoremap <buffer>' item '<CR>'
  endfor

  augroup infs-input
    autocmd CmdlineChanged @ call s:udpate_loclist(getcmdline())
  augroup END

  call s:do_user_autocmd('InfsInputPre')
  let s:buffer = getline(1, '$')->map({ i, v -> #{text: v, bufnr: bufnr(), lnum: i + 1} })
  const cancelled = empty(input('query: ', get(a:, '1', '')))
  call s:do_user_autocmd('InfsInputPost')

  call s:restore_cmaps(orig_maps)
  autocmd! infs-input

  if save_fen
    setlocal foldenable
  endif

  if getloclist(0)->len() <= 0 || cancelled
    call winrestview(s:saveview)
    lclose
  else
    lclose
    silent ll
    silent! normal! zzzO
  endif
endfunction


function s:restore_cmaps(maps) abort
  for [name, map] in items(a:maps)
    if empty(map)
      execute 'cunmap <buffer>' name
    else
      call mapset('c', 0, map)
    endif
  endfor
endfunction


function s:udpate_loclist(query) abort
  if getchar(1) !=# 0
    return
  endif
  const bufnr = bufnr()
  const items = s:buffer->matchfuzzy(a:query, #{key: 'text'})

  call setloclist(0, [], 'r', #{
        \   title: 'infs: ' .. a:query,
        \   items: items,
        \ })

  if empty(items)
    call winrestview(s:saveview)
  else
    ll
    normal! zz
  endif
  redraw
endfunction


function s:infs_text(info) abort
  let items = getloclist(a:info.winid, #{id: a:info.id, items: 1}).items
  return items[a:info.start_idx - 1 : a:info.end_idx - 1]
        \ ->map({_, v -> printf('|%3d| %s', v.lnum, v.text->substitute('^\s*', '', ''))})
endfunction


function s:do_user_autocmd(event) abort
  if exists('#User#' .. a:event)
    execute 'doautocmd <nomodeline> User' a:event
  endif
endfunction


function s:get_config(query, default) abort
  if exists('g:infs_config.' .. a:query)
    return eval('g:infs_config.' .. a:query)
  endif
  return a:default
endfunction


let &cpo = save_cpo


" vim: et sw=2 sts=-1
