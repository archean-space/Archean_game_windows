include "vertical_ui.xc"

var $clock = 0

init
	$btn_horizontal_padding = 25

tick
	$clock++
	
	@begin()
	
	@writeLine("Initializing...")
	
	if $clock > 25
		@writeLine("Detecting available hardware...")
		
	if $clock > 30
		@writeLine(text("Processor Type: {}", processor_type))
		@writeLine(text("Frequency: {} ticks per second", system_frequency))
		if system_ipc == 0
			@writeLine("Max IPC: UNLIMITED")
		else
			@writeLine(text("Max IPC: {}k", system_ipc/1000))
		
	if $clock > 35
		@writeLine(text("System RAM: {}k values", system_ram/1000))
		
	if $clock > 40
		if system_storage == 0
			@writeLine("Storage Capacity: NONE")
		else
			@writeLine(text("Storage Capacity: {} values", system_storage))
		
	if $clock > 45
		@writeLine(text("I/O ports: {}", system_io))
		
	if $clock > 50
		@margin(8)
		if system_storage
			var $c = programs_count
			if $c
				@writeLine("PLEASE SELECT A PROGRAM TO RUN:")
				@margin(2)
				repeat $c ($index)
					var $name = program_name($index)
					if @button($name)
						load_program($name)
						@_clear()
						@writeLine("Running program [" & $name & "]")
			else
				@writeLine("NO PROGRAMS FOUND")
		else
			@writeLine("PLEASE INSERT HDD")
	
	@end()
