@filename: mem.S

.text
.align 2
.global init_mem_man
.global get_mem

@ page size appears to be 0x1000 (4096)

.macro	brk addr
	.ifnb \addr
		mov	r0, \addr
	.endif
	mov	r7, #45
	svc	0x00000000
.endm


@ long sys_mmap2(unsigned long addr, unsigned long len, unsigned long prot, unsigned long flags, unsigned long fd, unsigned long pgoff)
@      r7=192             r0                  r1                 r2                  r3                   r4                r5

mmap:
	push	{r4, r5}
	mov	r1, r0
	mov	r0, #0
	mov	r2, #3			@ 1=read, 2=write, 4=exec, 0=none
	mov	r3, #0x22		@ 0x20=ANONYMOUS 0x02=PRIVATE
	mov	r4, #0
	mov	r5, #0
	mov	r7, #192
	svc	0x00000000
	pop	{r4, r5}
	bx	lr


	
init_mem_man:
	brk	#0
	ldr	r1, =heap_start
	str	r0, [r1]
	mov	r0, #0
	ldr	r1, =heap_size
	str	r0, [r1]
	bx	lr
	
get_mem:
	push	{r4, r5, r6, r7, lr}
				@	start with r0 = requested
				@	requested = requested & 0xFFFC + 4
	ldr	r1, =0xFFFC
	and	r0, r0, r1
				@ only add 4 if r0 isn't a multiple of 4
	add	r0, r0, #4

	ldr	r1, =heap_start
	ldr	r1, [r1]

	ldr	r2, =heap_size
	ldr	r2, [r2]
	
				@	i = 0
	mov	r3, #0
get_mem_loop1:
				@	while i < heap_size {
	cmp	r3, r2
	bge	get_mem_loop2
				@		size = [heap_start + i]
	ldr	r4, [r1, r3]
				@		if (size & 1 == 1) {
	and	r5, r4, #1
	cmp	r5, #1
	bne	get_mem_loop3
				@			// allocate memory
				@			[heap_start + i] = requested
	str	r0, [r1, r3]
				@			size = size - 1
	sub	r4, r4, #1
				@			remaining = size - requested
	sub	r5, r4, r0
				@			if (remaining > 0) {
	cmp	r5, #0
	ble	get_mem_loop4
				@				[heap_start + i + requested + 4] = remaining + 1 - 4
	sub	r5, r5, #3
	add	r6, r1, r3
	add	r6, r6, #4
	str	r5, [r6, r0]
				@			}
get_mem_loop4:
				@			return heap_start + i + 4
	add	r0, r1, r3
	add	r0, r0, #4
	pop	{r4, r5, r6, r7, lr}
	bx	lr
				@		}
get_mem_loop3:
				@		i += size + 4
	add	r3, r3, r4
	add	r3, r3, #4
	b	get_mem_loop1
				@	}
get_mem_loop2:
				@	heap_size += 4096
	add	r2, r2, #4096
	ldr	r5, =heap_size
	str	r2, [r5]
				@	brk(heap_start + heap_size)
	add	r4, r2, r1
	push	{r0-r7}
	brk	r4
	pop	{r0-r7}
				@	[heap_start + i] = 4096 + 1 - 4
	ldr	r4, =4093
	str	r4, [r1, r3]
				@	goto get_mem_loop1
	b	get_mem_loop1

.section .data
.align 2

heap_start:
	.word	0
heap_size:
	.word	0


