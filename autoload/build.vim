vim9script

# =========================================================
#   Copyright (C) 2023 Allan Downey. All rights reserved.
#
#   File Name     : build.vim
#   Author        : Allan Downey<AllanDowney@126.com>
#   Version       : 0.2
#   Create        : 2023-03-01 23:13
#   Last Modified : 2023-03-12 02:49
#   Describe      : 
#
# =========================================================

const table_path = expand('<script>:p:h:h') .. '/table'
const table_zh = table_path .. '/wubi86_zh.txt'
const table_dz = table_path .. '/wubi86_dz.txt'
const table_tw = table_path .. '/wubi86_tw.txt'
const table_custom = table_path .. '/custom.txt'

export def BuildTable(): dict<list<string>>
	echo 'Building tables...'
	echo 'This may take a few seconds...'

	var table_dict = {}
	var im_gb2312: bool = empty(g:->get('Vimim_config')) ? v:true :
		get(g:Vimim_config, 'gb2312', v:true)

	var startt = reltime()

	var ltable_dict = ReadToDict(table_zh)
	ExtendD(ltable_dict, ReadToDict(table_dz))

	if !im_gb2312
		ExtendD(ltable_dict, ReadToDict(table_tw))
	endif

	{
		var ltable_cust = ReadToDict(table_custom)

		if !empty(ltable_cust)
			ExtendD(ltable_dict, ltable_cust)
			echo 'Extend custom table'
		endif
	}

	table_dict = mapnew(ltable_dict, (_, v) =>
		sort(v, (a, b) => -(str2nr(a[1]) - str2nr(b[1])))
		->mapnew((_, w) => w[0]))

	echo 'All tables length: ' len(table_dict) 'type: ' typename(table_dict)
	echo 'Done. in' reltimestr(reltime(startt)) .. 's.'

	var table_json = substitute(table_zh, '_zh.txt$', '.json', '')
	writefile([js_encode(table_dict)], table_json)

	return table_dict
enddef

def ReadToDict(txtfile: string): dict<list<list<string>>>
	var table_dict = {}

	for line in readfile(txtfile)
		var [len, code, char, freq] = split(line, "\t")

		if has_key(table_dict, code)
			add(table_dict[code], [char, freq])
		else
			table_dict[code] = [[char, freq]]
		endif
    endfor

	var fname = fnamemodify(txtfile, ":t")
	echo fname->printf('%16s') 'length:' len(table_dict)->printf('%6d')
	return table_dict
enddef

def ExtendD(base: dict<list<list<string>>>, secondd: dict<list<list<string>>>):
		\ dict<list<list<string>>>
	for [key, value] in items(secondd)
		if has_key(base, key)
			extend(base[key], value->deepcopy())
		else
			base[key] = value->deepcopy()
		endif
	endfor

	return base
enddef

export def EditTable(TxtFile: string)
	var lfile = TxtFile
	if TxtFile == ''
		lfile = 'custom.txt'
	endif
	execute 'tabedit ' .. table_path .. '/' .. lfile
enddef

#  vim: ts=4 sw=4 noet fdm=indent
