array $characters:text
array $specialCharacters:text
var $caps = 0
var $specialCharactersSwitch = 0
var $output = ""

function @case($t:text):text
	if $caps
		return upper($t)
	else
		return lower($t)
	
function @renderKeyboard()
	blank()
	text_size(2)
	; Caps ---------------------------------------------
	if button(40,106,color(100,200,200),31,19)
		$caps!!
	if $caps
		draw(40,106,color(255,255,255,100),31,19)
	write(50,113,Black,"^")
	; Delete -------------------------------------------
	if button(228,106,color(255,255,50),16,19)
		$output.substring(0,size($output)-1)
	write(231,109,Black,"<")
	; reset --------------------------------------------
	if button(248,106,color(255,50,50),16,19)
		$output = ""
	write(251,109,Black,"X")
	; Space --------------------------------------------
	if button(93,128,color(100,200,200),113,19)
		$output &= " "
	draw(113,142,color(40,40,40),73,2)
	; Special characters Switch ------------------------
	if button(35,128,color(100,200,200),31,19)
		$specialCharactersSwitch!!
	if $specialCharactersSwitch
		draw(35,128,color(255,255,255,100),31,19)
	write(38,131,Black,"!?")
	; comma --------------------------------------------
	if button(69,128,color(100,200,200),21,19)
		$output &= ","
	write(75,130,black,",")
	; dot ----------------------------------------------
	if button(209,128,color(100,200,200),21,19)
		$output &= "."
	write(215,130,black,".")
	; Send ---------------------------------------------
	if button(233,128,color(50,255,50),31,19)
		output.0($output)
	write(243,130,Black,">")


	; Special characters -------------------------------
	if $specialCharactersSwitch
		repeat 36 ($i)
			if $i < 10
				if button(40+($i%10)*22,40+floor($i/10)*22,color(50,220,220),19,19)
					$output &= $specialCharacters.$i
				write(44+($i%13)*22,42+floor($i/13)*22,black,$specialCharacters.$i)
			elseif $i < 20
				if button(40+($i%10)*22,40+floor($i/10)*22,color(50,220,220),19,19)
					$output &= $specialCharacters.$i
				write(44+($i%10)*22,42+floor($i/10)*22,black,$specialCharacters.$i)
			elseif $i < 29
				if button(52+($i%10)*22,40+floor($i/10)*22,color(50,220,220),19,19)
					$output &= $specialCharacters.$i
				write(56+($i%10)*22,42+floor($i/10)*22,black,$specialCharacters.$i)
			elseif $i < 36
				if button(30+($i%9)*22,40+floor($i/9)*22,color(50,220,220),19,19)
					$output &= $specialCharacters.$i
				write(35+($i%9)*22,42+floor($i/9)*22,black,$specialCharacters.$i)
	; Normal characters --------------------------------
	else
		repeat 36 ($i)
			if $i < 10
				if button(40+($i%10)*22,40+floor($i/10)*22,color(50,220,220),19,19)
					$output &= @case($characters.$i)
				write(44+($i%13)*22,42+floor($i/13)*22,black,@case($characters.$i))
			elseif $i < 20
				if button(40+($i%10)*22,40+floor($i/10)*22,color(50,220,220),19,19)
					$output &= @case($characters.$i)
				write(44+($i%10)*22,42+floor($i/10)*22,black,@case($characters.$i))
			elseif $i < 29
				if button(52+($i%10)*22,40+floor($i/10)*22,color(50,220,220),19,19)
					$output &= @case($characters.$i)
				write(56+($i%10)*22,42+floor($i/10)*22,black,@case($characters.$i))
			elseif $i < 36
				if button(30+($i%9)*22,40+floor($i/9)*22,color(50,220,220),19,19)
					$output &= @case($characters.$i)
				write(35+($i%9)*22,42+floor($i/9)*22,black,@case($characters.$i))


	; Drawing ------------------------------------------
	draw(5,8,color(80,80,80),290,24)
	draw(5,8,black,3,3)
	draw(5,29,black,3,3)
	draw(292,8,black,3,3)
	draw(292,29,black,3,3)
	text_size(2)
	if size($output) < 23
		write(7,13,black,$output & "_")
	else
		write(7,13,black,substring($output,size($output)-23,23) & "_")

init
	$characters.append("1","2","3","4","5","6","7","8","9","0","q","w","e","r","t","y","u","i","o","p","a","s","d","f","g","h","j","k","l","z","x","c","v","b","n","m")
	$specialCharacters.append("1","2","3","4","5","6","7","8","9","0","+","*","/","-","=","%","(",")","[","]","{","}","<",">","|","\","@","$","&","_","`","^","'","~","!","?")
	@renderKeyboard()
	
click
	@renderKeyboard()