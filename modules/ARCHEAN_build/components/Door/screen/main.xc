tick
	blank(black)
	
	if isOpen
		write(12,4, green, "OPEN")
		draw(4,18, white, 40, 30)
		write(9,29, black, "CLOSE")
	elseif isClosed
		write(6,4, red, "CLOSED")
		draw(4,18, white, 40, 30)
		write(12,29, black, "OPEN")
	elseif isOpening
		write(3,4, yellow, "OPENING")
	elseif isClosing
		write(3,4, yellow, "CLOSING")
	
	output.0 (isOpen)

click
	if isOpen
		close()
	elseif isClosed
		open()

input.0 ($action:number)
	if $action == 1
		if isClosed
			open()
	elseif $action == 0
		if isOpen
			close()
