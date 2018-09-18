# jja54
# Jack Anderson

.include "convenience.asm"
.include "display.asm"

.eqv GAME_TICK_MS      16
.eqv MAX_BULLETS	10
.eqv MAX_ENEMIES	20
.eqv GAME_OVER_CONST	99

.data
# don't get rid of these, they're used by wait_for_next_frame.
last_frame_time:  .word 0
frame_counter:    .word 0

#Player Constants
player_image: .byte
 0   0   7   0   0
 7   0   2   0   7
 7   0   7   0   7
 7   2   7   2   7
 0   7   0   7   0
player_x_coord: .word 30
player_y_coord: .word 48 
player_lives: .word 3
player_shots: .word 50
bullet_x: .byte 0:MAX_BULLETS
bullet_y: .byte 0:MAX_BULLETS
bullet_active: .byte 0:MAX_BULLETS
bullet_player_const: .byte 1
bullet_enemy_const: .byte 2
bullet_last_frame: .word 0
player_invincible: .word 0
player_invincible_counter: .word 0
player_flash_const: .word 0

#Enemy Constants
enemy_image: .byte
 0   0   7   0   0
 0   7   5   7   0
 7   7   0   7   7
 7   0   0   0   7
 7   0   0   0   7
enemies_remaining: .word 20
enemies_array: .byte 1:MAX_ENEMIES #all active to start
enemy_x_coord: .word 2
enemy_y_coord: .word 2
enemy_movement_direction: .word 0 #0 for right, 1 for left!
enemies_can_move: .byte 0 #quick var to allow movement after player starts moving!
enemy_speed: .word 20
enemy_fire_speed: .word 60
enemy_bullet_last_frame: .word 0


game_over_text: .asciiz "GAME OVER"
game_over_text_lives: .asciiz "NO LIVES"
game_over_text_shots: .asciiz "NO SHOTS"
game_over_text_enemies: .asciiz "YOU WIN!!"
game_over_flash_const: .word 0
game_over_counter: .word 0

.text

# --------------------------------------------------------------------------------------------------

.globl main
main:
	# set up anything you need to here,
	# and wait for the user to press a key to start.

_main_loop:
	# check for input,
	jal check_player_input
	jal check_enemy_fire
	beq v0, GAME_OVER_CONST, _game_over
	# update everything,
	jal update_enemies
	jal update_player_bullets
	jal update_enemy_bullets
	jal update_invincible_couter
	beq v0, GAME_OVER_CONST, _game_over
	# then draw everything.
	jal draw_player
	jal draw_enemies
	jal draw_player_bullets
	jal draw_enemy_bullets
	jal draw_shots
	jal draw_lives

	jal	display_update_and_clear
	jal	wait_for_next_frame
	b	_main_loop

_game_over:
	jal game_over
	jal display_update_and_clear
	exit

# --------------------------------------------------------------------------------------------------
# call once per main loop to keep the game running at 60FPS.
# if your code is too slow (longer than 16ms per frame), the framerate will drop.
# otherwise, this will account for different lengths of processing per frame.

wait_for_next_frame:
enter	s0
	lw	s0, last_frame_time
_wait_next_frame_loop:
	# while (sys_time() - last_frame_time) < GAME_TICK_MS {}
	li	v0, 30
	syscall # why does this return a value in a0 instead of v0????????????
	sub	t1, a0, s0
	bltu	t1, GAME_TICK_MS, _wait_next_frame_loop

	# save the time
	sw	a0, last_frame_time

	# frame_counter++
	lw	t0, frame_counter
	inc	t0
	sw	t0, frame_counter
leave	s0

