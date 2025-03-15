; Version 1
storage var $helpStatus:text
var $panel = panel(top,600,400)
var $helpButton = panel(top_right,30,30)
var $helpDelay = 75
var $quitButtonColor = 0
var $page = 1

function @keyboardKeys($x:number,$y:number,$name:text,$s:panel,$keycolor:number)
	$s.text_size(1)
	$s.text_align(top_left)
	var $color = color(200,200,200)
	if $keycolor > 0
		$color = $keycolor
	var $text_w = (size($name)*$s.char_w)-15
	$s.draw_circle($x+305,$y+205,5,$color,$color)
	$s.draw_circle($x+$text_w+330,$y+205,5,$color,$color)
	$s.draw_circle($x+305,$y+220,5,$color,$color)
	$s.draw_circle($x+$text_w+330,$y+220,5,$color,$color)
	$s.draw_rect($x+305,$y+201,$x+$text_w+331,$y+225,$color,$color)
	$s.draw_rect($x+301,$y+205,$x+$text_w+335,$y+221,$color,$color)
	$s.write($x+306,$y+206,black,$name)
	$keycolor = 0

function @page($p:number,$s:panel)
	$s.text_size(1)
	if $p == 1
		@keyboardKeys(-270,16-40,"Alt",$s)
		@keyboardKeys(-270,76-40,"Esc",$s)
		@keyboardKeys(-270,136-40,"Enter",$s)
		$s.text_align(center)
		$s.write(0,-105,color(0,200,200),"Essential shortcuts")
		$s.text_align(left)
		$s.write(30, -60,color(200,200,200), "Right click to grab cursor for mouselook")
		$s.write(80,30-40,color(200,200,200),"To release the cursor, use the left ALT key.\n- Quick press: Toggle mode\n- Hold: Temporary mode")
		$s.write(80,89-40,color(200,200,200),"Hold to exit the game")
		$s.write(90,149-40,color(200,200,200),"Toggle chat window")
	elseif $p == 2
		@keyboardKeys(-270,-90,"F1",$s)
		@keyboardKeys(-270,-55,"F2",$s)
		@keyboardKeys(-270,-20,"F3",$s)
		@keyboardKeys(-270,15,"F4",$s)
		@keyboardKeys(-270,65,"F11",$s)
		@keyboardKeys(-270,100,"F12",$s)
		$s.text_align(center)
		$s.write(0,-105,color(0,200,200),"Function Keys")
		$s.text_align(left)
		$s.write(80,-77,color(200,200,200),"Help and Settings")
		$s.write(80,-42,color(200,200,200),"Toggle Drone mode")
		$s.write(192,-42,color(150,150,150),"(No Clip)")
		$s.write(80,-7,color(200,200,200),"Hide user interface")
		$s.write(80,28,color(200,200,200),"Admin Menu")
		$s.write(80,78,color(200,200,200),"Fullscreen")
		$s.write(80,113,color(200,200,200),"Screenshot")
	elseif $p == 3
		$panel.draw_rect(300-80,78,300+80,360,color(60,60,60),color(60,60,60))
		@keyboardKeys(-40,-61,"Q",$s,color(80,200,150))
		@keyboardKeys(14,-61,"E",$s,color(80,200,150))
		@keyboardKeys(-13,-61,"W",$s)
		@keyboardKeys(-40,-35,"A",$s)
		@keyboardKeys(-13,-35,"S",$s)
		@keyboardKeys(14,-35,"D",$s)
		@keyboardKeys(-22,27,"CTRL",$s)
		@keyboardKeys(-37,90,"  SPACE  ",$s)
		@keyboardKeys(170,-61,"R",$s)
		@keyboardKeys(170,9,"F",$s)
		@keyboardKeys(170,79,"L",$s)
		@keyboardKeys(-209,-61,"TAB",$s)
		@keyboardKeys(-223,9,"1",$s)
		@keyboardKeys(-187,9,"9",$s)
		@keyboardKeys(-205,79,"J",$s)
		$s.text_align(center)
		$s.write(0,-105,color(0,200,200),"Basic Control Layout")
		$s.write(0,-72,color(80,200,150),"Player Roll")
		$s.write(0,2,white,"Player movement")
		$s.write(0,65,white,"Crouch/Down")
		$s.write(0,128,white,"Jump/Up")
		$s.write(185,-20,white,"Sit on seat (Hold to exit)")
		$s.write(185,50,white,"Interact with component")
		$s.write(185,116,white,"Headlight")
		$s.write(-187,-24,white,"Backpack (Inventory)")
		$s.write(-191,23,color(200,200,200),"-")
		$s.write(-187,46,white,"Select item/tool in your belt")
		$s.write(-191,116,white,"Jetpack")
	elseif $p == 4
		@keyboardKeys(-270,-90," K ",$s)
		@keyboardKeys(-270,-55," Z ",$s)
		@keyboardKeys(-270,-10," V ",$s,color(160,160,160))
		@keyboardKeys(-270,35," C ",$s)
		@keyboardKeys(-270,70," X ",$s)
		@keyboardKeys(-270,115,"SHIFT",$s,color(160,160,160))
		@keyboardKeys(-219,115,"F10",$s,color(160,160,160))
		$s.text_align(center)
		$s.write(0,-105,color(0,200,200),"Misceallenous")
		$s.text_align(left)
		$s.write(80,-77,color(200,200,200),"Third person view (zoom with mouse wheel)")
		$s.write(80,-42,color(200,200,200),"Zoom")
		$s.write(80,3,color(200,200,200),"Get info or edit component")
		$s.write(80,48,color(200,200,200),"Configure the current tool")
		$s.write(80,83,color(200,200,200),"Use tool's special mode")
		$s.write(130,128,color(200,200,200),"Respawn (drops inventory in adventure mode)")
	elseif $p == 5
		$s.text_align(center)
		$s.write(0,-105,color(0,200,200),"HUDs")
		$s.write(0,-40,color(200,200,200),"This interface was designed entirely using the tools available in the game.\n\nYou may create your own HUDs using in-game coding\nand display various information on the screen.\n\nTo create your own interface or disable this one,\ngo to the settings by pressing F1, then select the HUD tab.")
		$s.write(0,40,color(200,200,200),"Join our discord channel to get help and share your creations.")
	
