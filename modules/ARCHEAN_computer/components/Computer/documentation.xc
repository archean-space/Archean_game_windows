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


	; Channels per component

	; Seat
		; Input:
			; Channel 0 >> "using"
			; Channel 1 >> "mainThrust"
			; Channel 2 >> "leftRight"
			; Channel 3 >> "backwardForward"
			; Channel 4 >> "downUp"
			; Channel 5 >> "pitch"
			; Channel 6 >> "roll"
			; Channel 7 >> "yaw"
			; Channel 8 >> "aux_0"
			; Channel 9 >> "aux_1"
			; Channel 10 >> "aux_2"
			; Channel 11 >> "aux_3"
			; Channel 12 >> "aux_4"
			; Channel 13 >> "aux_5"
			; Channel 14 >> "aux_6"
			; Channel 15 >> "aux_7"
			; Channel 16 >> "aux_8"
			; Channel 17 >> "aux_9"


	; Wheel
		; Output
			; Channel 0 >> "accelerate"
			; Channel 1 >> "steer"
			; Channel 2 >> "regen"
			; Channel 3 >> "brake"
			; Channel 4 >> "gearbox"


	; Propeller
		; Output
			; Channel 0 >> "Set Speed"
			; Channel 1 >> "Set Pitch"
			; Channel 2 >> "Set Radius"
			; Channel 3 >> "Set Width"
			; Channel 4 >> "Set Twist"
			; Channel 5 >> "Set Blades"


	; Battery & High voltage Battery
		; Input
			; Channel 0 >> "voltage"
			; Channel 1 >> "max capacity"
			; Channel 2 >> "state of charge"
			; Channel 3 >> "throughput"


	; Beacon
		; Input
			; Channel 0 >> "distance"
			; Channel 1 >> "direction x"
			; Channel 2 >> "direction y"
			; Channel 3 >> "direction z"
			; Channel 4 >> "data"
		; Output
			; Channel 0 >> "transmit freq"
			; Channel 1 >> "transmit data"
			; Channel 2 >> "receive freq"


	; Altimeter
		; Input
			; Channel 0 >> "absolute altitude"
			; Channel 1 >> "above terrain"
			; Channel 2 >> "relative speed"
			; Channel 3 >> "tilt"


	; Small fluid tank, fluid tank & big fluid tank
		; Input
			; Channel 0 >> "Level"


	; NavInstrument
		; Input
			; Channel 0 >> "celestial"
			; Channel 1 >> "altitude"
			; Channel 2 >> "orbital speed"
			; Channel 3 >> "ground speed"
			; Channel 4 >> "periapsis"
			; Channel 5 >> "apoapsis"
			; Channel 6 >> "horizon pitch"
			; Channel 7 >> "horizon roll"
			; Channel 8 >> "prograde pitch"
			; Channel 9 >> "prograde yaw"
			; Channel 10 >> "retrograde pitch"
			; Channel 11 >> "retrograde yaw"
			; Channel 12 >> "locator pitch"
			; Channel 13 >> "locator yaw"
			; Channel 14 >> "locator distance"
			; Channel 15 >> "orbit target speed"
			; Channel 16 >> "orbit target altitude"
			; Channel 17 >> "celestial inner radius"
			; Channel 18 >> "celestial outer radius"
			; Channel 19 >> "orbital inclination"
			; Channel 20 >> "forward airspeed"
			; Channel 21 >> "vertical speed"
			; Channel 22 >> "above terrain"
			; Channel 23 >> "latitude"
			; Channel 24 >> "longitude"
			; Channel 25 >> "course"
			; Channel 26 >> "heading"
			; Channel 27 >> "ground speed forward"
			; Channel 28 >> "ground speed right"
		; Output
			; Channel 0 >> "locate distance"
			; Channel 1 >> "locate direction x"
			; Channel 2 >> "locate direction y"
			; Channel 3 >> "locate direction z"
			; Channel 4 >> "locate celestial"
			; Channel 5 >> "forward vector config" ; // 0 = forward, +1 = up, -1 = down


	; Small thruster
		; Input
			; Channel 0 >> "thrust"
			; Channel 1 >> "burned flow"
			; Channel 2 >> "unburned flow"
		; Output
			; Channel 0 >> "ignition"
			; Channel 1 >> "gimbal x" 
			; Channel 2 >> "gimbal z"


	; TurboPump
		; Input
			; Channel 0 >> "flow" ; Current flow rate
		; Output
			; Channel 0 >> "flow" ; Target power of the TurboPump (0-1)


	; RCS
		; Output
			; Channel 0 >> "Nozzle 0"
			; Channel 1 >> "Nozzle 1"
			; Channel 2 >> "Nozzle 2"
			; Channel 3 >> "Nozzle 3"
			; Channel 4 >> "Nozzle 4"

