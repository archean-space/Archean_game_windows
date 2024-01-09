var $saveTimer = 0
var $resetTimer = 0
var $rolesTimer = 0

tick
	blank(color(1,1,1))

	
	; Save button
	if button(3,3,color(0,20,20),34,9)
		if $saveTimer == 0
			save()
			$saveTimer = 5
	write(8,4,black,"SAVE")

	; Save animation
	if $saveTimer > 0
		draw(3,4,color(0,200,200),34,9)
		$saveTimer--
		
		
		
	; Reset button
	if button(3,27,color(0,20,20),34,9)
		if $resetTimer == 0
			reset()
			$resetTimer = 5
	write(5,28,black,"RESET")

	; Reset animation
	if $resetTimer > 0
		draw(3,27,color(0,200,200),34,9)
		$resetTimer--



	; Roles button
	if button(3,15,color(0,20,0),34,9) && (user == owner || owner == "")
		if $rolesTimer == 0
			$rolesTimer = 5
			roles(user)
	write(5,16,black,"ROLES")

	; Roles animation
	if $rolesTimer > 0
		draw(3,14,color(0,200,0),34,9)
		$rolesTimer--

