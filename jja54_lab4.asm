.data
	opcode: .asciiz "\nopcode = "
	rs: .asciiz "\nrs = "
	rt: .asciiz "\nrt = "
	immediate: .asciiz "\nimmediate = "

.text

encode_instruction:
	push	ra
	
	sll t0, a0, 26 #t0 = a0 << 26, encode opcode
	sll t1, a1, 21 #t1 = a1 << 21, encode rs
	sll t2, a2, 16 #t2 = a2 << 16, encode rt
	#don't need to shift immediate, already at 0
	#but need a 16bit mask to get the right value:
	and t3, a3, 0xFFFF
	
	#OR-ing it together:
	or t0, t0, t1 #puts opcode and rs together
	or t1, t2, t3 #puts rt and immediate together
	or a0, t0, t1 #puts the two halves together into a0 so we can syscall
	
	li	v0, 34
	syscall
	
	li a0, '\n'
	li v0, 11
	syscall

	pop	ra
	jr	ra

decode_instruction:
	push	ra
	push s0
	
	move s0, a0
	
	la a0, opcode
	li v0, 4
	syscall
	srl t0, s0, 26 #t0 = s0 >> 26
	and a0, t0, 0x3F
	li v0, 1
	syscall
	
	la a0, rs
	li v0, 4
	syscall
	srl t0, s0, 21 #t0 = s0 >> 21
	and a0, t0, 0x1F
	li v0, 1
	syscall
	
	la a0, rt
	li v0, 4
	syscall
	srl t0, s0, 16 #t0 = s0 >> 16
	and a0, t0, 0x1F
	li v0, 1
	syscall
	
	la a0, immediate
	li v0, 4
	syscall
	#move t0, s0
	and t0, s0, 0xFFFF
	sll t0, t0, 16
	sra t0, t0, 16 # shift right *arithmetic*
	move a0, t0
	li v0, 1
	syscall

	pop s0
	pop	ra
	jr	ra

.globl main
main:
	# addi t0, s1, 123
	li	a0, 8
	li	a1, 17
	li	a2, 8
	li	a3, 123
	jal	encode_instruction

	# beq t0, zero, -8
	li	a0, 4
	li	a1, 8
	li	a2, 0
	li	a3, -8
	jal	encode_instruction

	li	a0, 0x2228007B
	jal	decode_instruction

	li	a0, '\n'
	li	v0, 11
	syscall

	li	a0, 0x1100fff8
	jal	decode_instruction

	# exit the program cleanly
	li	v0, 10
	syscall
