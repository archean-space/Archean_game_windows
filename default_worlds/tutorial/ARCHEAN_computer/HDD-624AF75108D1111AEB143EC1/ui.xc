update
	blank(black)
	text_align(center)
	text_size(1)
	write(0,-20,cyan,"Running program")
	text_size(2)
	write(white,program_name(0))
	text_size(1)
	
	var $speed = input_number(2,0) * 3.6
	write(0,45,gray,"SPEED")
	write(0,57,gray,text("{0} km/h",$speed))
	
	if input_number(9,0) && !input_number(5,0)
		draw_rect(20,40,180,120,gray,gray)
		text_size(2)
		write(0,-15,color(255,100,100),"Warning")
		text_size(1)
		newline_spacing(5)
		write(0,8,color(255,150,150),"You are currently in the\n passenger seat")