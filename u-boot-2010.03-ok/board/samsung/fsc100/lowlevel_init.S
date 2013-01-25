/*
 * Copyright (C) 2009 Samsung Electronics
 * Kyungmin Park <kyungmin.park@samsung.com>
 * Minkyu Kang <mk7.kang@samsung.com>
 *
 * See file CREDITS for list of people who contributed to this
 * project.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */

#include <config.h>
#include <version.h>
#include <asm/arch/cpu.h>
#include <asm/arch/power.h>
#include <asm/arch/s5pc100.h>

/*
 * Register usages:
 *
 * r5 has zero always
 */

_TEXT_BASE:
	.word	TEXT_BASE

	.globl lowlevel_init
lowlevel_init:
	mov	r9, lr

	/* IO Retention release*/
	ldr r0, =(ELFIN_CLOCK_POWER_BASE + OTHERS_OFFSET)
	ldr r1, [r0]
	ldr r2, =IO_RET_REL
	orr r1, r1, r2
	str r1, [r0]


	/* r5 has always zero */
	mov	r5, #0

	ldr	r8, =S5PC100_GPIO_BASE

	/* Disable Watchdog */
	ldr	r0, =S5PC100_WATCHDOG_BASE		@0xEA200000
	orr	r0, r0, #0x0
	str	r5, [r0]


	/* setting SRAM */
	ldr	r0, =S5PC100_SROMC_BASE
	ldr	r1, =0x9
	str	r1, [r0]

	/* init system clock */
	bl	system_clock_init



	/* for UART */
	bl 	uart_asm_init


	bl	dma_init

	bl	nand_pin_mux

	bl	nand_asm_init

#if 1
	ldr	r0, =0xff0fffff
	bic	r1, pc, r0	/* r0 <- current base addr of code		*/
	ldr	r2, _TEXT_BASE	/* r1 <- original base addr in ram		*/
	bic	r2, r2, r0	/* r0 <- current base addr of code		*/
	cmp 	r1, r2		/* compare r0, r1					*/
	beq 	1f		/* r0 == r1 then skip sdram init		*/
#endif
	bl	mem_ctrl_asm_init

