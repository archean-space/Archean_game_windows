const $sleepTime = 7500 ; ticks (7500 ticks = 5 minutes)
var $steamTemp = 0
var $tick = 0
var $idle = $sleepTime
var $CooldownAnim = 0
var $bgColor = color(5,15,25)
var $bColor = color(0,160,210)
var $tColor = color(0,255,125)
var $gColor = color(150,150,150)
var $nuclearLogoColor = color(255,0,50)
var $lastEfficiency = 0
var $lifetimeEta = ""
const $depletedValue = 0.045

function @standby()
	blank(color(5,15,25,2))
	text_align(center)
	draw(0,screen_h/2-50,color(255,255,255,20),screen_w,100)
	text_size(3)
	write(0,-18,$tColor,"STANDBY MODE")
	text_size(2)
	write(0,20,color(100,100,100),"Click to Wake UP")

function @coreTemp($x:number,$y:number)
	text_align(top_left)
	write($x+15,$y,$tColor,"Temperature")
	repeat 4 ($i)
		var $tSize = (size("Zone 0:"))
		write($x+5,($y+15)+($i*15),white,text("Zone {}: ", $i+1))
		write($x+($tSize*7),($y+15)+($i*15),$gColor,text("{0.00}k",get_temperature($i)))

function @rods($x:number,$y:number)
	write($x+13,$y,$tColor,"Control Rods")
	repeat 4 ($i)
		var $tSize = (size("Rod 0:"))
		write($x+5,($y+15)+($i*15),white,text("Rod {}:", $i+1))
		write($x+($tSize*7)+2,($y+15)+($i*15),$gColor,text("{0.00}%", get_control_rod($i)*100))
	;top left
	draw(123,55,color(100,100,100),10,25)
	draw(125,55,$bgColor,6,23)
	draw(125,36+(19*(1-get_control_rod(0))),$tColor,6,23)
	draw(123,34+(19*(1-get_control_rod(0))),$tColor,10,2)
	;top right
	draw(269,55,color(100,100,100),10,25)
	draw(271,55,$bgColor,6,23)
	draw(271,36+(19*(1-get_control_rod(1))),$tColor,6,23)
	draw(269,34+(19*(1-get_control_rod(1))),$tColor,10,2)
	;bottom left
	draw(123,113,color(100,100,100),10,25)
	draw(125,113,$bgColor,6,23)
	draw(125,94+(19*(1-get_control_rod(2))),$tColor,6,23)
	draw(123,92+(19*(1-get_control_rod(2))),$tColor,10,2)
	;bottom right
	draw(269,113,color(100,100,100),10,25)
	draw(271,113,$bgColor,6,23)
	draw(271,94+(19*(1-get_control_rod(3))),$tColor,6,23)
	draw(269,92+(19*(1-get_control_rod(3))),$tColor,10,2)


function @neutrons($x:number,$y:number)
	write($x+16,$y,$tColor,"Neutrons")
	repeat 4 ($i)
		var $tSize = size("Flux 0:")
		write($x-4,($y+15)+($i*15),white,text("Flux {}: ", $i+1))
		var $neutrons = get_neutrons($i)
		var $n = text("{0}", $neutrons)
		if $neutrons > 1000000000
			$n = text("{0.00}B", $neutrons/1000000000)
		elseif $neutrons > 1000000
			$n = text("{0.00}M", $neutrons/1000000)
		elseif $neutrons > 1000
			$n = text("{0.00}K", $neutrons/1000)
		write($x+($tSize*7)-8,($y+15)+($i*15),$gColor,$n)


function @nuclearLogo($x:number,$y:number)
	var $r = 0
	var $g = 0
	var $b = 0
	if $steamTemp <= 300
		$r = 0
		$g = clamp(($steamTemp / 300) * 255, 0, 255)
		$b = clamp(255 - (($steamTemp / 300) * (255 - 25)), 0, 255)
	else 
		$r = clamp((($steamTemp - 300) / 900) * 255, 0, 255)
		$g = clamp(255 - ((($steamTemp - 300) / 900) * 255), 0, 255)
		$b = 25
	$nuclearLogoColor = color($r, $g, $b)
	if status == "CRITICAL" and round(time * 5) % 2
		$nuclearLogoColor = color(255,255,50)
	draw_circle($x,$y,50,$nuclearLogoColor,$nuclearLogoColor)
	draw_triangle($x-25,$y-50,$x+25,$y-50,$x,$y,$bgColor,$bgColor)
	draw_triangle($x+56,$y,$x+31,$y+47,$x,$y,$bgColor,$bgColor)
	draw_triangle($x-31,$y+47,$x-56,$y,$x,$y,$bgColor,$bgColor)
	draw_circle($x,$y,13,$nuclearLogoColor,$nuclearLogoColor)
	draw_circle($x,$y,8,$bgColor,$bgColor)
	for 51, 53 ($i)
		draw_circle($x,$y,$i,$nuclearLogoColor)

function @coolant($x:number,$y:number)
	text_align(left)
	text_size(1)
	write($x+0,$y,$tColor,"Coolant Flow")
	write($x+0,$y+14,green,text("+{0.00} kg/s", flow))