# --------------------------------------------------------------------------------------------------
#PLAYER INPUT STUFF
check_player_input:
	enter s0
	jal input_get_keys
	
	lbu t0, enemies_can_move
	beq t0, 1, checkLEFT #skip this nonsense because enemies can move now
	beq v0, 0, checkLEFT #make sure that a key is being pressed
	add t0, t0, 1
	sb t0, enemies_can_move
	
	checkLEFT:
		#v0 = keys
		move s0, v0
		and t0, s0, KEY_L
		bne t0, 0, checkRIGHT #if (keys & KEY_L) != 0, check right
			lw a0, player_x_coord
			jal move_player_right
			#FOR SOME REASON THESE WERE INVERTED if used move_player_left
			#SWITCHED EACH ONE AND NOW CONTROLS ARE NOT INVERTED
	checkRIGHT:
		and t0, s0, KEY_R
		bne t0, 0, checkUP #pressing right
			lw a0, player_x_coord
			jal move_player_left

	checkUP:
		and t0, s0, KEY_U
		bne t0, 0, checkDOWN #pressing up
			lw a0, player_y_coord
			jal move_player_down
	checkDOWN:
		and t0, s0, KEY_D
		bne t0, 0, checkB #pressing down
			lw a0, player_y_coord
			jal move_player_up
	
	checkB:
		and t0, s0, KEY_B
		beq t0, 0, skip_to_end
		jal alloc_bullet
		#bullet to use is now in v0
		move a0, v0
		beq v0, MAX_BULLETS, skip_to_end #hit max, don't fire another bullet
		#check if frame will let you fire:
		lw t0, bullet_last_frame
		beq t0, 0, _skip_to_first_shot #if last frame was 0 you never fired
		lw t1, frame_counter
		sub t0, t1, t0 #sub bullet_last_frame from current frame
		blt t0, 30, skip_to_end #don't allow a shot if gap too small
		sw t1, bullet_last_frame #set current frame to bullet_last_frame
		jal fire_player_shot
		b skip_to_end
	_skip_to_first_shot:
		lw t0, frame_counter
		sw t0, bullet_last_frame
		jal fire_player_shot
	skip_to_end:
		leave s0
		
alloc_bullet:
	enter s0
	li s0, 0
	_alloc_bullet_loop:
		beq s0, MAX_BULLETS, _skip_to_alloc_bullet_end
			#lb t0, bullet_active(s0) :
			la t0, bullet_active
			add t0, t0, s0
			lb t0, (t0)
			add s0, s0, 1 #increment before check so if the if fails then it can jump back to loop top
			bne t0, 0, _alloc_bullet_loop #if not 0, go back to top, else:
			sub s0, s0, 1 #sub back down to keep right number
			move v0, s0 #return the address# of available bullet
			lb t1, bullet_player_const
			la t0, bullet_active
			add t0, t0, s0
			sb t1, (t0) #mark it as used
			leave s0
	_skip_to_alloc_bullet_end:
		li v0, MAX_BULLETS #if return this, then know max are being drawn, so draw no more
		leave s0
		
alloc_enemy_bullet:
	enter s0
	li s0, 0
	_alloc_enemy_bullet_loop:
		beq s0, MAX_BULLETS, _skip_to_alloc_enemy_bullet_end
			#lb t0, bullet_active(s0) :
			la t0, bullet_active
			add t0, t0, s0
			lb t0, (t0)
			add s0, s0, 1 #increment before check so if the if fails then it can jump back to loop top
			bne t0, 0, _alloc_enemy_bullet_loop #if not 0, go back to top, else:
			sub s0, s0, 1 #sub back down to keep right number
			move v0, s0 #return the address# of available bullet
			lb t1, bullet_enemy_const
			la t0, bullet_active
			add t0, t0, s0
			sb t1, (t0) #mark it as used
			leave s0
	_skip_to_alloc_enemy_bullet_end:
		li v0, MAX_BULLETS #if return this, then know max are being drawn, so draw no more
		leave s0
		
fire_player_shot:
	enter s0
	#s0 is bullet# to edit
	move s0, a0
	#get location of player so we can fire
	lw t0, player_x_coord
	lw t1, player_y_coord
	add t0, t0, 2 #move bullet to nose of ship
	sub t1, t1, 1 #put the bullet 1 pixel away from the ship vertically
	#create bullet's xy info:
	#sb t0, bullet_x(s0) :
	la t3, bullet_x
	add t3, t3, s0
	sb t0, (t3)
	#sb t1, bullet_y(s0):
	la t4, bullet_y
	add t4, t4, s0
	sb t1, (t4)
	#decrement number of shots/check if 0:
	lw t2, player_shots
	sub t2, t2, 1
	sw t2, player_shots
	beq t2, 0, _skip_game_over_shots
	leave s0
	
	_skip_game_over_shots:
	jal draw_shots
	li v0, GAME_OVER_CONST
	leave s0
	

