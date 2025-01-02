var $r:number
var $g:number
var $b:number
var $anim = 0

function @deco()
	var $status = status
	if $status == "LEAK"
		$r = 200
		$g = 0
		$b = 0
	elseif $status == "TRANSFER"
		$r = 200
		$g = 200
		$b = 0
	elseif $status == "AIRTIGHT"
		$r = 0
		$g = 200
		$b = 50
	else
		$r = 80
		$g = 80
		$b = 80
	draw_rect(0,0,screen_w,screen_h,color($r,$g,$b))
	for 1,30 ($i)
		draw_rect($i,$i,screen_w-$i,screen_h-$i,color($r/($i+1),$g/($i+1),$b/($i+1)))
	
function @volume()
	text_align(center)
	; STATUS
	write(0,-30,cyan,"Status:")
	if status == ""
		write(0,-20,color(100,40,40),"Perform a Scan")
	else
		write(0,-20,color($r,$g,$b),status)
	; VOLUME
	write(0,-5,cyan,"Volume:")
	if volume
		write(0,5,color(150,150,150),text("{0.0} m³",volume))
	else
		write(0,5,color(100,40,40),"Invalid Volume")
	; SCAN
	if button_rect(20,65,80,85,color(60,60,60),color(10,10,10))
		if $anim == 0
			$anim = 30
			scan()
	write(0,25,color(120,120,120),"SCAN")

init
	blank()
	@deco()
	@volume()

tick
	output.0(level,volume,status)
	if $anim > 0
		@deco()
		draw_rect(30-$anim,30-$anim,screen_w-(30-$anim),screen_h-(30-$anim),color(200-((30-$anim)*6.6),200-((30-$anim)*6.6),200-((30-$anim)*6.6)))
		@volume()
		$anim--
		if $anim == 0
			blank()
			@deco()
			@volume()

click
	@volume()

status
	blank()
	@deco()
	@volume()
