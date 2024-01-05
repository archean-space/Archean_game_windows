; Private Variables
var $_current_y:number
array $_buttons_y:number
var $_clicked_btn = -1
var $_active_btn = -1
var $_btns_start_y:number
var $_btns_end_y:number

; Public Variables (You may set their value in 'init')
var $btn_horizontal_padding = 25

; -----------------------------------------------------------------------------------------------
; Private Functions
function @_clear()
	$_buttons_y.clear()
	$_current_y = 2
	blank(black)
	
click ($x:number, $y:number)
	if $x > $btn_horizontal_padding and $x < screen_w - $btn_horizontal_padding
		if $y > $_btns_start_y and $y < $_btns_end_y
			foreach $_buttons_y ($btn_y, $index)
				if $y < $btn_y and $y > $btn_y - (char_h + 8)
					$_clicked_btn = $index
					$_active_btn = $index

; -----------------------------------------------------------------------------------------------
; Public Functions

; Should call this before starting to draw UI within the 'tick' entrypoint
function @begin()
	set_text_size(1)
	@_clear()

; Should call this after finishing to draw UI within the 'tick' entrypoint
function @end()
	$_clicked_btn = -1
	$_btns_end_y = $_current_y

; Write text on the screen
function @writeLine($text:text)
	write(1,$_current_y,green, $text)
	$_current_y += char_h + 2

; Draw a button on the screen, returns true if it was clicked
function @button($text:text):number
	var $btn_index = $_buttons_y.size
	if ($btn_index == 0)
		$_btns_start_y = $_current_y
	var $is_clicked = $btn_index == $_clicked_btn
	var $border_color = color(9, 9, 9)
	if $is_clicked
		$_clicked_btn = -1
	if $is_clicked or $_active_btn == $btn_index
		$border_color = white
	draw($btn_horizontal_padding, $_current_y, $border_color, screen_w - $btn_horizontal_padding * 2, char_h + 8)
	draw($btn_horizontal_padding + 1, $_current_y + 1, color(1, 1, 1), screen_w - ($btn_horizontal_padding + 1) * 2, char_h + 6)
	draw($btn_horizontal_padding + 4, $_current_y + 4, $border_color, char_h, char_h)
	write($btn_horizontal_padding + 17, $_current_y + 4, green, $text)
	$_current_y += char_h + 9
	$_buttons_y.append($_current_y)
	return $is_clicked

; Add vertical margins
function @margin($h:number)
	$_current_y += $h
