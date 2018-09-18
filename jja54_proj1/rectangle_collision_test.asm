.include "convenience.asm"
.include "display.asm"

.text

# --------------------------------------------------------------------------------------------------

.globl main

check_bullet_collision:
	enter s0 s1
	li s0, 0
	li s1, 0
	_bullet_loop:
		beq s0, MAX_BULLETS, _skip_to_collision_end
			la t0, bullet_active
			add t0, t0, s0
			lb t0, (t0)
			add s0, s0, 1 #increment before check so if the if fails then it can jump back to loop top
			bne t0, 1, _bullet_loop #if not 1, go back to bullet loop, else:
				sub s0, s0, 1 #sub back down for correct bullet num
				la t0, bullet_x
				add t0, t0, s0
				lb a0, (t0) #bullet_x num in a0
				la t1, bullet_y
				add t1, t1, s0
				lb a1, (t1) #bullet_y num in a1
				add s0, s0, 1 #increment up again
				b _enemy_loop
	_enemy_loop:
		beq s1, MAX_ENEMIES, _bullet_loop #cycled through the enemies and didn't hit, go to next bullet
			la t0, enemies_array
			add t0, t0, s1
			lb t0, (t0)
			add s1, s1, 1 #increment before check so if the if fails then it can jump back to loop top
			bne t0, 1, _enemy_loop #if not 1, go back to enemy loop, else:
				sub s1, s1, 1 #sub back down for correct enemy num
				lw t1, enemy_x_coord
				lw t2, enemy_y_coord
				# s1 IS THE ENEMY NUMBER WE'RE ON
				_check_first_row:
					bgt s1, 4, _check_second_row
						mul a2, s1, 2 #x offset padding
						mul a2, a2, 5 #offset by enemy number
						add a2, t1, a2 #add offset to x coord
						move a3, t2 #y coord no offset for first row
						jal check_collision #WE HAVE BULLET X,Y and ENEMY X,Y NOW CHECK FOR A COLLISION IN A 5x5!!!
						b _handle_collision
				_check_second_row:
					bgt s1, 9, _check_third_row
						move t0, s1
						sub t0, t0, 5 #get correct offset for row 2
						mul a2, t0, 2 #x offset padding
						mul a2, a2, 5 #offset by enemy number
						add a2, t1, a2 #add offset to x coord
						add a3, t2, 7 #add row 2 offset to y coord
						jal check_collision #WE HAVE BULLET X,Y and ENEMY X,Y NOW CHECK FOR A COLLISION IN A 5x5!!!
						b _handle_collision
				_check_third_row:
					bgt s1, 14, _check_fourth_row
						move t0, s1
						sub t0, t0, 10 #get correct offset for row 3
						mul a2, t0, 2 #x offset padding
						mul a2, a2, 5 #offset by enemy number
						add a2, t1, a2 #add offset to x coord
						add a3, t2, 14 #add row 3 offset to y coord
						jal check_collision #WE HAVE BULLET X,Y and ENEMY X,Y NOW CHECK FOR A COLLISION IN A 5x5!!!
						b _handle_collision
				_check_fourth_row:
						move t0, s1
						sub t0, t0, 15 #get correct offset for row 3
						mul a2, t0, 2 #x offset padding
						mul a2, a2, 5 #offset by enemy number
						add a2, t1, a2 #add offset to x coord
						add a3, t2, 21 #add row 3 offset to y coord
						jal check_collision #WE HAVE BULLET X,Y and ENEMY X,Y NOW CHECK FOR A COLLISION IN A 5x5!!!
						b _handle_collision
			
	_handle_collision:
		bne v0, 1, __no_collision #if not 1, there's no collision, else:
		#s0 is the bullet num
		#s1 is the enemy num
		move a0, s0
		jal dealloc_bullet
		#decrease enemy amount
		lw t0, enemies_remaining
		sub t0, t0, 1
		sw t0, enemies_remaining
		#now dealloc that enemy num
		la t0, enemies_array
		add t0, t0, s1
		lb t1, (t0)
		sub t1, t1, 1 #change it to 0
		sb t1, (t0)
		add s1, s1, 1 #increment and leave
		b _enemy_loop
		
		__no_collision:
			add s1, s1, 1 #increment and leave
			b _enemy_loop
			
	_skip_to_collision_end:
		leave s0 s1
		
			
check_collision:
	enter
	#bullet x,y = a0, a1
	#enemy x,y = a2, a3
	add t0, a2, 4 #enemy x max
	add t1, a3, 4 #enemy y max
	sub t2, t0, a0
	sub t3, t1, a1
	blt t2, 0, _skip_to_check_col_end #fail any and leave
	bgt t2, 4, _skip_to_check_col_end
	blt t3, 0, _skip_to_check_col_end
	bgt t3, 4, _skip_to_check_col_end
	#make it past all these and we're good
	li v0, 1 #returning 1 = collision detected!!!
	leave
	_skip_to_check_col_end:
		li v0, 0 #returning 0 = no collision
		leave
