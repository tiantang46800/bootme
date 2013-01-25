/*
 * (C) Copyright 2000-2003
 * Wolfgang Denk, DENX Software Engineering, wd@denx.de.
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
 * Misc boot support
 */
#include <common.h>
#include <command.h>
#include <net.h>

/* Allow ports to override the default behavior */
__attribute__((weak))
unsigned long do_go_exec (ulong (*entry)(int, char *[]), int argc, char *argv[])
{
	return entry (argc, argv);
}

int do_go (cmd_tbl_t *cmdtp, int flag, int argc, char *argv[])
{
	ulong	addr, rc;
	int     rcode = 0;

	if (argc < 2) {
		cmd_usage(cmdtp);
		return 1;
	}
	/************* farsight **************/
	char *commandline = getenv("bootargs");
	/************* farsight **************/

	struct param_struct *lht_params=(struct param_struct *)0x20000100;

	printf("setup linux parameters at 0x20000100\n");
	memset(lht_params,0,sizeof(struct param_struct));
	lht_params->u1.s.page_size=4096;
	lht_params->u1.s.nr_pages=0x10000000>>12;
	memcpy(lht_params->commandline,commandline,strlen(commandline)+1);
	printf("linux command line is: \"%s\"\n",commandline);
	/************* farsight **************/

	addr = simple_strtoul(argv[1], NULL, 16);

	printf ("## Starting application at 0x%08lX ...\n", addr);

	/************** farsight *************/
	__asm__(
		"ldr 	r1, =1826\n"
		"mov	ip, #0\n"
		"mcr 	p15, 0, ip, c8, c7, 0\n"
		"mcr	p15, 0, ip, c7, c5, 0\n"
		"mcr 	p15, 0, ip, c7, c5, 6\n"
		"mcr 	p15, 0, ip, c7, c10, 4\n"
		"mcr 	p15, 0, ip, c7, c5, 4\n"

		"mrc	p15, 0, ip, c1, c0, 0\n"
		"bic	ip, ip, #0x00002000\n"
		"bic 	ip, ip, #0x00000007\n"
		"orr 	ip, ip, #0x00000002\n"
		"orr 	ip, ip, #0x00000800\n"
		"bic	ip, ip, #0x00001000\n"
		"mcr	p15, 0, ip, c1, c0, 0\n"
		
		"mov pc, %[zImage]\n"
		"nop\n"
		:
		:[zImage]"r"(addr)
		:"r1"
		);
	/**************** farsight ************/

	/*
	 * pass address parameter as argv[0] (aka command name),
	 * and all remaining args
	 */
	rc = do_go_exec ((void *)addr, argc - 1, argv + 1);
	if (rc != 0) rcode = 1;

	printf ("## Application terminated, rc = 0x%lX\n", rc);
	return rcode;
}

/* -------------------------------------------------------------------- */

U_BOOT_CMD(
	go, CONFIG_SYS_MAXARGS, 1,	do_go,
	"start application at address 'addr'",
	"addr [arg ...]\n    - start application at address 'addr'\n"
	"      passing 'arg' as arguments"
);

extern int do_reset (cmd_tbl_t *cmdtp, int flag, int argc, char *argv[]);

U_BOOT_CMD(
	reset, 1, 0,	do_reset,
	"Perform RESET of the CPU",
	""
);
