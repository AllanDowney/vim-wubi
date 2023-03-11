vim9script

# =========================================================
#   Copyright (C) 2023 Allan Downey. All rights reserved.
#
#   File Name     : vimim.vim
#   Author        : Allan Downey<AllanDowney@126.com>
#   Version       : 0.1
#   Create        : 2023-02-28 23:18
#   Last Modified : 2023-02-28 23:18
#   Describe      : 
#
# =========================================================

import autoload 'build.vim'

var tabledict: dict<list<string>> = {}

const im_valid_keys = split('a b c d e f g h i j k l m n o p q r s t u v w x y z')
const im_select_keys = [' ', ';', "'", ',', '5', '6', '7', '8', '9', '0']

var vimimconfig: dict<any> = {
	horizontal: true,
	gb2312: true,
	showlogo: true,
	temp_english_key: '`',
	disable_chinese_punct: false,
	toggle_chinese_punct: "\<C-l>",
	chinese_puncts: {
		',': '，',
		'.': '。',
		':': '：',
		';': '；',
		'?': '？',
		'!': '！',
		'\': '、',
		'^': '……',
		'_': '——',
		}
}
	# trim_english_word: true,

# ┌──────────────────┐
# │                  │
# └──────────────────┘
var popopt_wubi: dict<any> = {
		pos: 'topleft',
		border: [],
		borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
		borderhighlight: [ 'imBorder' ],
		title: '五─CN',
		padding: [0, 2, 0, 1],
		zindex: 400,
		wrap: false,
		scrollbar: 0 }

var popid: number = -1
var logoid: number = -1
var vimim_enabled: bool = false

highlight imBorder	ctermfg=250 ctermbg=Cyan guifg=#80A0FF guibg=#263A45
highlight imCode	ctermfg=168 ctermbg=Cyan guifg=#DC657D guibg=#263A45

export def LoadTable(force: bool = v:false)
	if force
		tabledict = {}
		tabledict = build.BuildTable()
	elseif empty(tabledict)
		var ljson = expand('<script>:p:h:h') .. '/wubi86.json'
		if filereadable(ljson)
			tabledict = js_decode(readfile(ljson)[0])
		else
			tabledict = build.BuildTable()
		endif
	endif

	if !empty(g:->get('Vimim_config'))
		extend(vimimconfig, g:Vimim_config, "force")
	endif

	echohl Statement
	echomsg '[VIMIM] - table length:' (len(tabledict)) ' type:'
				\ (typename(tabledict))
	echohl None
	echo ''
enddef

export def Enable(): number
    setlocal iminsert=2
	if vimimconfig.showlogo
		logoid = popup_create('五笔', {
				line: winheight(0) - 1,
				col: winwidth(0) - 10,
				zindex: 300,
				highlight: 'imBorder',
				border: [],
				borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
				padding: [0, 1, 0, 1],
				wrap: false,
			})
		redraw
	endif

	vimim_enabled = true
	if vimimconfig.horizontal
		popopt_wubi.maxheight = 1
	else
		popopt_wubi.maxheight = 12
	endif

	augroup Vimim_enable
		autocmd!
		autocmd InsertCharPre * call vimim#TableConvert()
		autocmd ModeChanged i*:n* call vimim#Toggle(0)
		autocmd ModeChanged n*:i* call vimim#Toggle(1)
	augroup END

	echo 'VIMIM ' vimim_enabled

	if exists(':CocDisable') == 2
		CocDisable
	endif
	return 1
enddef

export def Toggle(stauts: number)
	if !stauts
		setlocal iminsert=0
		setlocal iminsert?
	else
		setlocal iminsert=2
		setlocal iminsert?

	endif
enddef

export def Disable()
	if vimim_enabled
		popup_clear()
		setlocal iminsert=0
		vimim_enabled = false
		logoid = -1
		popid = -1
		augroup Vimim_enable
			autocmd!
			autocmd BufEnter * call popup_clear()
		augroup END

		echo 'VIMIM ' vimim_enabled
	endif

	if exists(':CocEnable') == 2
		CocEnable
	endif
enddef

export def TableConvert(): string
	if &iminsert != 2
		return ''
	endif

	if index(im_valid_keys, v:char) < 0
		return PassThrough(v:char)
	else
		return ConvertStart(v:char)
	endif