move_player_left:
	enter
		beq a0, 2, skip_end_left #if x coord is 2, don't let move further left 
		sub a0, a0, 1
		sw a0, player_x_coord
	skip_end_left:
	leave
move_player_right:
	enter
		beq a0, 57, skip_end_right
		add a0, a0, 1
		sw a0, player_x_coord
	skip_end_right:
	leave
move_player_up:
	enter
		beq a0, 46, skip_end_up
		sub a0, a0, 1
		sw a0, player_y_coord
	skip_end_up:
	leave
move_player_down:
	enter
		beq a0, 52, skip_end_down
		add a0, a0, 1
		sw a0, player_y_coord
	skip_end_down:
	leave
	
	
check_enemy_fire:
	enter
	#make sure that player has moved first
	lbu t0, enemies_can_move
	bne t0, 1, _skip_end_enemy_fire
	
	lw t0, enemies_remaining
	_fire_speed_scale_5:
		bgt t0, 5, _fire_speed_scale_10
		li t1, 30
		sw t1, enemy_fire_speed
		b _skip_fire_speed_scaling
	_fire_speed_scale_10:
		bgt t0, 10, _fire_speed_scale_15
		li t1, 45
		sw t1, enemy_fire_speed
		b _skip_fire_speed_scaling
	_fire_speed_scale_15:
		bgt t0 15, _skip_fire_speed_scaling
		li t1, 50
		sw t1, enemy_fire_speed
		b _skip_fire_speed_scaling
	
	_skip_fire_speed_scaling:
	lw t0, enemy_bullet_last_frame
	beq t0, 0, _skip_to_enemy_first_shot #if last frame was 0 they never fired
	lw t1, frame_counter
	sub t0, t1, t0 #sub bullet_last_frame from current frame
	lw t4, enemy_fire_speed
	blt t0, t4, _skip_end_enemy_fire #don't allow a shot if gap too small
	jal alloc_enemy_bullet
	#bullet to use is now in v0, move to a0
	move a0, v0
	beq v0, MAX_BULLETS, _skip_end_enemy_fire #hit max, don't fire another bullet
	lw t1, frame_counter
	sw t1, enemy_bullet_last_frame #set last enemy frame to bullet_last_frame
	
	jal fire_enemy_shot
	b _skip_end_enemy_fire
	
	_skip_to_enemy_first_shot:
		jal alloc_enemy_bullet
		#bullet to use is now in v0, move to a0
		move a0, v0
		beq v0, MAX_BULLETS, _skip_end_enemy_fire #hit max, don't fire another bullet
		lw t0, frame_counter
		sw t0, enemy_bullet_last_frame
		jal fire_enemy_shot
		
	_skip_end_enemy_fire:
		leave
		
fire_enemy_shot:
	enter s0 s1
	move s0, a0 #a0 was bullet num to fire
	li s1, 0
	
	#GET ENEMY LOCATION TO FIRE with random num gen
	_rand_gen_enemy_num:
		li v0, sys_randRange #syscall num
		li a1, MAX_ENEMIES #upper bound
		syscall
		#now rand num is in a0
		move s1, a0
		#check to see if the enemy is alive:
		la t0, enemies_array #address calculation
		add t0, t0, s1
		lb t0, (t0)
		bne t0, 1, _rand_gen_enemy_num #check if enemy active, if not get a new rand num
				
	#calculate correct firing coords
	lw t1, enemy_x_coord #load the top-left coords
	lw t2, enemy_y_coord
	
	#A0 WILL BE X, A1 WILL BE Y
		_if_first_row:
			#if in first row:
			bgt s1, 4, _if_second_row
				mul a0, s1, 2 #x offset padding
				mul a0, a0, 5 #offset by enemy number
				add a0, t1, a0 #add offset to x coord
				move a1, t2
				#y coord no offset for first row
				b _fire_from_enemy
		_if_second_row:
			bgt s1, 9, _if_third_row
				sub t0, s1, 5 #get correct offset for row 2
				mul a0, t0, 2 #x offset padding
				mul a0, a0, 5 #offset by enemy number
				add a0, t1, a0 #add offset to x coord
				add a1, t2, 7 #add row 2 offset to y coord
				b _fire_from_enemy
		_if_third_row:
			bgt s1, 14, _if_fourth_row
				sub t0, s1, 10 #get correct offset for row 3
				mul a0, t0, 2 #x offset padding
				mul a0, a0, 5 #offset by enemy number
				add a0, t1, a0 #add offset to x coord
				add a1, t2, 14 #add row 3 offset to y coord
				b _fire_from_enemy
		_if_fourth_row:
				sub t0, s1, 15 #get correct offset for row 3
				mul a0, t0, 2 #x offset padding
				mul a0, a0, 5 #then offset by enemy number
				add a0, t1, a0 #add offset to x coord
				add a1, t2, 21 #add row 4 offset to y coord
	
	_fire_from_enemy:
		add a0, a0, 2 #move bullet to nose of ship
		add a1, a1, 4 #put the bullet 4 pixels away from the ship vertically
	
	#create bullet's xy info:
	#sb t0, bullet_x(s0) :
	la t3, bullet_x
	add t3, t3, s0
	sb a0, (t3)
	#sb t1, bullet_y(s0):
	la t4, bullet_y
	add t4, t4, s0
	sb a1, (t4)
	leave s0 s1