function @scram($x:number,$y:number)
	text_align(center)
	draw($x-60,$y-42,color(255,255,255,20),120,35)
	write(0,$y-154,color(180,180,180),"STATUS")
	text_size(2)
	write(0,$y-138,white,status)
	var $safe = max(get_temperature(0),get_temperature(1),get_temperature(2),get_temperature(3)) < 373 && max(get_neutrons(0),get_neutrons(1),get_neutrons(2),get_neutrons(3)) < 1000
	var $scram = status == "SCRAM"
	if $scram && !$safe
		if $tick % 15 == 0
			$CooldownAnim++
			if $CooldownAnim > 3
				$CooldownAnim = 0
		var $t = substring("COOLDOWN...", 0, 8+$CooldownAnim)
		write(0,$y-106,cyan,$t)
	else
		var $statusColor = if($safe && $scram, color(200,200,0), color(255,0,50))
		if button_rect($x-40,$y,$x+40,$y+28,$statusColor,$statusColor)
			if $safe
				reset()
			else
				scram()
		draw($x-40,$y,$bgColor,2,2)
		draw($x+38,$y,$bgColor,2,2)
		draw($x-40,$y+26,$bgColor,2,2)
		draw($x+38,$y+26,$bgColor,2,2)
		write(0,$y-106,white,if($safe && $scram, "RESET", "SCRAM"))


function @temp($x:number,$y:number)
	text_align(left)
	write(17,90,$tColor,"Fluid Input:")
	write(18,105,cyan,text(">>> {0.00}K", input_temperature))

	write(309,90,$tColor,"Fluid Output:")
	write(310,105,orange,text(">>> {0.00}K", output_temperature))

function @fuel()
	text_align(left)
	write(322,2,$tColor,"Lifetime")
	var $currentEfficiency = min(get_efficiency(0),get_efficiency(1),get_efficiency(2),get_efficiency(3))
	var $delta = $lastEfficiency - $currentEfficiency
	if $delta > 0 and status == "ACTIVE"
		var $eta = (($currentEfficiency - $depletedValue) / $delta) / 25
		if $eta > 3153600000
			$lifetimeEta = "> 100 years"
		elseif $eta > 31536000
			$lifetimeEta = text("~ {0.0} years", $eta/31536000)
		elseif $eta > 2592000
			$lifetimeEta = text("~ {0.0} months", $eta/2592000)
		elseif $eta > 86400
			$lifetimeEta = text("~ {0.0} days", $eta/86400)
		elseif $eta > 3600
			$lifetimeEta = text("~ {0.0} hours", $eta/3600)
		elseif $eta > 60
			$lifetimeEta = text("~ {0.0} minutes", $eta/60)
		elseif $eta < 0
			$lifetimeEta = "Depleted"
		elseif $eta < 60
			$lifetimeEta = text("~ {0.0} seconds", $eta)
		write(308,15,color(150,150,150),$lifetimeEta)
	else
		write(308,15,color(150,150,150), if($currentEfficiency <= $depletedValue, "Depleted", "Unknown"))
	$lastEfficiency = $currentEfficiency


function @grid()
	draw(0,0,$bColor,400,2)
	draw(0,238,$bColor,400,2)
	draw(0,0,$bColor,2,240)
	draw(398,0,$bColor,2,240)
	draw(0,27,$bColor,400,2)
	draw(106,28,$bColor,2,240)
	draw(294,28,$bColor,2,240)
	draw(0,113,$bColor,106,2)
	draw(0,198,$bColor,106,2)
	; draw(294,113,$bColor,106,2)
	draw(294,198,$bColor,106,2)
	draw(106,152,$bColor,188,2)
	draw(294,152,$bColor,106,2)


function @meltdown()
	blank(black)
	text_size(6)
	text_align(center)
	draw(0,screen_h/2-50,color(255,0,50,40),screen_w,100)
	write(0,0,color(200,0,50),"MELTDOWN")


function @screen()
	blank($bgColor)
	$steamTemp = max(get_temperature(0),get_temperature(1),get_temperature(2),get_temperature(3))
	text_align(top)
	text_size(2)
	write(6,6,white,"Compact Fission Reactor")
	text_size(1)
	@grid()
	@coreTemp(3,120)
	@rods(3,35)
	@nuclearLogo(200,90)
	@neutrons(306,35)
	@temp(10,205)
	@fuel()
	@coolant(310,49)
	@scram(screen_w/2,203)

tick
	$tick++
	if $idle > 0
		$idle--
	if status == "MELTDOWN"
		@meltdown()
		$idle = $sleepTime
	elseif $idle <= 0
		@standby()
	else
		@screen()
	output.0 (get_temperature(0),get_temperature(1),get_temperature(2),get_temperature(3),get_control_rod(0),get_control_rod(1),get_control_rod(2),get_control_rod(3),get_neutrons(0),get_neutrons(1),get_neutrons(2),get_neutrons(3),input_temperature,output_temperature,flow, status)


input.0 ($rod0:number,$rod1:number,$rod2:number,$rod3:number,$send_neutrons:number,$scram:number)
	set_control_rod(0, $rod0)
	set_control_rod(1, $rod1)
	set_control_rod(2, $rod2)
	set_control_rod(3, $rod3)
	send_neutrons($send_neutrons)
	if $scram
		scram()

click
	$idle = $sleepTime
