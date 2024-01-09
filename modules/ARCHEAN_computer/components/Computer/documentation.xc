; XenonCode Documentation

; This is the extended documentation related to the Archean implementation of XenonCode.
; For the basic syntax, please refer to https://xenoncode.com/documentation.php

var $num_value : number

tick
	
	; Built-in values
	$num_value = time ; the current time as decimal unix timestamp in seconds with microsecond precision
	$num_value = delta_time ; the time interval between ticks in seconds
	
	$num_value = char_w ; the width of a character in pixels, taking into consideration the current text size
	$num_value = char_h ; the height of a character in pixels, taking into consideration the current text size

	$num_value = screen_w ; the width of the virtual monitor in pixels
	$num_value = screen_h ; the height of the virtual monitor in pixels

	$num_value = clicked ; whether the mouse button was pressed while aiming at the virtual monitor
	$num_value = click_x ; the x coordinate of the mouse cursor on the virtual monitor when the mouse button was pressed
	$num_value = click_y ; the y coordinate of the mouse cursor on the virtual monitor when the mouse button was pressed
	
	$num_value = system_frequency ; the frequency of the system clock in hertz (ticks per second)
	$num_value = programs_count ; the number of programs currently on the virtual HDD
	
	
	; Built-in functions
	var $programName = program_name(0) ; returns a program name, given an index between 0 and programs_count-1
	load_program($programName) ; loads a program
	reboot() ; reboots the computer
	
	; Random Generator
	$num_value = random(0, 100) ; returns a random integer value between 0 and 100
	$num_value = random ; returns a random float value between 0.0 and 1.0
	
	; Color
	var $blue = color(0, 0, 255) ; returns an RGB color given three values between 0 and 255
	var $translucentRed = color(255, 0, 0, 128) ; returns an RGBA color given four values between 0 and 255


	; Built-in colors
	var $black = black
	var $white = white
	var $red = red
	var $green = green
	var $blue = blue
	var $yellow = yellow
	var $pink = pink
	var $orange = orange
	var $cyan = cyan
	var $gray = gray
	
	
	; Monitor rendering functions (draw on the virtual screen)
	
	blank($black) ; clears the screen with a given color

	write(0, 0, $green, "Hello") ; write a green Hello message in the top left corner of the screen
	write(0, char_h+1, $blue, "Hey") ; write a blue Hey message just one pixel under the first message

	draw(50, 50, $red, 10, 10) ; draw a 10x10 pixel red square starting (top-left) at coordinates 50,50 in the screen
	draw(screen_w/2, screen_h/2, $white) ; draw a single white pixel in the middle of the screen

	set_text_size(2) ; sets text size to two times native, only valid for following writes in current tick until next set_text_size()

	if button(0, 0, $gray, 100, 50) ; draw a 100x50 gray rectangle button in the top left corner of the screen
		if user == owner
			print("The owner of this computer clicked the button")
		else
			print("The button was clicked by " & user) ; prints a message to the console (when the button was clicked, in this case)
	

	; IO
	
	; input_[number|text](aliasOrIoNumber, channelIndex) ; returns the value of the input with the given alias and index
	var $someNumber = input_number("", 0)
	var $someText = input_text("", 0)
	
	; output_[number|text](aliasOrIoNumber, channelIndex, value) ; sends the given value to the output with the given alias and index
	output_number(0, 0, $num_value) ; send a number to output with alias computer
	output_number("computer", 0, $num_value) ; send a number to output with alias computer
	output_text("computer", 0, "hello") ; send text hello to output with alias computer
