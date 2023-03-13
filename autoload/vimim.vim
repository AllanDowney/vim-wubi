vim9script

# =========================================================
#   Copyright (C) 2023 Allan Downey. All rights reserved.
#
#   File Name     : vimim.vim
#   Author        : Allan Downey<AllanDowney@126.com>
#   Version       : 0.3
#   Create        : 2023-02-28 23:18
#   Last Modified : 2023-03-12 11:29
#   Describe      : 
#
# =========================================================

import autoload 'build.vim'

var tabledict: dict<list<string>> = {}
var impath: string = expand('<script>:p:h:h')

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

var popopt_wubi: dict<any> = {
		pos: 'topleft',
		border: [],
		borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
		borderhighlight: [ 'imBorder' ],
		title: '五─CN',
		zindex: 400,
		wrap: false,
		scrollbar: 0 }

var popid: number = -1
var logoid: number = -1
var vimim_enabled: bool = false
var vimim_status: bool = true

highlight imBorder	ctermfg=250 ctermbg=Cyan guifg=#80A0FF guibg=#263A45
highlight imCode	ctermfg=168 ctermbg=Cyan guifg=#DC657D guibg=#263A45

export def LoadTable()
	var ljson = impath .. '/table/wubi86.json'
	if filereadable(ljson)
		tabledict = js_decode(readfile(ljson)[0])
	else
		tabledict = build.BuildTable()
	endif

	if !empty(g:->get('Vimim_config'))
		extend(vimimconfig, g:Vimim_config, "force")
	endif

enddef

export def RebuildTable()
		tabledict = {}
		tabledict = build.BuildTable()
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
		popopt_wubi.padding = [0, 2, 0, 1]
	else
		popopt_wubi.maxheight = 12
		popopt_wubi.padding = [0, 1, 0, 1]
	endif

	augroup Vimim_enable
		autocmd!
		autocmd InsertCharPre * call vimim#TableConvert()
		autocmd ModeChanged i*:n* call vimim#Toggle()
		autocmd ModeChanged n*:i* call vimim#Toggle()
	augroup END

	echo 'VIMIM ' vimim_enabled

	if exists(':CocDisable') == 2
		CocDisable
	endif
	return 1
enddef

export def Toggle()
	if vimim_status
		setlocal iminsert=0
		setlocal iminsert?
	else
		setlocal iminsert=2
		setlocal iminsert?
	endif
	vimim_status = !vimim_status
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
		popid = popup_atcursor(GetCandidatesHorizontal(lcode), popopt_wubi)
	else
		popid = popup_atcursor(GetCandidatesVertical(lcode), popopt_wubi)
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
			popup_settext(popid, GetCandidatesHorizontal(lcode))
		else
			popup_settext(popid, GetCandidatesVertical(lcode))
		endif
		redraw
	endwhile

	return v:char
enddef

var sprevword: string = '五笔输入法'

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

		sprevword = v:char
	endif

	return v:char
enddef

def GetCandidates(code: string): list<string>
	var lcand: list<string> = []

	if code == ''
		return lcand
	elseif code == 'z'
		lcand = [sprevword]
	elseif has_key(tabledict, code)
		lcand = tabledict[code]
	endif

	if len(lcand) > 10
		lcand = lcand[: 9]
	endif

	return lcand
enddef

def GetCandidatesVertical(code: string): list<string>
	return copy(GetCandidates(code))->map((key, val) =>
			printf('%d. %s', (key + 1) % 10, val))
		->insert('────────')
		->insert(code)
enddef

def GetCandidatesHorizontal(code: string): string
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

export def CreateWords(swords: string): number
	var lword: list<string> = split(swords, '\zs')
	var lenword: number = len(lword)

	var hftable = readfile(impath .. '/table/wubi86_dz.txt')
	var lftable = readfile(impath .. '/table/wubi86_zh.txt')
	var cftable = readfile(impath .. '/table/custom.txt')

	var lcode: list<string> = []

	for word in lword
		var llline = match(hftable, "\t" .. word .. "\t")
		if llline > 0
			add(lcode, hftable[llline])
		else
			llline = match(lftable, "\t" .. word .. "\t", 704)
			if llline > 0
				add(lcode, lftable[llline])
			endif
		endif
	endfor

	map(lcode, (_, v) => split(v)[1] .. ' ' .. split(v)[2])

	var lllcrt = ''
	if lenword == 1
		lllcrt = lcode[0]
	elseif lenword == 2
		lllcrt = lcode[0][: 1] .. lcode[1][: 1]
	elseif lenword == 3
		lllcrt = lcode[0][0] .. lcode[1][0] .. lcode[2][: 1]
	elseif lenword == 4
		lllcrt = lcode[0][0] .. lcode[1][0] .. lcode[2][0] .. lcode[3][0]
	elseif lenword > 4
		lllcrt = lcode[0][0] .. lcode[1][0] .. lcode[2][0] .. lcode[-1][0]
	endif

	if match(hftable, "\t" .. swords .. "\t") > 0
			|| match(lftable, "\t" .. swords .. "\t") > 0
			|| match(cftable, "\t" .. swords .. "\t") > 0
		echohl WarningMsg
		echo 'EXITS [' swords '] CODE [' lllcrt ']'
		echohl END
		return -1
	endif

	echohl MoreMsg
	echomsg 'Zhcode:' lcode ' Code:' lllcrt
	echohl END

	echohl Question
	var inyn = input('[ ' .. swords .. ' ] WITH [ ' .. lllcrt .. ' ] [Y/n]: ', 'y')
	echohl END

	if inyn ==? 'y' || inyn == ''
		var lntxt = len(lllcrt) .. "\t" .. lllcrt .. "\t" .. swords .. "\t400"
		if has_key(tabledict, lllcrt)
			tabledict[lllcrt]->add(swords)
		else
			tabledict[lllcrt] = [swords]
		endif

		writefile([lntxt], expand(impath .. '/table/custom.txt'), 'a')

		echo '  ADDED [' lllcrt '] FOR [' swords ']'
	endif
	return 0
enddef

#  vim: ts=4 sw=4 noet fdm=indent fdl=2
