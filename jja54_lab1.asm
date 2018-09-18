# Jack Anderson (jja54)

print_int:
	li	v0, 1
	syscall
	jr	ra
	
newline:
	li	a0, '\n'
	li	v0, 11
	syscall
	li	v0, 1
	jr	ra

.globl main
main:
	li	a0, 1234
	li	v0, 1
	syscall
	# int numbers = 1234;
	# System.out.println(numbers);
	jal	newline
	li	a0, 5678
	jal	print_int