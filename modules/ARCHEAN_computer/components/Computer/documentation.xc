; Archean XenonCode Documentation

; This is the extended documentation related to the Archean specific implementation of XenonCode.
; For the basic syntax of XenonCode, please refer to https://xenoncode.com/documentation.php

; Includes are useful to either share functionality between programs, merge multiple programs into one, or just to keep your programs clean and organized.
include "some_helper_functions.xc"

; Basic Declarations
var $num_value : number
const $speed_of_light = 299792458

; Storage Declarations
storage var $memorized_value : number
storage array $memorized_names : text
; Storage values are retained between reboots and program modifications. They are always default-initialized to 0 or empty.

init
	; This entry point is executed once when the program is loaded.
	; Only one 'init' entry point may be defined in a program.

shutdown
	; This entry point is executed once when the computer is powered off or before it is rebooted (but NOT when it crashes).
	; Multiple 'shutdown' entry points may be defined in a single program and they will all be executed in the order they are defined.

input.0 ($value0:number, $value1:number, $value2:text)
	; This entry point is executed whenever a value is received from the input with the specified IO index.
	; The arguments are the values received for each channel. Any number of arguments can be provided, with their appropriate types.
	; There can only be one 'input' entry point defined per IO index per program.

click ($x:number, $y:number)
	; This entry point is executed whenever a user clicks on the screen, given an xy coordinate in pixels.
	; Multiple 'click' entry points may be defined in a single program and they will all be executed in the order they are defined.

tick
	; This entry point is executed once every server tick.
	; Only one 'tick' entry point may be defined in a program.

timer interval 5
	; This entry point is executed every 5 seconds.
	; Multiple 'timer interval' entry points may be defined in a single program and they will all be executed as their time has come, after the tick.
timer frequency 10
	; This entry point is executed 10 times per second.
	; Multiple 'timer frequency' entry points may be defined in a single program and they will all be executed as their time has come, after the tick.
	
update
	; This entry point is executed on each server tick at the end of each cycle, after the timers.
	; Multiple 'update' entry points may be defined in a single program and they will all be executed in the order they are defined.

	; Built-in values
	$num_value = time ; the current time as decimal unix timestamp in seconds with microsecond precision
	$num_value = delta_time ; the time interval between ticks in seconds (equivalent to 1.0 / system_frequency)
	
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
	load_program($programName) ; loads a program and call its init function (it first unloads the currently running program, calling shutdown on it)
	reboot() ; reboots the computer (calls the shutdown entry point and loads the bios or main program)
	
	; Random Generator
	$num_value = random(0, 100) ; returns a random integer value between 0 and 100 inclusively
	$num_value = random ; returns a random float value between 0.0 and 1.0 (hitting exactly 0.0 or 1.0 is statistically improbable)
	
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

	write(0, 0, green, "Hello") ; write a green Hello message in the top left corner of the screen
	write(0, char_h+1, blue, "Hey") ; write a blue Hey message just one pixel under the first message

	draw(50, 50, red, 10, 10) ; draw a 10x10 pixel red square starting (top-left) at coordinates 50,50 in the screen
	draw(screen_w/2, screen_h/2, white) ; draw a single white pixel in the middle of the screen

	text_size(2) ; sets text size to two times native, only valid for following writes in current tick until next text_size()

	if button(0, 0, gray, 100, 50) ; draw a 100x50 gray rectangle button in the top left corner of the screen. Evaluates to true if clicked.
		if user == owner
			print("The owner of this computer clicked the button")
		else
			print("The button was clicked by " & user) ; prints a message to the console (when the button was clicked, in this case)
	; Here we also happen to use the built-ins 'user' and 'owner' which are player usernames
	

	; IO
	
	; input_[number|text](aliasOrIoNumber, channelIndex) ; returns the value of the input with the given alias and index
	var $someNumber = input_number("", 0)
	var $someText = input_text("", 0)
	
	; output_[number|text](aliasOrIoNumber, channelIndex, value) ; sends the given value to the output with the given alias and index
	output_number(0, 0, $num_value) ; send a number to output with alias computer
	output_number("computer", 0, $num_value) ; send a number to output with alias computer
	output_text("computer", 0, "hello") ; send text hello to output with alias computer