function @menu($s:panel)
	$s.newline_spacing(5)
	$s.text_align(center)
	$s.text_size(3)
	$s.draw(0,0,color(0,0,0,200),$panel.width,$panel.height)
	$s.draw(0,9,color(255,255,255,30),600,30)
	$s.draw_rect(10,78,590,360,color(255,255,255,50),color(255,255,255,50))
	$s.write(0,-176,white,"Welcome to Archean")
	$s.text_size(2)
	$s.write(0,-141,color(200,200,200),"README")
	; Previous/Next arrows
	if $page > 1
		$s.draw_triangle(225,370,215,380,225,390,color(170,170,170),color(170,170,170))
		$s.draw_rect(226,375,260,386,color(170,170,170),color(170,170,170))
	if $page < 5
		$s.draw_triangle(375,370,385,380,375,390,color(170,170,170),color(170,170,170))
		$s.draw_rect(340,375,375,386,color(170,170,170),color(170,170,170))
	if $s.button_rect(215,370,260,391,color(0,0,0,0),color(0,0,0,0))
		if $page > 1
			$page--
	if $s.button_rect(340,370,385,391,color(0,0,0,0),color(0,0,0,0))
		if $page < 5
			$page++
	; Quit button
	var $mouse_x = mouse_x-$s.x
	var $mouse_y = mouse_y-$s.y
	if $mouse_x > 590 and $mouse_x < 600 and $mouse_y > 0 and $mouse_y < 8
		$quitButtonColor = color(200,50,50)
	else
		$quitButtonColor = white
	$s.draw_line(592,7,598,1,$quitButtonColor)
	$s.draw_line(592,2,598,8,$quitButtonColor)
	if $s.button_rect($panel.width-10,0,$panel.width,9,color(0,0,0,0))
		$helpStatus = "close"
		$s.blank()
		return
	$s.text_size(1)
	$s.write(0, 182, color(170,170,170), text("Page:{}",$page))
	@page($page,$panel)

tick
	if $helpStatus == ""
		$helpDelay--
		if $helpDelay == 0
			$helpStatus = "open"
	if $helpStatus == "close"
		$helpButton.blank()
		$helpButton.set_position(screen_w-$helpButton.width,0)
		var $glowColor = color(20,20,20,100+abs(sin(time))*90)
		if $helpButton.button_circle($helpButton.width-12,12,6,$glowColor,$glowColor)
			$helpStatus = "open"
			$helpButton.blank()
			return
		for 13, 15 ($x)
			$helpButton.write($helpButton.width-$x,9,color(250,250,50),"i")
	elseif $helpStatus == "open"
		$panel.set_position($panel.x,20)
		$panel.blank()
		@menu($panel)
