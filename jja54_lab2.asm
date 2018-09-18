# Jack Anderson (jja54)
.data 
	small: .byte 200
	medium: .half 400
	large: .word 0
	
	.eqv NUM_ITEMS 5
	values: .word 0:NUM_ITEMS
	
.text
.globl main
main:
	lbu t0, small
	lhu t1, medium
	mul a0, t0, t1
	sw a0, large
	li v0 1
	syscall
	
	li s0, 0 #i variable
	
	ask_loop_top: # while(...)
		blt s0, NUM_ITEMS, ask_loop_body #if s0<NUM_ITEMS
		b ask_loop_exit
	ask_loop_body: # {
		li v0, 5
		syscall #ask for user input
		
		la t0, values #load inital address of array
		mul t1, s0, 4
		add t0, t0, t1
		sw v0 (t0) #looping through array, putting input into correct array value address
		
		add s0, s0, 1 #increment i, s0=s0+1
		b ask_loop_top
	ask_loop_exit: # }