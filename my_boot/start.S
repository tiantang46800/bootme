_start: 
		b reset
		nop
		nop
		nop
		nop
		nop
		nop
		nop
reset:
	mrs r0,cpsr
	bic  r0,#0x1f
	orr  r0,#0xd3
	@orr  r0,0x13
	msr  cpsr,r0

	@close watch dog
	ldr r0,=0xea200000
	ldr r1,=0x0
	str r1,[r0]
	@led out_put
	ldr r0,=0xe03001c0
	ldr r1,=0x1111
	str r1,[r0]
	
	@led light all 
	ldr r0,=0xe03001c4
	ldr r1,=0xff
	str r1,[r0]

	@init pll
	b sys_clock_init
	/*************************************************************************
	 *
	 * CPU_init_critical registers
	 *
	 * setup important registers
	 * setup memory timing
	 *
	 *************************************************************************/
cpu_init_crit:
	/*
	 * Invalidate L1 I/D
	 */
	mov	r0, #0			@ set up for MCR
	mcr	p15, 0, r0, c8, c7, 0	@ invalidate TLBs
	mcr	p15, 0, r0, c7, c5, 0	@ invalidate icache

	/*
	 * disable MMU stuff and caches
	 */
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #0x00002000	@ clear bits 13 (--V-)
	bic	r0, r0, #0x00000007	@ clear bits 2:0 (-CAM)
	orr	r0, r0, #0x00000002	@ set bit 1 (--A-) Align
	orr	r0, r0, #0x00000800	@ set bit 12 (Z---) BTB
	mcr	p15, 0, r0, c1, c0, 0

	/*
	 * Jump to board specific initialization...
	 * The Mask ROM will have already initialized
	 * basic memory. Go here to bump up clock rate and handle
	 * wake up conditions.
	 */
	mov	ip, lr			@ persevere link reg across call
	bl	lowlevel_init		@ go setup pll,mux,memory
	mov	lr, ip			@ restore link
	mov	pc, lr			@ back to my caller


loop:
	b loop





