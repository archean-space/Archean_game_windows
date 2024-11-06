var $numtext = "0"
var $output = 0
var $send = 0
const $chars = "7894561230.-"

const $xPos = 13
const $yPos = 15
var $textColor = color(0,0,0)
var $backgroundColor = color(0,0,0)
var $numButtonColor = color(50,220,220)
var $animColor = color(50,220,220,20)
var $removeButtonColor = color(255,255,50)
var $clearButtonColor = color(255,50,50)
var $lockButtonColor = color(50,255,50)
var $displayColor = color(80,80,80)

function @decoration()
	draw(2,3,$backgroundColor,1,1)
	draw(2,11,$backgroundColor,1,1)
	draw(53,3,$backgroundColor,1,1)
	draw(53,11,$backgroundColor,1,1)

function @numpad($value:number):number
	blank($backgroundColor)
	var $last = ""
	
	;NUMPAD
	repeat 12 ($i)
		var $x = ($i % 3) * 8
		var $y = floor($i / 3) * 10
		if button($x+$xPos, $y+$yPos, $numButtonColor, 7, 9)
			if $chars.$i == "."
				if !contains($numtext, ".")
					$last &= $chars.$i
			elseif $chars.$i == "-"
				if $numtext.0 == "-"
					$numtext.substring(1)
				else 
					$numtext = "-" & $numtext
			else
				$last &= $chars.$i
		write($x+$xPos+1, $y+$yPos+1, $textColor, $chars.$i)
	if $last != ""
		if $numtext == "0"
			$numtext = $last
		else
			$numtext &= $last
		$last = ""
		
		
	; REMOVE
	if button($xPos+24, $yPos, $removeButtonColor, 7, 12)
		var $size = size($numtext)
		if $size > 1
			$numtext.substring(0,$size-1)
		else
			$numtext = "0"
	write($xPos+25, $yPos+3, $textColor, "<")
	
	; CLEAR
	if button($xPos+24, $yPos+13, $clearButtonColor, 7, 12)
		$numtext = "0"
	write($xPos+25, $yPos+16, $textColor, "X")
	
	; LOCK
	if button($xPos+24, $yPos+26, $lockButtonColor, 7, 13)
		if $numtext == "." or $numtext == "-." or $numtext == "-"
			$numtext = "0"
		$send = 12
		$output = $numtext:number
	write($xPos+25, $yPos+29, $textColor, ">")
	
	; DISPLAY
	draw($xPos-11, $yPos-12, $displayColor, 52, 9)
	if $numtext == "0"
		write(($xPos-10), $yPos-11, $textColor, "0")
	else
		write(($xPos-10), $yPos-11, $textColor, substring($numtext,0,8))
	@decoration()
	
	
tick
	output.0($output)
	if $send > 0
		$send -= 1
		draw($xPos-11, $yPos-12, $animColor, 52, 9)
		@decoration()
		if $send == 0
			@numpad()
	
init
	@numpad()
click
	@numpad()