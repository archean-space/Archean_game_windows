#NODES {"nodes":[{"id":"NODE00000000106EAF21EB14EEE8","inputTypes":[0,0,0,0,0],"inputValues":["","","","",""],"inputs":["NODE00000000E8F0A224EB141687","","","NODE0000000070068B27EB149224",""],"ioNumber":3,"outputType":2,"pos":{"x":410.0,"y":370.0},"size":{"x":163.0,"y":166.0},"title":"output.3","type":"OutputNode"},{"id":"NODE0000000041696322EB14EA73","inputTypes":[0,0,0,0,0],"inputValues":["","","","",""],"inputs":["NODE00000000E8F0A224EB141687","NODE00000000278EC424EB146612","","NODE0000000070068B27EB149224",""],"ioNumber":4,"outputType":2,"pos":{"x":410.0,"y":170.0},"size":{"x":163.0,"y":166.0},"title":"output.4","type":"OutputNode"},{"id":"NODE0000000088508622EB149AFA","inputTypes":[0,0,0,0,0],"inputValues":["","","","",""],"inputs":["NODE000000001A38FF25EB143E17","","","NODE0000000070068B27EB149224",""],"ioNumber":10,"outputType":2,"pos":{"x":680.0,"y":370.0},"size":{"x":163.0,"y":166.0},"title":"output.10","type":"OutputNode"},{"id":"NODE00000000860EF122EB144A75","inputTypes":[0,0,0,0,0],"inputValues":["","","","",""],"inputs":["NODE000000001A38FF25EB143E17","NODE00000000278EC424EB146612","","NODE0000000070068B27EB149224",""],"ioNumber":11,"outputType":2,"pos":{"x":680.0,"y":170.0},"size":{"x":163.0,"y":166.0},"title":"output.11","type":"OutputNode"},{"channel":1,"id":"NODE00000000E8F0A224EB141687","inputs":[],"ioNumber":5,"outputType":0,"pos":{"x":10.0,"y":170.0},"size":{"x":270.0,"y":66.0},"title":"input.5","type":"InputNode"},{"channel":2,"id":"NODE00000000278EC424EB146612","inputs":[],"ioNumber":5,"outputType":0,"pos":{"x":10.0,"y":270.0},"size":{"x":222.0,"y":66.0},"title":"input.5","type":"InputNode"},{"id":"NODE000000001A38FF25EB143E17","inputTypes":[0],"inputValues":[""],"inputs":["NODE00000000E8F0A224EB141687"],"outputType":0,"pos":{"x":520.0,"y":100.0},"size":{"x":72.0,"y":45.0},"title":"NEGATIVE","type":"MathNode_NEGATIVE"},{"channel":3,"id":"NODE0000000070068B27EB149224","inputs":[],"ioNumber":5,"outputType":0,"pos":{"x":10.0,"y":370.0},"size":{"x":318.0,"y":66.0},"title":"input.5","type":"InputNode"},{"comment":"Inputs from the Driver's Seat","id":"NODE624AF75109D663ECEB14BA3D","inputs":[],"name":"comment","outputType":2,"pos":{"x":10.0,"y":30.0},"size":{"x":268.0,"y":67.5},"title":"comment","type":"CommentNode"},{"comment":"Outputs to Wheels\n\nWe use a Negative here because the wheels \nare reversed on the right side","id":"NODE624AF75136AE6CEFEB14AA5F","inputs":[],"name":"comment","outputType":2,"pos":{"x":630.0,"y":20.0},"size":{"x":359.0,"y":106.0},"title":"comment","type":"CommentNode"}]}

update
	var $_input_number_5_1 = input_number(5, 1)
	output_number(3, 0, $_input_number_5_1)
	var $_input_number_5_3 = input_number(5, 3)
	output_number(3, 3, $_input_number_5_3)
	output_number(4, 0, $_input_number_5_1)
	var $_input_number_5_2 = input_number(5, 2)
	output_number(4, 1, $_input_number_5_2)
	output_number(4, 3, $_input_number_5_3)
	output_number(10, 0, (-$_input_number_5_1))
	output_number(10, 3, $_input_number_5_3)
	output_number(11, 0, (-$_input_number_5_1))
	output_number(11, 1, $_input_number_5_2)
	output_number(11, 3, $_input_number_5_3)
