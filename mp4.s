.data
# flags for information about blocks
# 0	indicates unlocked state, 1 indicates locked state
block_status: .byte	0, 0, 0, 0, 0, 0, 0, 0, 0, 0
current_target: .byte 0
exception_string: .asciiz "Exception\n"


.text
main:
			  sub	$sp, $sp, 8
			  sw	$ra, 0($sp)
			  li	$t4, 0x1001		# bonk interrupt and global interrupt
			  mtc0	$t4, $12		# enable interrupt mask
live:
			  jal	find_closest_block
			  sub	$t0, $v0, 300
			  bgtz	$t0, stop		# closest_x > 300 (invalid case, triggered by no closest blocks)
			  move	$a0, $v0
			  move	$a1, $v1
			  jal	move_block_to_goal
			  j		live
stop:
			  sw	$0, 0xffff0010($0) # set velocity zero
			  j		live
main_return:
			  li	$v0, 0
			  lw	$ra, 0($sp)
			  add	$sp, $sp, 8
			  jr	$ra

find_closest_block:
			  sub	$sp, $sp, 40
			  sw	$s7, 32($sp)
			  sw	$s6, 28($sp)
			  sw	$s5, 24($sp)
			  sw	$s4, 20($sp)
			  sw	$s3, 16($sp)
			  sw	$s2, 12($sp)
			  sw	$s1, 8($sp)
			  sw	$s0, 4($sp)
			  sw	$ra, 0($sp)
			  li	$s0, 0			# uint i = 0
			  li	$s1, 700		# uint target_x = 700 chosen to always be further away than any block
			  li	$s2, 700		# uint target_y = 700
			  li	$s7, 980000		# distance(0, 0, 700, 700)
			  jal	find_bot_coordinates
			  move	$s3, $v0		# bot_x
			  move	$s4, $v1		# bot_y
find_closest_block_loop:
			  sub	$t0, $s0, 11
			  beqz	$t0, find_closest_block_return # i == 11
			  move	$a0, $s0
			  jal	find_box_coordinates
			  move	$s5, $v0		# box_x
			  move	$s6, $v1		# box_y
			  move	$a0, $s5
			  jal	is_in_goal
			  bnez	$v0, find_closest_block_loop_end # is_in_goal(i)
			  move	$a0, $s0
			  jal	is_locked
			  bnez	$v0, find_closest_block_loop_end # is_locked(i)
			  move	$a0, $s5		# box_x
			  move	$a1, $s6		# box_y
			  move	$a2, $s3		# bot_x
			  move	$a3, $s4		# bot_y
			  jal	distance
			  sub	$t0, $v0, $s7
			  bgez	$t0, find_closest_block_loop_end # min_dist <= distance(bot_x, bot_y, box_x, box_y)
			  move	$s7, $v0		# save the new min_dist
			  move	$s1, $s5		# save the new target_x
			  move	$s2, $s6		# save the new target_y
			  sw	$s0, current_target($0)
find_closest_block_loop_end:
			  add	$s0, $s0, 1
			  j		find_closest_block_loop
find_closest_block_return:
			  move	$v0, $s1
			  move	$v1, $s2
			  lw	$s7, 32($sp)
			  lw	$s6, 28($sp)
			  lw	$s5, 24($sp)
			  lw	$s4, 20($sp)
			  lw	$s3, 16($sp)
			  lw	$s2, 12($sp)
			  lw	$s1, 8($sp)
			  lw	$s0, 4($sp)
			  lw	$ra, 0($sp)
			  jr	$ra

is_locked:
			  lw	$v0, block_status($a0)
			  jr	$ra

is_in_goal:
			  li	$v0, 0			# initialize to false
			  sub	$a0, $a0, 145
			  bgtz	$a0, is_in_goal_false # x_coord > 145
			  li	$v0, 1			# set to true
is_in_goal_false:
			  jr	$ra

# void move_block_to_goal(box_x, box_y)
move_block_to_goal:
			  sub	$sp, $sp, 16
			  sw	$a1, 8($sp)
			  sw	$a0, 4($sp)
			  sw	$ra, 0($sp)
			  jal	find_bot_coordinates
			  lw	$a1, 8($sp)
			  lw	$a0, 4($sp)
			  sub	$t0, $v0, $a0	# x_diff
			  sub	$t1, $v1, $a1	# y_diff
			  bltz	$t0, move_block_to_goal_right
			  beqz	$t1, move_block_to_goal_left
			  bltz	$t1, move_block_to_goal_down
			  bgtz	$t1, move_block_to_goal_up
			  j		move_block_to_goal_left