1:
	/* Wakeup support. Don't know if it's going to be used, untested. */
	ldr	r0, =S5PC100_RST_STAT
	ldr	r1, [r0]
	bic	r1, r1, #0xfffffff7
	cmp	r1, #0x8
	beq	wakeup_reset


	ldr	r0, =0xec000000			/*ELFIN_UART_BASE*/
	ldr	r1, =0x4b4b4b4b
	str	r1, [r0, #20]			/*UTXH_OFFSET*/

	mov	lr, r9
	mov	pc, lr

wakeup_reset:

	/* Clear wakeup status register */
	ldr	r0, =S5PC100_WAKEUP_STAT
	ldr	r1, [r0]
	str	r1, [r0]

	/* Load return address and jump to kernel */
	ldr	r0, =S5PC100_INFORM0

	/* r1 = physical address of s5pc100_cpu_resume function */
	ldr	r1, [r0]

	/* Jump to kernel (sleep.S) */
	mov	pc, r1
	nop
	nop

/*
 * system_clock_init: Initialize core clock and bus clock.
 * void system_clock_init(void)
 */
system_clock_init:

	ldr	r0, =0xe0100000		        /*LFIN_CLOCK_POWER_BASE*/

	mov	r1, #0xe00
	orr	r1, r1, #0x10			/*e10*/
	/*input frequency = 12MHz, PLL MASKTIME = 300usec*/
	str	r1, [r0, #0x00]        		/*APLL_LOCK_OFFSET*/
	str	r1, [r0, #0x04]        		/*MPLL_LOCK_OFFSET*/
	str	r1, [r0, #0x08]        		/*EPLL_LOCK_OFFSET*/
	str	r1, [r0, #0x0c]        		/*HPLL_LOCK_OFFSET*/

	ldr r1, [r0, #0x300]			/*CLK_DIV0_OFFSET*/
	ldr	r2, =0x3fff				/*CLK_DIV0_MASK*/
	/*clear PCLK0, DO_BUS, ARM, APLL 's ratio*/
	bic	r1, r1, r2

	ldr	r2, =0x11301				/*CLK_DIV0_VAL, 1<<0 | 0<<4 | 3<<8 | 1<<12 | 1<<16=0x11301*/
	orr	r1, r1, r2					
	str	r1, [r0, #0x300]	    		/*CLK_DIV0_OFFSET*/

	ldr	r1, =0x81bc0400				/*APLL_VAL, (1<<31 | 444<<16 | 4<<8 | 0)*/
	/*enable apll, pll M divide value 444(0x1bc), pll p divide value 4*/
	str	r1, [r0, #0x100]    			/*APLL_CON_OFFSET*/

	ldr r1, [r0, #0x304]     			/*CLK_DIV1_OFFSET*/
	ldr	r2, =0x11110				/*CLK_DIV1_VAL, (1<<16)|(1<<12)|(1<<8)|(1<<4)*/
	orr	r1, r1, r2
	/*set PCLKD1, D1_BUS, MPLL2, MPLL 's ratio to 1*/
	str	r1, [r0, #0x304]     	/*CLK_DIV1_OFFSET*/

	ldr	r1, =0x80590201		/*MPLL_VAL, (1<<31 | 89<<16 | 2<<8 | 1)*/
	str	r1, [r0, #0x104]        /*MPLL_CON_OFFSET*/
	ldr	r1, =0x80870303		/*EPLL_VAL, (1<<31 | 135<<16 | 3<<8 | 3)*/
	str	r1, [r0, #0x108]  	/*EPLL_CON_OFFSET*/
	ldr	r1, =0x80600603		/*HPLL_VAL, (1<<31 | 96<<16 | 6<<8 | 3)*/
	str	r1, [r0, #0x10c]  	/*HPLL_CON_OFFSET*/

	ldr	r1, [r0, #0x200]	/*CLK_SRC0_OFFSET*/
	ldr	r2, =0x1111
	orr	r1, r1, r2		/*set APLL_SEL, MPLL_SEL, EPLL_SEL, HPLLSEL to 1*/
	str	r1, [r0, #0x200]        /*CLK_SRC0_OFFSET*/

	/*delay*/
	mov	r1, #0x10000
1:	subs	r1, r1, #1
	bne	1b
#if 0
	ldr r0, =0xe0100400
	ldr r2, =0x9000
	str r2, [r0, #0x80]
#endif
	
	/*return*/
	mov	pc, lr


#ifndef CONFIG_ONENAND_IPL
	/*
	 * uart_asm_init: Initialize UART's pins
	 */
	uart_asm_init:

	/* set GPIO(GPA) to enable UART */
	@ GPIO setting for UART
	ldr	r0, =0xe0300000		/*ELFIN_GPIO_BASE	e0300000*/
	ldr	r1, =0x22222222		/*uart0 uart1*/
	str   	r1, [r0, #0x0]		/*GPA0CON_OFFSET]*/

	ldr     r1, =0x2222		/*uart2 uart3*/
	str     r1, [r0, #0x20]		/*GPA1CON_OFFSET*/

	/*uart control registers*/
	ldr	r0, =0xEC000000		/*ELFIN_UART_CONSOLE_BASE*/
	mov	r1, #0x0
	str	r1, [r0, #0x8]	/*uart channel 0 fifo control register*/
	str	r1, [r0, #0xc]	/*uart channel 1 modem control register*/

	mov	r1, #0x3
	str	r1, [r0, #0x0]	/*uart line control register data bit is 8*/

	ldr	r1, =0x245				/*f5*/
	/*uart control register0*/
	/*bit [1:0] recive mode : interrupt request or polling mode*/
	/*bit [3:2] transmit mode : interrupt request or polling mode*/
	/*bit 4 send break signal*/
	/*bit 5 loop back mode*/
	/*bit 6 generates receieve error status interrupt*/
	/*bit 7 enable Rx time-out interrupt*/
	str	r1, [r0, #0x4]

	ldr	r1, =0x23
	str	r1, [r0, #0x28]	/*USB channel baud rate divisior register 0*/

	ldr	r1, =0x3
	str	r1, [r0, #0x2c]	/*uart channel dividing slot register 0*/

	ldr	r1, =0x4f4f4f4f			/*uart transmit buffer register*/
	str	r1, [r0, #0x20]		@'O'

	mov	pc, lr


/*
 * tzpc_asm_init: Initialize TZPC
 */
tzpc_asm_init:
	ldr	r0, =0xE3800000
	mov	r1, #0x0
	str	r1, [r0]
	mov	r1, #0xff
	str	r1, [r0, #0x804]
	str	r1, [r0, #0x810]

	ldr	r0, =0xE2800000
	str	r1, [r0, #0x804]
	str	r1, [r0, #0x810]
	str	r1, [r0, #0x81C]

	ldr	r0, =0xE2900000
	str	r1, [r0, #0x804]
	str	r1, [r0, #0x810]

	mov	pc, lr
#endif

nand_pin_mux:

	ldr     r0, =0xe03002a0  	// GPK0CON
	/*SMC_CSn[0], SMC_CSn[1], NFCSn[0], NFCSn[1], CFCSn[0], CFCSn[1]*/
	/*EBI_OEn, EBI_WEn*/
	ldr     r1, =0x22443322
	str     r1, [r0]
	ldr     r0, =0xe03002e0  	// GPK2CON
	/*NF_CLE, NF_ALE, NF_FWEn, NF_FREn, reserved*/
	/*output, output, output*/
	ldr     r1, =0x11133333
	str     r1, [r0]

	mov	pc, lr


dma_init:

	ldr	r0, =0xE3800000		/*secure ram region size register*/
	mov	r1, #0x0
	str	r1, [r0]
	mov	r1, #0xff
	str	r1, [r0, #0x804]		/*decode protection set register 0*/
	str	r1, [r0, #0x810]		/*decode protection set register 0*/

	ldr 	r0, =0xE2800000
	str	r1, [r0, #0x804]		/*decode protection set register 1*/
	str	r1, [r0, #0x810]		/*decode protection set register 1*/
	str	r1, [r0, #0x81C]		/*decode protection set register 1*/

	ldr	r0, =0xE2900000
	str	r1, [r0, #0x804]		/*decode protection set register 2*/
	str	r1, [r0, #0x810]		/*decode protection set register 2*/

	mov	pc, lr


nand_asm_init:

	ldr	r0, =0xe7200000			/*ELFIN_NAND_BASE*/
	ldr	r1, [r0, #0x0]			/*nand flash configuration register*/
	orr	r1, r1, #0x70			/*set bit 4,5,6 to 1*/
	orr	r1, r1, #0x7700			/*set bit 8,9,10 and 12,13,14 to 1*/
	str 	r1, [r0, #0x0]

	ldr 	r1, [r0, #0x4]
	orr 	r1, r1, #0x3
	bic r1, r1, #(0x20000)
	str 	r1, [r0, #0x4]

	mov	pc, lr
