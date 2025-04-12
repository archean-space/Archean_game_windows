var $targetTemp = target_temperature
var $currentTemp = temperature

function @color($temp:number):number
	var $r = 60/3000*$temp
	var $g = 60/3000*(3000-$temp)
	return color($r,$g,0)

function @main()
	blank(color(10,10,10))
	draw_rect(0,0,screen_w,33,@color($currentTemp),@color($currentTemp))
	draw_rect(0,33,screen_w,screen_h,color(50,50,50,50),color(50,50,50,50))
	draw_rect(0,33,screen_w,34,color(70,70,70),color(70,70,70))
	if button(10,54,gray,15,15)
		$targetTemp -= 100
	if button(28,54,gray,15,15)
		$targetTemp -= 10
	if button(104,54,gray,15,15)
		$targetTemp += 10
	if button(122,54,gray,15,15)
		$targetTemp += 100
	if $targetTemp > 3000
		$targetTemp = 3000
	if $targetTemp < 300
		$targetTemp = 300
	set_temperature($targetTemp)

	$currentTemp = lerp($currentTemp, temperature, 0.01)
	text_align(top)
	write(-57,57,white,"<<")
	write(-39,57,white,"<")
	write(37,57,white,">")
	write(55,57,white,">>")
	write(0,6,white,"Current Temperature")
	write(0,19,white,text("{0} K",$currentTemp))
	write(0,39,white,"Target Temperature")
	write(0,57,white,text("{0} K",$targetTemp))
	output.0($currentTemp)

tick
	@main()

input.0 ($value:number, $purge:number)
	if $value
		$targetTemp = $value
		set_temperature($targetTemp)
	if $purge
		purge()