move_block_to_goal_right:
			  add	$t2, $t1, 15
			  bltz	$t2, move_block_to_goal_right_clear
			  sub	$t2, $t1, 15
			  bgtz	$t2, move_block_to_goal_right_clear
# we are too close to the block in y, avoid the block
			  sub	$t2, $a1, 275
			  bgtz	$t2, move_block_to_goal_down_move # the block is near the top
			  j		move_block_to_goal_up_move
move_block_to_goal_right_clear:
			  li	$t4, 0
			  j		move_block_to_goal_return
move_block_to_goal_down:
			  sub	$t0, $t0, 15
			  bltz	$t0, move_block_to_goal_right # x_diff < 15 && y_diff < 0
move_block_to_goal_down_move:
			  li	$t4, 90
			  j		move_block_to_goal_return
move_block_to_goal_up:
			  sub	$t0, $t0, 15
			  bltz	$t0, move_block_to_goal_right # x_diff < 15 && y_diff > 0
move_block_to_goal_up_move:
			  li	$t4, 270
			  j		move_block_to_goal_return
move_block_to_goal_left:
			  li	$t4, 180
			  j		move_block_to_goal_return
move_block_to_goal_return:
			  sw	$t4, 0xffff0014($0) # set angle
			  li	$t4, 1
			  sw	$t4, 0xffff0018($0) # set angle as absolute
			  li	$t4, 10
			  sw	$t4, 0xffff0010($0) # set the velocity
			  lw	$ra, 0($sp)
			  add	$sp, $sp, 16
			  jr	$ra

find_bot_coordinates:
			  lw	$v0, 0xffff0020($0)
			  lw	$v1, 0xffff0024($0)
			  jr	$ra

find_box_coordinates:
			  sw	$a0, 0xffff0070($0)
			  lw	$v0, 0xffff0070($0)
			  lw	$v1, 0xffff0074($0)
			  jr	$ra

distance:
			  sub	$t0, $a0, $a2	# x_diff
			  sub	$t1, $a1, $a3	# y_diff
			  mul	$t0, $t0, $t0	# x_diff ^ 2
			  mul	$t1, $t1, $t1	# y_diff ^ 2
			  add	$v0, $t0, $t1
			  jr	$ra

.ktext 0x80000080
interrupt_handler:
			  .set	noat
			  move	$k1, $at		# save $at
			  .set	at
			  mfc0	$k0, $13		# cause register
			  and	$k0, $k0, 0x3c	# ExcCode field
			  bnez	$k0, non_interrupt
interrupt_dispatch:
			  mfc0	$k0, $13		# cause register
			  beqz	$k0, interrupt_done
			  and	$k0, $k0, 0x1000 # bonk interrupt
			  bnez	$k0, bonk_interrupt
			  # further interrupt handlers here
			  b		interrput_done
bonk_interrupt:
			  lw	$k0, current_target($0)
			  sw	$k0, 0xffff0070($0)
			  lw	$k2, 0xffff0070($0) # target box x coordinate
			  lw    $k0, 0xffff0020($0) # bot x coordinate
			  sub	$k2, $k0, $k2
			  beqz	$k2, bonk_interrupt_mark_target	# assumes we're hitting the target
			  # epic fail, we're hitting a block that isn't the target
			  b		bonk_interrupt_done
bonk_interrupt_mark_target:
			  lw	$k0, current_target($0)
			  li	$k2, 1
			  sw	$k2, block_status($k0) # mark target box as locked
			  b		bonk_interrupt_done
bonk_interrupt_done:
			  sw	$0, 0xffff0060($0) # acknowledge bonk interrupt
			  b		interrupt_dispatch # check for further interrupts
interrupt_done:
			  mfc0	$k0, $14
			  .set	noat
			  move	$at, $k1
			  .set	at
			  rfe
			  jr	$k0
non_interrupt:
			  li	$v0, 4
			  lw	$a0, exception_string
			  syscall
			  b		interrupt_done
