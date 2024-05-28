var $cursor = 0
var $currentCraft:text
var $categories:text
var $crafts : text
var $craftCount : number

var $upX : number
var $upY : number
var $downX : number
var $downY : number
var $initTime : number

init
	if $initTime == 0
		$initTime = time
	$crafts = crafts
	$upX = screen_w-14
	$upY = screen_h/4
	$downX = screen_w-14
	$downY = screen_h*3/4-2

tick
	blank()
	text_size(1)
	
	if time < $initTime+4
		if time > $initTime+1
			write(10,10,cyan,"Initializing Crafter...")
		return
	
	var $dpIndex = 0
	foreach $crafts ($category, $craftList)
		if button(0,(12*$dpIndex)-$cursor,color(10,10,10),screen_w-17,11)
			$categories.$category!!
		write(3,((12*$dpIndex)+2)-$cursor,color(60,60,60),$category)
		$dpIndex++
		if $categories.$category
			array $craftArray:text
			$craftArray.from($craftList,",")
			foreach $craftArray ($index, $craft)
				if button(0,(12*$dpIndex)-$cursor,color(10,10,10),screen_w-17,11)
					if $currentCraft == $craft
						$currentCraft = ""
						cancel_craft()
					else
						cancel_craft()
						start_craft($craft)
						$currentCraft = $craft
				if $currentCraft == $craft
					if progress > 0 and progress < 1
						draw(0,(12*$dpIndex)-$cursor,color(0,64,64,64),(screen_w-17)*progress,11)
					elseif progress == 1
						draw(0,(12*$dpIndex)-$cursor,color(0,128,0,64),screen_w-17,11)
					elseif progress < 0
						draw(0,(12*$dpIndex)-$cursor,color(30,15,15),screen_w-17,11)
				if $currentCraft == $craft
					write(6,(12*$dpIndex+2)-$cursor,color(20,80,0),$craft)
				else
					write(6,(12*$dpIndex+2)-$cursor,color(40,40,40),$craft)
				$dpIndex++

	if button(screen_w-16,0,color(20,20,20),15,screen_h/2)
		if $cursor > 0
			$cursor -= 50
			if $cursor < 0
				$cursor = 0
	if button(screen_w-16,screen_h/2+1,color(20,20,20),15,screen_h/2)
		$cursor = clamp($cursor + 50, 0, max(0,$dpIndex*12-screen_h/5*4))
	
	draw_triangle(0+$upX,0+$upY,10+$upX,0+$upY,5+$upX,-9+$upY,white,white)
	draw_triangle(0+$downX,0+$downY,10+$downX,0+$downY,5+$downX,9+$downY,white,white)

input.0 ($on:number, $craft:text)
	if time < $initTime+5
		return
	if $on
		if $craft
			$currentCraft = $craft
			start_craft($craft)
		elseif $currentCraft
			start_craft($currentCraft)
	
