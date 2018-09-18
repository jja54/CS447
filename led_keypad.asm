
# MMIO Registers
.eqv DISPLAY_CTRL 0xFFFF0000
.eqv DISPLAY_KEYS 0xFFFF0004
.eqv DISPLAY_BASE 0xFFFF0008

# Display stuff
.eqv DISPLAY_W         64
.eqv DISPLAY_H         64
.eqv DISPLAY_W_SHIFT   6

# LED Colors
.eqv COLOR_BLACK   0
.eqv COLOR_RED     1
.eqv COLOR_ORANGE  2
.eqv COLOR_YELLOW  3
.eqv COLOR_GREEN   4
.eqv COLOR_BLUE    5
.eqv COLOR_MAGENTA 6
.eqv COLOR_WHITE   7

# Input key flags
.eqv KEY_NONE 0
.eqv KEY_U 0x01
.eqv KEY_D 0x02
.eqv KEY_L 0x04
.eqv KEY_R 0x08
.eqv KEY_B 0x10

# --------------------------------------------------------------------------------------------------
# returns a bitwise OR of the above key constants, indicating which keys are being held down.
input_get_keys:
	lw	v0, DISPLAY_KEYS
	jr	ra

# --------------------------------------------------------------------------------------------------
# copies the color data from display RAM onto the screen.
display_update:
	sw	zero, DISPLAY_CTRL
	jr	ra

# --------------------------------------------------------------------------------------------------
# copies the color data from display RAM onto the screen, and then clears display RAM.
display_update_and_clear:
	li	t0, 1
	sw	t0, DISPLAY_CTRL
	jr	ra

# --------------------------------------------------------------------------------------------------
# sets 1 pixel to a given color.
# (0, 0) is in the top LEFT, and Y increases DOWNWARDS!
# arguments:
#	a0 = x
#	a1 = y
#	a2 = color (use one of the constants above)
display_set_pixel:
	sll	t0, a1, DISPLAY_W_SHIFT
	add	t0, t0, a0
	add	t0, t0, DISPLAY_BASE
	sb	a2, (t0)
	jr	ra

# --------------------------------------------------------------------------------------------------
# fills a rectangle of pixels with a given color.
# there are FIVE arguments, and I was naughty and used 'v1' as a "fifth argument register."
# this is technically bad practice. sue me.
# arguments:
#	a0 = top-left corner x
#	a1 = top-left corner y
#	a2 = width
#	a3 = height
#	v1 = color (use one of the constants above)
display_fill_rect:
	# multiple of 4 width?
	and	t0, a2, 3
	beqz	t0, display_fill_rect_fast

	# turn w/h into x2/y2
	add	a2, a2, a0
	add	a3, a3, a1

	# turn y1/y2 into addresses
	li	t0, DISPLAY_BASE
	sll	a1, a1, DISPLAY_W_SHIFT
	add	a1, a1, t0
	add	a1, a1, a0
	sll	a3, a3, DISPLAY_W_SHIFT
	add	a3, a3, t0

	move	t0, a1
_fill_loop_y:
	move	t1, t0
	move	t2, a0
_fill_loop_x:
	sb	v1, (t1)
	addi	t1, t1, 1
	addi	t2, t2, 1
	blt	t2, a2, _fill_loop_x

	addi	t0, t0, DISPLAY_W
	blt	t0, a3, _fill_loop_y

	jr	ra

# --------------------------------------------------------------------------------------------------
# exactly the same as display_fill_rect, but works faster for rectangles whose width
# is a multiple of 4.
# IF WIDTH IS NOT A MULTIPLE OF 4, IT WILL DO WEIRD THINGS.
# arguments:
#	same as display_fill_rect.
display_fill_rect_fast:
	# duplicate color across v1
	and	v1, v1, 0xFF
	mul	v1, v1, 0x01010101

	# a2 = x2
	add	a2, a2, a0

	# a3 = y2
	add	a3, a3, a1

	# t0 = display base address
	li	t0, DISPLAY_BASE

	# a1 = start address
	sll	a1, a1, DISPLAY_W_SHIFT
	add	a1, a1, t0
	add	a1, a1, a0

	# a3 = end address
	sll	a3, a3, DISPLAY_W_SHIFT
	add	a3, a3, t0

	# t0 = current row's start address
	move	t0, a1
_fast_fill_loop_y:
	move	t1, t0 # t1 = current address
	move	t2, a0 # t2 = current x
_fast_fill_loop_x:
	sb	v1, (t1)
	addi	t1, t1, 4
	addi	t2, t2, 4
	blt	t2, a2, _fast_fill_loop_x

	addi	t0, t0, DISPLAY_W
	blt	t0, a3, _fast_fill_loop_y

	jr	ra