tick
	blank(black)
	
	if isOpen
		write(12,2, green, "DOOR")
		if button(4,11, white, 40, 18)
			close()
		write(9,16, black, "CLOSE")
	elseif isClosed
		write(12,2, red, "DOOR")
		if button(4,11, white, 40, 18)
			open()
		write(12,16, black, "OPEN")
	elseif isOpening
		write(3,14, yellow, "OPENING")
	elseif isClosing
		write(3,14, yellow, "CLOSING")
	
	draw(0, 31, color(5,5,5), 48, 1)
	
	if isDocked
		write(6,32+2, green, "DOCKED")
		if button(4,32+11, white, 40, 18)
			undock()
		write(6,32+16, black, "UNDOCK")
	elseif canDock
		write(3,32+2, green, "DOCKING")
		if button(4,32+11, white, 40, 18)
			undock()
		write(6,32+16, black, "DISARM")
	else
		write(3,32+2, red, "DOCKING")
		if button(4,32+11, white, 40, 18)
			dock()
		write(15,32+16, black, "ARM")
	
	output.0 (isOpen)
	output.1 (isDocked)

input.0 ($door:number, $dock:number)
	if $door
		if isClosed
			open()
	else
		if isOpen
			close()
	if $dock
		dock()
	else
		undock()
