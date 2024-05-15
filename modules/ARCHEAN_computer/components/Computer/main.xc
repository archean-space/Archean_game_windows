const $bios_version = "2.0"

const $h_offset = 20
var $scroll = 0
var $rndload = 0

function @selectProgram($program:text)
	blank(black)
	text_align(center)
	text_size(1)
	write(0,-20,cyan,"Running program")
	text_size(2)
	write(white,$program)
	load_program($program)

tick
	if processor_type == "XPU64-MINI"
		if programs_count == 1
			load_program(program_name(0))
		return
	
	blank(black)
	$rndload += random(1,6)
	draw(21,81,color(100,100,100),clamp($rndload,0,159),19)
	draw_rect(20,80,180,100,gray)
	
	if tick < 20
		write(60,105,cyan,"Initializing...")
		
	if tick > 20 and tick < 50
		write(40,105,cyan,"Detecting hardware...")
		
	if tick > 50
		text_align(top)
		draw(0,0,color(10,10,10),200,85)
		draw(0,83,color(20,20,20),200,90)
		draw(0,83,color(30,30,30),200,1)
		write(0,5,white, "AIO COMPUTER bios v" & $bios_version)
		
	if tick > 55
		text_align(top_left)
		write(0,0+$h_offset,cyan,text("Processor: {}", processor_type))
		
	if tick > 60
		write(0,10+$h_offset,cyan,text("Frequency: {} tick/s", system_frequency))
		
	if tick > 65
		if system_ipc == 0
			write(0,20+$h_offset,cyan,"Max IPC: UNLIMITED")
		elseif system_ipc < 1000
			write(0,20+$h_offset,cyan,text("Max IPC: {}", system_ipc))
		elseif system_ipc < 1000000
			write(0,20+$h_offset,cyan,text("Max IPC: {}k", system_ipc/1000))
		else
			write(0,20+$h_offset,cyan,text("Max IPC: {}M", system_ipc/1000000))
			
	if tick > 70
		if system_ram < 1000
			write(0,30+$h_offset,cyan,text("System RAM: {} values", system_ram))
		elseif system_ram < 1000000
			write(0,30+$h_offset,cyan,text("System RAM: {}k values", system_ram/1000))
		else
			write(0,30+$h_offset,cyan,text("System RAM: {}M values", system_ram/1000000))
		
	if tick > 75
		if system_storage == 0
			write(0,40+$h_offset,cyan,"Storage Capacity: NONE")
		else
			write(0,40+$h_offset,cyan,text("Storage Capacity: {} values", system_storage))
			
	if tick > 80
		write(0,50+$h_offset,cyan,text("I/O ports: {}", system_io))
		text_align(none)
		
	if tick > 85
		if system_storage
			var $count = programs_count
			if $count
				write(30,88,cyan,"SELECT A PROGRAM TO RUN:")
				repeat $count ($index)
					var $name = program_name($index)
					if 100+($index*14)+$scroll > 90
						if button(10,100+($index*14)+$scroll,gray,160,13)
							@selectProgram($name)
							return
						draw(11,101+($index*14)+$scroll,color(10,10,10),158,11)
						draw(15,103+($index*14)+$scroll,color(110,255,255),7,7)
						if size($name) >= 20
							write(25,103+($index*14)+$scroll,white, text("{}...", substring($name,0,20)))
						else
							write(25,103+($index*14)+$scroll,white, $name)
				if $count > 4
					if button(171,100,color(40,40,40),28,20)
						if $scroll < 0
							$scroll += 14
					if button(171,139,color(40,40,40),28,20)
						if $scroll > -($count-3) * 14
							$scroll -= 14
					
					var $upArrow = 0
					var $downArrow = 0
					if $scroll == 0
						$upArrow = -60
					else
						$upArrow = 0
					if $scroll == -($count-3) * 14
						$downArrow = -60
					else
						$downArrow = 0
						
					draw_triangle(175,114,185,104,195,114,color(120+$upArrow,120+$upArrow,120+$upArrow),color(120+$upArrow,120+$upArrow,120+$upArrow))
					draw_triangle(175,144,185,154,195,144,color(120+$downArrow,120+$downArrow,120+$downArrow),color(120+$downArrow,120+$downArrow,120+$downArrow))
			else
				write(48,115,color(130,30,30),"NO PROGRAMS FOUND")
		else
			write(48,115,color(130,30,30),"PLEASE INSERT HDD")
