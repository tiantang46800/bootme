#include <config.h>
#include <version.h>

.globl _start
_start: b	reset
.global _end_vect
_end_vect:

.balignl 16,0xdeadbeef
/*************************************************************************
 *
 * Startup Code (reset vector)
 *
 * do important init only if we don't start from memory!
 * setup Memory and board specific bits prior to relocation.
 * relocate armboot to ram
 * setup stack
 *
 *************************************************************************/
.global hello
hello:
.word 0x123

_TEXT_BASE:
.word	TEXT_BASE

.globl _armboot_start
_armboot_start:
.word _start

/*
 * These are defined in the board-specific linker script.
 */
.globl _bss_start
_bss_start:
.word __bss_start

.globl _bss_end
_bss_end:
.word _end

#ifdef CONFIG_USE_IRQ
/* IRQ stack memory (calculated at run-time) */
.globl IRQ_STACK_START
IRQ_STACK_START:
.word	0x0badc0de

/* IRQ stack memory (calculated at run-time) */
.globl FIQ_STACK_START
FIQ_STACK_START:
.word 0x0badc0de
#endif

/*
 * the actual reset code
 */

reset:
/*
 * set the cpu to SVC32 mode
 */
mrs	r0, cpsr
bic	r0, r0, #0x1f
orr	r0, r0, #0xd3
msr	cpsr,r0

bl	cpu_init_crit

ldr r0, =0xe03001c0
ldr r1, =0x1111
str r1, [r0]
ldr r0, =0xe03001c4
ldr r1, =0x3
str r1, [r0]

/* added by zeng */
ldr r0, =_TEXT_BASE
adr r1, _TEXT_BASE
cmp r0, r1
beq stack_setup

ldr r0, =0xe03001c4
ldr r1, =0xf
str r1, [r0]

	ldr sp, =(0x22000000)
	bl copy_uboot_to_ram
	b stack_setup
	/* Set up the stack */
	stack_setup:

	ldr r0, =0xe03001c4
	ldr r1, =0x0
	str r1, [r0]

	ldr	r0, _TEXT_BASE		@ upper 128 KiB: relocated uboot
	sub	r0, r0, #CONFIG_SYS_MALLOC_LEN @ malloc area
	sub	r0, r0, #CONFIG_SYS_GBL_DATA_SIZE @ bdinfo
	sub	sp, r0, #12		@ leave 3 words for abort-stack
	and	sp, sp, #~7		@ 8 byte alinged for (ldr/str)d

	/* Clear BSS (if any). Is below tx (watch load addr - need space) */
	clear_bss:
	ldr	r0, _bss_start		@ find start of bss segment
	ldr	r1, _bss_end		@ stop here
	mov	r2, #0x00000000		@ clear value
	clbss_l:
	str	r2, [r0]		@ clear BSS location
	cmp	r0, r1			@ are we at the end yet
	add	r0, r0, #4		@ increment clear index pointer
	bne	clbss_l			@ keep clearing till at end

	ldr r0, =0xe03001c4
	ldr r1, =0x1
	str r1, [r0]

	ldr	pc, _start_armboot	@ jump to C code

	_start_armboot: .word start_armboot


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

