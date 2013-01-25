/*
 * $Id: nand_cp.c,v 1.1 2008/11/20 01:08:36 boyko Exp $
 *
 * (C) Copyright 2006 Samsung Electronics
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

/*
 * You must make sure that all functions in this file are designed
 * to load only U-Boot image.
 *
 * So, DO NOT USE in common read.
 *
 * By scsuh.
 */


#include <common.h>

#ifdef CONFIG_S5PC1XX
//#include <asm/io.h>
#include <linux/mtd/nand.h>
//#include <regs.h>
//#include <asm/arch/s5pc100.h>

#if 1
#define _REG__(x)			(*(volatile unsigned long *)(x))
#define _REGb__(x)			(*(volatile unsigned char *)(x))
#define NFCONT_REG		_REG__(0xe7200004)
#define NFCMD_REG		_REG__(0xe7200008)
#define NFADDR_REG		_REG__(0xe720000C)
#define NFSTAT_REG		_REG__(0xe7200028)
#define NFDATA8_REG		_REGb__(0xe7200010)
#endif

#define NAND_CONTROL_ENABLE()	(NFCONT_REG |= (1 << 0))

/*
 * address format
 *              17 16         9 8            0
 * --------------------------------------------
 * | block(12bit) | page(5bit) | offset(9bit) |
 * --------------------------------------------
 */

static int nandll_read_page1 (uchar *buf, ulong addr, int large_block)
{
	int i;
	int page_size = 512;
	if (large_block)
		page_size = 2048;
	NAND_ENABLE_CE();

	NFCMD_REG = NAND_CMD_READ0;

	/* Write Address */
	NFADDR_REG = 0;

	if (large_block)
		NFADDR_REG = 0;

	NFADDR_REG = (addr) & 0xff;
	NFADDR_REG = (addr >> 8) & 0xff;
	NFADDR_REG = (addr >> 16) & 0xff;

	if (large_block)
		NFCMD_REG = NAND_CMD_READSTART;

	NF_TRANSRnB();
	/* for compatibility(2460). u32 cannot be used. by scsuh */
	for(i=0; i < page_size; i++) {
		*buf++ = NFDATA8_REG;
	}
	NAND_DISABLE_CE();

#if 1
	if ((*(volatile unsigned long *)(0xe7200004)) & (1<<17))
		while(1);
#endif
	return 0;
}


static int nandll_read_page (uchar *buf, ulong addr, int large_block)
{
	int i;
	int page_size = 512;
	if (large_block)
		page_size = 2048;
	NAND_ENABLE_CE();

	NFCMD_REG = NAND_CMD_READ0;

	/* Write Address */
	NFADDR_REG = 0;

	if (large_block)
		NFADDR_REG = 0;

	NFADDR_REG = (addr) & 0xff;
	NFADDR_REG = (addr >> 8) & 0xff;
	NFADDR_REG = (addr >> 16) & 0xff;

	if (large_block)
		NFCMD_REG = NAND_CMD_READSTART;

	NF_TRANSRnB();
	/* for compatibility(2460). u32 cannot be used. by scsuh */
	for(i=0; i < page_size; i++) {
		*buf++ = NFDATA8_REG;
	}
	NAND_DISABLE_CE();
	return 0;
}


	
/*
 * Read data from NAND.
 */
static int nandll_read_blocks (ulong dst_addr, ulong size, int large_block)
{
	uchar *buf = (uchar *)dst_addr;
	int i, pages;
	uint page_shift = 9;

	if (large_block)
		page_shift = 11;

		//nandll_read_page1(buf, i, large_block);
	pages = size >> page_shift;
	/* Read pages */
	for (i = 0; i < pages; i++, buf+=(1<<page_shift)) {
		nandll_read_page(buf, i, large_block);
	}

	return 0;
}

int copy_uboot_to_ram (void)
{

	int large_block = 0;
	int i;
	vu_char id;

	NAND_CONTROL_ENABLE();
	NAND_ENABLE_CE();
	NFCMD_REG = NAND_CMD_READID;
	NFADDR_REG =  0x00;

	/* wait for a while */
	for (i=0; i<200; i++);
	id = NFDATA8_REG;
	id = NFDATA8_REG;

	if (id > 0x80)
		large_block = 1;
	/* read NAND Block.
	 * 128KB ->240KB because of U-Boot size increase. by scsuh
	 * So, read 0x3c000 bytes not 0x20000(128KB).
	 */
	return nandll_read_blocks(0x2ff80000, 0x40000, large_block);
}
#endif
