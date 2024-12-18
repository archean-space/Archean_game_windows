var $status = "ERROR"
var $r:number
var $g:number
var $b:number

var $anim = 0
var $volume = 152.14

function @deco($type:text)
	if $type == "ERROR"
		$r = 100
		$g = 0
		$b = 0
	elseif $type == "LEAK" or $type == "TRANSFER"
		$r = 100
		$g = 100
		$b = 0
	elseif $type == "SEALED" or $type == "SAFE"
		$r = 0
		$g = 100
		$b = 20
	else
		$r = 40
		$g = 40
		$b = 40
	draw_rect(0,0,screen_w,screen_h,color($r,$g,$b))
	for 1,30 ($i)
		draw_rect($i,$i,screen_w-$i,screen_h-$i,color($r/($i+1),$g/($i+1),$b/($i+1)))
	
function @volume()
	text_align(center)
	; STATUS
	write(0,-30,cyan,"Status:")
	if $status == ""
		write(0,-20,color(100,40,40),"undefined")
	else
		write(0,-20,color($r,$g,$b),$status)
	; VOLUME
	write(0,-5,cyan,"Volume:")
	if $volume
		write(0,5,color(150,150,150),text("{0.0} m3",$volume))
	else
		write(0,5,color(100,40,40),"undefined")
	; SCAN
	if button_rect(20,65,80,85,color(60,60,60),color(10,10,10))
		print(15)
		if $anim == 0
			$anim = 30
			;scanVolume() CPP
	write(0,25,color(120,120,120),"SCAN")


tick
	if $anim > 0
		@deco($status)
		draw_rect(30-$anim,30-$anim,screen_w-(30-$anim),screen_h-(30-$anim),color(200-((30-$anim)*6.6),200-((30-$anim)*6.6),200-((30-$anim)*6.6)))
		@volume()
		$anim--
		if $anim == 0
			blank()
			@deco($status)
			@volume()

			
		;FONCTION C++	
; 	if $status != $t
; 		$status = $t
; 		blank()
; 		@deco($status)
; 		@volume()
				

init
	blank()
	@deco($status)
	@volume()

click
	print("58")
	@volume()


	