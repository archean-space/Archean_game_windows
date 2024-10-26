var $saveTimer = 0
var $resetTimer = 0
var $rolesTimer = 0
var $debounce = ""


function @ownerpad()
	output.0("")
	blank(color(16,16,16))

	; Save button
	if button(3,3,color(0,128,128),34,9)
		if $saveTimer == 0
			save()
			output.0("save")
			$saveTimer = 6
	write(8,4,black,"SAVE")
	
	; Reset button
	if button(3,27,color(0,128,128),34,9)
		if $resetTimer == 0
			reset()
			output.0("reset")
			$resetTimer = 6
	write(5,28,black,"RESET")

	; Roles button
	if button(3,15,color(0,128,0),34,9) && (user == owner || owner == "")
		if $rolesTimer == 0
			$rolesTimer = 6
			roles(user)
	write(5,16,black,"ROLES")

		
tick
	; Save animation
	if $saveTimer > 0
		draw(3,3,color(0,255,255),34,9)
		$saveTimer--
		if $saveTimer == 0
			@ownerpad()
	; Reset animation
	if $resetTimer > 0
		draw(3,27,color(0,255,255),34,9)
		$resetTimer--
		if $resetTimer == 0
			@ownerpad()
	; Roles animation
	if $rolesTimer > 0
		draw(3,15,color(0,255,0),34,9)
		$rolesTimer--
		if $rolesTimer == 0
			@ownerpad()

init
	@ownerpad()
click
	@ownerpad()



input.0 ($func:text)
	if $debounce != $func
		if $func == "save"
			save()
			output.0("save")
		if $func == "reset"
			reset()
			output.0("reset")
	$debounce = $func