# --------------------------------------------------------------------------------------------------
#UPDATE STUFF	
update_player_bullets:
	enter s0 s1 s2
	li s0, 0 #loop counter
	_update_player_bullets_loop:
		beq s0, 9, _skip_to_update_player_bullets_end
		la t0, bullet_active #address calculation
		add t0, t0, s0
		lb t0, (t0)
		add s0, s0, 1 #increment before if
		bne t0, 1, _update_player_bullets_loop
			sub s0, s0, 1 #decrement for right address calc
			la t1, bullet_y
			add t1, t1, s0
			lb a1, (t1)
			sub a1, a1, 1
			
			move s1, a1 #store these vals before jump
			move s2, t1
			move a0, s0 #send the bullet into the collision check so no need for that loop inside it
			jal check_bullet_collision
			move a1, s1
			move t1, s2
			
			ble a1, 0, _skip_de_alloc #if it's <=0 then dealloc it and delete
				sb a1, (t1)
				add s0, s0, 1 #increment again
				b _update_player_bullets_loop
			_skip_de_alloc:
				move a0, s0
				jal dealloc_bullet
				add s0, s0, 1
				b _update_player_bullets_loop
	_skip_to_update_player_bullets_end:
		leave s0 s1 s2
	
update_enemy_bullets:
	#THIS COULD DEFINITELY BE DONE IN THE UPDATE_PLAYER_BULLETS, BUT FOR TIME'S SAKE IM JUST MAKING IT
	#SEPARATE INSTEAD OF MODIFIYING THAT FUNCTION NOW
	enter s0 s1 s2
	li s0, 0 #loop counter
	_update_enemy_bullets_loop:
		beq s0, 9, _skip_to_update_enemy_bullets_end
		la t0, bullet_active #address calculation
		add t0, t0, s0
		lb t0, (t0)
		add s0, s0, 1 #increment before if
		bne t0, 2, _update_enemy_bullets_loop
			sub s0, s0, 1 #decrement for right address calc
			la t1, bullet_y
			add t1, t1, s0
			lb a1, (t1)
			add a1, a1, 1 #move it down towards player
			
			move s1, a1 #store these vals before jump
			move s2, t1
			move a0, s0 #send the bullet into the collision check so no need for that loop inside it
			jal check_bullet_player_collision
			move a1, s1
			move t1, s2
			
			bgt a1, 63, _skip_enemy_de_alloc #if it's >63 then dealloc it and delete, else:
				sb a1, (t1)
				add s0, s0, 1 #increment again
				b _update_enemy_bullets_loop
			_skip_enemy_de_alloc:
				move a0, s0
				jal dealloc_bullet
				add s0, s0, 1 #increment again
				b _update_enemy_bullets_loop
			
	_skip_to_update_enemy_bullets_end:
		leave s0 s1 s2
		
dealloc_bullet:
	enter
	la t0, bullet_active
	add t0, t0, a0
	li t1, 0 #t1 for 0 
	sb t1, (t0) #open it up for new bullet
	li t1, 0
	#now set x, y to 0, 0
	la t0, bullet_x
	add t0, t0, a0
	sb t1, (t0)
	la t0, bullet_y
	add t0, t0, a0
	sb t1, (t0)
	leave
	
