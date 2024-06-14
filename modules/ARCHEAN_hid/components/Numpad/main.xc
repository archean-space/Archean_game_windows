var $numtext = "0"
var $outputNumber = 0
var $send = 0
const $chars = "7894561230.-"

const $xPos = 13
const $yPos = 15
var $textColor = color(0,0,0)
var $backgroundColor = color(0,0,0)
var $numButtonColor = color(50,220,220)
var $removeButtonColor = color(255,255,50)
var $clearButtonColor = color(255,50,50)
var $lockButtonColor = color(50,255,50)
var $activeColor = color(255,255,255,180)
var $displayColor = color(80,80,80)

tick
	blank($backgroundColor)
	var $last = ""
	
	;NUMPAD
	repeat 12 ($i)
		var $x = ($i % 3) * 8
		var $y = floor($i / 3) * 10
		if button($x+$xPos, $y+$yPos, $numButtonColor, 7, 9)
			draw($x+$xPos, $y+$yPos, $activeColor, 7, 9)
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
		
	; REMOVE, CLEAR and LOCK
	if button($xPos+24, $yPos, $removeButtonColor, 7, 12)
		draw($xPos+24, $yPos, $activeColor, 7, 12)
		var $size = size($numtext)
		if $size > 1
			$numtext.substring(0,$size-1)
		else
			$numtext = "0"
	write($xPos+25, $yPos+3, $textColor, "<")
	
	if button($xPos+24, $yPos+13, $clearButtonColor, 7, 12)
		draw($xPos+24, $yPos+20, $activeColor, 7, 12)
		$numtext = "0"
	write($xPos+25, $yPos+16, $textColor, "X")
	
	if button($xPos+24, $yPos+26, $lockButtonColor, 7, 13)
		draw($xPos+24, $yPos+26, $activeColor, 7, 13)
		if $numtext == "." or $numtext == "-." or $numtext == "-"
			$numtext = "0"
		$send = 10
		$outputNumber = $numtext:number
	write($xPos+25, $yPos+29, $textColor, ">")
	
	; DISPLAY
	draw($xPos-11, $yPos-12, $displayColor, 52, 9)
	if $send > 0
		$send -= 1
		draw($xPos-11, $yPos-12, $numButtonColor, (52/10)*(10-$send), 9)
	if $numtext == "0"
		write(($xPos-10), $yPos-11, $textColor, "0")
	else
		write(($xPos-10), $yPos-11, $textColor, substring($numtext,0,8))
	output.0($outputNumber)
	
	; DECORATION
	draw(2,3,$backgroundColor,1,1)
	draw(2,11,$backgroundColor,1,1)
	draw(53,3,$backgroundColor,1,1)
	draw(53,11,$backgroundColor,1,1)