enddef

def PassThrough(chari: string): string
	if chari == vimimconfig.toggle_chinese_punct
		vimimconfig.disable_chinese_punct = !vimimconfig.disable_chinese_punct
		if vimimconfig.disable_chinese_punct
			popopt_wubi.title = '五─EN'
		else
			popopt_wubi.title = '五─CN'
		endif

		v:char = ''
	elseif chari == vimimconfig.temp_english_key
			v:char = TempEnglish()
	else
		v:char = HandlePunct(chari)
	endif

	return v:char
enddef

def ConvertStart(code: string): string
	var lcode = code
	if vimimconfig.horizontal
		popid = popup_atcursor(GetCandidatesToString(lcode), popopt_wubi)
	else
		popid = popup_atcursor(GetCandidates(lcode, v:true), popopt_wubi)
	endif
	redraw

	while v:true
		var char = getchar()

		if type(char) ==# v:t_number
			char = nr2char(char)
		endif

		if char == "\<BS>"
			lcode = lcode[: -2]
			if empty(lcode)
				return Finalize('', '')
			endif
		else
			if index(im_valid_keys, char) < 0
				return Finalize(lcode, char)
			elseif len(lcode) < 4
				lcode ..= char
			else
				feedkeys(char, 'i')
				return Finalize(lcode, '')
			endif
		endif

		if vimimconfig.horizontal
			popup_settext(popid, GetCandidatesToString(lcode))
		else
			popup_settext(popid, GetCandidates(lcode, v:true))
		endif
		redraw
	endwhile

	return v:char
enddef

def Finalize(code: string, chari: string): string
	popup_close(popid)
	popid = -1

	if code == '' || chari == "\<ESC>"
		v:char = ''
		return v:char
	elseif chari == "\<CR>"
		v:char = code
	else
		var lcand = GetCandidates(code)

		if len(lcand) == 0
			v:char = ''
			return v:char
		endif

		var lidx = index(im_select_keys, chari)
		if lidx < 0 || lidx >= len(lcand)
			v:char = get(lcand, 0, '') .. HandlePunct(chari)
		else
			v:char = lcand[lidx]
		endif
	endif

	return v:char
enddef

def GetCandidates(code: string, padding: bool = v:false): list<string>
	var lcand: list<string> = []

	if code == ''
		return lcand
	endif

	if has_key(tabledict, code)
		lcand = tabledict[code]
	endif

	if len(lcand) > 10
		lcand = lcand[: 9]
	endif

	return !padding ? lcand :
		copy(lcand)->map((key, val) =>
			printf('%d.%s', (key + 1) % 10, val))
		->insert('-------')
		->insert(code)
enddef

def GetCandidatesToString(code: string): string
	return copy(GetCandidates(code))->map((key, val) =>
			printf('%d.%s', (key + 1) % 10, val))
		->insert(printf('%-4s', code))
		->join('  ')
enddef

def HandlePunct(chari: string): string
	if vimimconfig.disable_chinese_punct ||
			!has_key(vimimconfig.chinese_puncts, chari)
		return chari
	else
		return vimimconfig.chinese_puncts[chari]
	endif
enddef

def TempEnglish(): string
    popid = popup_atcursor('=> ', { pos: 'topleft',
		border: [],
		borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
		borderhighlight: [ 'imBorder' ],
		title: 'EN',
		padding: [0, 1, 0, 1],
		maxheight: 1,
		scrollbar: 0 })
    redraw

    v:char = ''
    while v:true
		var lchar = getchar()
		if type(lchar) ==# v:t_number
			lchar = nr2char(lchar)
		endif

		if lchar == "\<CR>"
			break

		elseif lchar == "\<BS>"
			v:char = v:char[: -2]
			if empty(v:char)
				break
			endif

		elseif lchar == "\<Esc>"
			v:char = ''
			break

		else
			v:char ..= lchar
		endif

		popup_settext(popid, '=> ' .. v:char)
		redraw
    endwhile

    popup_close(popid)
    popid = -1

	# if vimimconfig.trim_english_word
	# 	v:char = trim(v:char) .. ' '
	# endif

    return v:char
enddef

#  vim: ts=4 sw=4 noet fdm=indent fdl=2