update_enemies:
	enter
	#make sure that player has moved first
	lbu t0, enemies_can_move
	bne t0, 1, _skip_to_end_update_enemies
	
	#check enemies remaining for difficulty scaling
	lw t0, enemies_remaining
	_speed_scale_5:
		bgt t0, 5, _speed_scale_10
		li t1, 5
		sw t1, enemy_speed
		b _skip_speed_scaling
	_speed_scale_10:
		bgt t0, 10, _speed_scale_15
		li t1, 10
		sw t1, enemy_speed
		b _skip_speed_scaling
	_speed_scale_15:
		bgt t0 15, _skip_speed_scaling
		li t1, 15
		sw t1, enemy_speed
		b _skip_speed_scaling
	
	_skip_speed_scaling:
	lw t0, frame_counter
	lw t1, enemy_speed #20 the magic number?
	div t0, t1
	mfhi t0 #gets the remainder, as if just did a mod
	bne t0, 0, _skip_to_end_update_enemies
		lw t0, enemy_movement_direction
		lw t1, enemy_x_coord
		lw t2, enemy_y_coord
		beq t0, 1, _move_enemies_left
		_move_enemies_right:	
			beq t1, 17, _switch_enemies_left
				add t1, t1, 1
				sw t1, enemy_x_coord
				b _skip_to_end_update_enemies
		_move_enemies_left:
			beq t1, 2, _switch_enemies_right
				sub t1, t1, 1
				sw t1, enemy_x_coord
				b _skip_to_end_update_enemies
		_switch_enemies_left:
			beq t2, 15, _skip_down_move_left
				add t2, t2, 1
				sw t2, enemy_y_coord
			_skip_down_move_left:
				add t0, t0, 1
				sw t0, enemy_movement_direction
				b _skip_to_end_update_enemies
		_switch_enemies_right:
			beq t2, 15, _skip_down_move_right
				add t2, t2, 1
				sw t2, enemy_y_coord
			_skip_down_move_right:
				sub t0, t0, 1
				sw t0, enemy_movement_direction
				b _skip_to_end_update_enemies
	_skip_to_end_update_enemies:		
		leave
		
check_bullet_player_collision:
	enter s0
	
	lw t0, player_invincible
	beq t0, 1, __no_player_collision #if invincible, don't try to check for collision
	# a0 is the bullet!
	move s0, a0
	la t0, bullet_x
	add t0, t0, s0
	lb a0, (t0) #bullet_x num in a0
	la t1, bullet_y
	add t1, t1, s0
	lb a1, (t1) #bullet_y num in a1
	lw a2, player_x_coord
	lw a3, player_y_coord
	jal check_collision #we have BULLET X,Y and PLAYER X,Y now check for a collision in a 5x5!!
	#v0 returns whether there is a collision or not
	bne v0, 1, __no_player_collision #if not 1, there's no collision, else:
		#player was hit by a bullet!!
		#s0 is the bullet num
		move a0, s0
		jal dealloc_bullet
		#decrease live amount
		lw t0, player_lives
		sub t0, t0, 1
		sw t0, player_lives
		beq t0, 0, __no_lives_game_over
		#let's make them invincible
		lw t0, player_invincible
		add t0, t0, 1
		sw t0, player_invincible
		
		__no_player_collision:
			leave s0
			
		__no_lives_game_over:
			#do same shit as before but gtfo
			li v0, GAME_OVER_CONST
			leave s0

check_bullet_collision:
	enter s0 s1 s2
	# a0 is the bullet!
	move s0, a0
	li s1, 0
	li s2, 0
	
	la t0, bullet_x
	add t0, t0, s0
	lb a0, (t0) #bullet_x num in a0
	la t1, bullet_y
	add t1, t1, s0
	lb a1, (t1) #bullet_y num in a1
	
	_enemy_loop:
		beq s1, MAX_ENEMIES, _skip_to_collision_end #cycled through the enemies and didn't hit, go to next bullet
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
		beq t0, 0, __no_enemies_game_over
		#now dealloc that enemy num
		la t0, enemies_array
		add t0, t0, s1
		li t1, 0 #change it to 0
		sb t1, (t0)
		add s1, s1, 1 #increment and leave
		b _enemy_loop
		
		__no_collision:
			add s1, s1, 1 #increment and leave
			b _enemy_loop
		
		__no_enemies_game_over:
			#do same shit as before but gtfo
			#now dealloc that enemy num
			la t0, enemies_array
			add t0, t0, s1
			li t1, 0 #change it to 0
			sb t1, (t0)
			add s1, s1, 1 #increment and leave
			li v0, GAME_OVER_CONST
			b _game_over
		
			
	_skip_to_collision_end:
		leave s0 s1 s2
		
			
