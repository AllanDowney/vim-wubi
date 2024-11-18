vim9script

# =========================================================
#   Copyright (C) 2023 Allan Downey. All rights reserved.
#
#   File Name     : vimim_wubi.vim
#   Author        : Allan Downey<AllanDowney@126.com>
#   Version       : 0.4
#   Create        : 2023-02-28 23:18
#   Last Modified : 2023-03-12 11:30
#   Describe      : 
#
# =========================================================

if v:version < 900
	echoerr "[vimim_wubi] Error: 需要 Vim-9.0 以上版本."
	finish
endif

if g:->get('loaded_vimim_wubi')
	finish
endif

g:loaded_vimim_wubi = 1

if !isdirectory(expand('~/.vim/table'))
	mkdir(expand('~/.vim/table'), 'p')
endif

g:vimim_table_custom = expand('~/.vim/table/custom.txt')

if !filereadable(g:vimim_table_custom)
	writefile([], g:vimim_table_custom)
endif

augroup Vimim
	autocmd!
	autocmd VimEnter * call vimim#LoadTable()
    autocmd BufReadPre */table/*.txt setlocal ts=20 list
augroup END

command -nargs=0 ImBuild vimim#RebuildTable()
command -nargs=0 ImDisable vimim#Disable()
command -complete=custom,WhFile -nargs=? ImEdit build#EditTable(<q-args>)
command -nargs=1 ImCreate vimim#CreateWords(<q-args>)

func WhFile(A, L, P)
	return "custom\nwubi86\nwubi86_dz"
endfunc

inoremap <Plug>(VimimStart) <Cmd>call vimim#Enable()<CR>
inoremap <Plug>(VimimToggle) <Cmd>call vimim#Toggle()<CR>
inoremap <Plug>(VimimStop) <Cmd>ImDisable<CR>
nnoremap <Plug>(VimimStop) <Cmd>ImDisable<CR>
nnoremap <Plug>(VimimEdit) <Cmd>ImEdit<CR>
vnoremap <Plug>(VimimCreate) y:ImCreate <C-R>"<CR>

if !hasmapto('<Plug>(VimimStart)', 'i')
	imap  <Leader>ii <Plug>(VimimStart)
endif

if !hasmapto('<Plug>(VimimToggle)', 'i')
	imap  <Leader>il <Plug>(VimimToggle)
endif

if !hasmapto('<Plug>(VimimStop)', 'i')
	imap  <Leader>im <Plug>(VimimStop)
endif

if !hasmapto('<Plug>(VimimStop)', 'n')
	nmap  <Leader>im <Plug>(VimimStop)
endif

if !hasmapto('<Plug>(VimimEdit)', 'n')
	nmap <Leader>ie <Plug>(VimimEdit)
endif

if !hasmapto('<Plug>(VimimCreate)', 'v')
	vmap  <Leader>ic <Plug>(VimimCreate)
endif

# vim: ts=4 sw=4 noet fdm=marker
