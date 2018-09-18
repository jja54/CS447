.include "led_keypad.asm"
# Jack Anderson (jja54)

.data 
	x_coord: .word 32
	y_coord: .word 32 
.text
check_input:
	push ra
	
	jal input_get_keys
	beq v0, 0x04, blockLEFT #pressing left
	beq v0, 0x08, blockRIGHT #pressing right
	beq v0, 0x01, blockUP #pressing up
	beq v0, 0x02, blockDOWN #pressing down
	b skip_to_end
	blockLEFT:
		lw t0, x_coord
		sub t0, t0, 1
		sw t0, x_coord
		b skip_to_end
	blockRIGHT:
		lw t0, x_coord
		add t0, t0, 1
		sw t0, x_coord
		b skip_to_end
	blockUP:
		lw t0, y_coord
		sub t0, t0, 1
		sw t0, y_coord
		b skip_to_end
	blockDOWN:
		lw t0, y_coord
		add t0, t0, 1
		sw t0, y_coord
		b skip_to_end
	skip_to_end:
		lw t0, x_coord
		lw t1, y_coord
		and t0, 63
		and t1, 63
		sw t0, x_coord
		sw t1, y_coord
		pop ra
		jr ra

draw_dot:
	push ra
	
	lw a0, x_coord
	lw a1, y_coord
	li a2, 7
	jal display_set_pixel
	
	pop ra
	jr ra

.globl main
main:
	main_loop:
		li t0, 1000
		li t1, 60
		div a0, t0, t1 #maybe this is more accurate than just putting in 16?
		li v0, 32 #trying to avoid drift
		syscall
		
		jal check_input
		jal draw_dot
		jal display_update_and_clear
		
		
		b main_loop	