check_collision:
	enter
	#bullet x,y = a0, a1
	#enemy x,y = a2, a3
	add t0, a2, 4 #rectangle x max
	add t1, a3, 4 #rectangle y max
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
		
update_invincible_couter:
	enter s0
	lw t0, player_invincible
	beq t0, 0, _skip_invincible
	lw t0, player_invincible_counter
	add t0, t0, 1
	#check for flashing
	li t2, 5
	divu t0, t2
	mfhi t1
	bne t1, 0, _skip_flashing
		lw t1, player_flash_const
		beq t1, 1, _turn_off_flash
		_turn_on_flash:
			add t1, t1, 1
			sw t1, player_flash_const
			b _skip_flashing
		_turn_off_flash:
			sub t1, t1, 1
			sw t1, player_flash_const
	_skip_flashing:
		beq t0, 120, _reset_counter
		#else:
		sw t0, player_invincible_counter
		leave s0
	
	_reset_counter:
	li t0, 0
	sw t0, player_invincible_counter
	lw t0, player_invincible
	sub t0, t0, 1
	sw t0, player_invincible
	
	_skip_invincible:
		leave s0
# --------------------------------------------------------------------------------------------------
# DRAWS	
draw_player:
	enter
	lw t1, player_flash_const
	beq t1, 1, _skip_drawing_player
	
	lw a0, player_x_coord
	lw a1, player_y_coord
	la a2, player_image
	jal display_blit_5x5
	_skip_drawing_player:
		leave
	
draw_shots:
	enter
	li a0, 2
	li a1, 58
	lw a2, player_shots
	jal display_draw_int
	leave
	
draw_lives:
	enter
	lw t0, player_lives
	beq t0, 3, _draw_lives_3
	beq t0, 2, _draw_lives_2
	#this is rather redundant right now, might fix it up later
	#else just draw one
		li a0, 58
		li a1, 58
		la a2, player_image
		jal display_blit_5x5
		b _draw_lives_exit
	_draw_lives_2:
		li a0, 58
		li a1, 58
		la a2, player_image
		jal display_blit_5x5
		#can't be sure the arguement registers remain the same
		li a0, 52
		li a1, 58
		la a2, player_image
		jal display_blit_5x5
		b _draw_lives_exit
	_draw_lives_3:
		li a0, 58
		li a1, 58
		la a2, player_image
		jal display_blit_5x5
		li a0, 52
		li a1, 58
		la a2, player_image
		jal display_blit_5x5
		li a0, 46
		li a1, 58
		la a2, player_image
		jal display_blit_5x5
		b _draw_lives_exit
	_draw_lives_exit:
		leave

draw_player_bullets:
	enter s0
	li s0, 0 #loop counter
	_draw_player_bullets_loop:
		beq s0, 9, _skip_to_draw_player_bullets_end
		la t0, bullet_active #address calculation
		add t0, t0, s0
		lb t0, (t0)
		add s0, s0, 1 #increment before if
		bne t0, 1, _draw_player_bullets_loop #if the bullet is active
			sub s0, s0, 1 #decrement again to get right bullet #
			la t1, bullet_x
			add t1, t1, s0
			lb a0, (t1)
			
			la t2, bullet_y
			add t2, t2, s0
			lb a1, (t2)

			li a2, COLOR_RED
			jal display_set_pixel
			add s0, s0, 1 #increment again before restarting loop
			b _draw_player_bullets_loop
	_skip_to_draw_player_bullets_end:
	leave s0
	
