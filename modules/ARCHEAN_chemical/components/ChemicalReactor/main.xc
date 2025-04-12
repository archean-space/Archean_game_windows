#SCREEN 150 75

var $state = 0
var $currentTemp = 0
var $targetTemp = 0
var $statusColor = red

function @main()
	blank(color(10,10,10))
	if button(0,0,$statusColor,13,13)
		if $state == 0
			$state = 1
			$statusColor = green
		else
			$state = 0
			$statusColor = red
	draw_circle(6,6,5,white)
	draw(5,6,$statusColor,3,5)
	draw(6,7,white,1,5)

	if button(10,50,gray,15,15)
		if $targetTemp > 100
			$targetTemp -= 100
		else
			$targetTemp = 0
	if button(28,50,gray,15,15)
		if $targetTemp >= 10
			$targetTemp -= 10
	if button(104,50,gray,15,15)
		$targetTemp += 10
	if button(122,50,gray,15,15)
		$targetTemp += 100
	if $targetTemp > 3000
		$targetTemp = 3000

	text_align(top)
	write(-57,53,white,"<<")
	write(-39,53,white,"<")
	write(37,53,white,">")
	write(55,53,white,">>")
	write(0,5,white,"Current Temperature")
	write(0,18,white,text("{0.00} K",$currentTemp))
	write(0,35,white,"Target Temperature")
	write(0,53,white,text("{0} K",$targetTemp))

tick
	@main()