draw_enemy_bullets:
	enter s0
	li s0, 0 #loop counter
	_draw_enemy_bullets_loop:
		beq s0, 9, _skip_to_draw_enemy_bullets_end
		la t0, bullet_active #address calculation
		add t0, t0, s0
		lb t0, (t0)
		add s0, s0, 1 #increment before if
		bne t0, 2, _draw_enemy_bullets_loop #if the bullet is active
			sub s0, s0, 1 #decrement again to get right bullet #
			la t1, bullet_x
			add t1, t1, s0
			lb a0, (t1)
			la t2, bullet_y
			add t2, t2, s0
			lb a1, (t2)
			li a2, COLOR_GREEN
			jal display_set_pixel
			add s0, s0, 1 #increment again before restarting loop
			b _draw_enemy_bullets_loop
	_skip_to_draw_enemy_bullets_end:
	leave s0
	
draw_enemies:
	enter s0 s1
	li s0, 0
	_draw_enemies_loop:
		beq s0, MAX_ENEMIES, _skip_to_draw_enemies_end
		lw t1, enemy_x_coord #load the top-left coords
		lw t2, enemy_y_coord
		la t0, enemies_array #address calculation
		add t0, t0, s0
		lb t0, (t0)
		add s0, s0, 1
		bne t0, 1, _draw_enemies_loop #if enemy active
			sub s0, s0, 1 #sub for correct
			_draw_first_row:
				#if in first row:
				bgt s0, 4, _draw_second_row
					mul a0, s0, 2 #x offset padding
					mul a0, a0, 5 #offset by enemy number
					add a0, t1, a0 #add offset to x coord
					move a1, t2 #y coord no offset for first row
					la a2, enemy_image
					jal display_blit_5x5
					add s0, s0, 1 #inc again
					b _draw_enemies_loop
			_draw_second_row:
				bgt s0, 9, _draw_third_row
					move t0, s0
					sub t0, t0, 5 #get correct offset for row 2
					mul a0, t0, 2 #x offset padding
					mul a0, a0, 5 #offset by enemy number
					add a0, t1, a0 #add offset to x coord
					add a1, t2, 7 #add row 2 offset to y coord
					la a2, enemy_image
					jal display_blit_5x5
					add s0, s0, 1 #inc again
					b _draw_enemies_loop
			_draw_third_row:
				bgt s0, 14, _draw_fourth_row
					move t0, s0
					sub t0, t0, 10 #get correct offset for row 3
					mul a0, t0, 2 #x offset padding
					mul a0, a0, 5 #offset by enemy number
					add a0, t1, a0 #add offset to x coord
					add a1, t2, 14 #add row 3 offset to y coord
					la a2, enemy_image
					jal display_blit_5x5
					add s0, s0, 1 #inc again
					b _draw_enemies_loop
			_draw_fourth_row:
				bgt s0, 19, _skip_to_draw_enemies_end
					move t0, s0
					sub t0, t0, 15 #get correct offset for row 3
					mul a0, t0, 2 #x offset padding
					mul a0, a0, 5 #then offset by enemy number
					add a0, t1, a0 #add offset to x coord
					add a1, t2, 21 #add row 4 offset to y coord
					la a2, enemy_image
					jal display_blit_5x5
					add s0, s0, 1 #inc again
					bne s0, 20, _draw_enemies_loop #checking if exiting third row
					#good to drop off to end
				
	_skip_to_draw_enemies_end:
	leave s0 s1
#------------------------------------------------------------------------------------------------------

game_over:
	enter
	#let's check why the game is ending
	_GO_check_lives:
		lw t0, player_lives
		bne t0, 0, _GO_check_shots
		
		li a0, 5
		li a1, 27
		la a2, game_over_text
		jal display_draw_text
		li a0, 8
		li a1, 36
		la a2, game_over_text_lives
		jal display_draw_text
		b _leave_GO
	_GO_check_shots:
		lw t0, player_shots
		bne t0, 0, _GO_check_enemies
		
		li a0, 5
		li a1, 27
		la a2, game_over_text
		jal display_draw_text
		li a0, 8
		li a1, 36
		la a2, game_over_text_shots
		jal display_draw_text
		b _leave_GO
	_GO_check_enemies:
		lw t0, enemies_remaining
		bne t0, 0, _generic_GO
		
		li a0, 5
		li a1, 27
		la a2, game_over_text
		jal display_draw_text
		li a0, 5
		li a1, 36
		la a2, game_over_text_enemies
		jal display_draw_text
		b _leave_GO
	
	_generic_GO:
		li a0, 5
		li a1, 32
		la a2, game_over_text
		jal display_draw_text
	_leave_GO:
		leave
