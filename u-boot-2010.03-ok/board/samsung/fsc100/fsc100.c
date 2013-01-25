/*
 *  Copyright (C) 2008-2009 Samsung Electronics
 *  Minkyu Kang <mk7.kang@samsung.com>
 *  Kyungmin Park <kyungmin.park@samsung.com>
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

#include <common.h>
DECLARE_GLOBAL_DATA_PTR;

struct s5p_sromc {
	unsigned int bw;
	unsigned int bc[6];
};

/*
 * s5p_config_sromc() - select the proper SROMC Bank and configure the
 * band width control and bank control registers
 * srom_bank	- SROM
 * srom_bw_conf  - SMC Band witdh reg configuration value
 * srom_bc_conf  - SMC Bank Control reg configuration value
 */
void s5p_config_sromc(u32 srom_bank, u32 srom_bw_conf, u32 srom_bc_conf)
{
	u32 tmp;
	struct s5p_sromc *srom = (struct s5p_sromc *)(S5PC100_SROMC_BASE);

	/* Configure SMC_BW register to handle proper SROMC bank */
	tmp = srom->bw;
	tmp &= ~(0xF << (srom_bank * 4));
	tmp |= srom_bw_conf;
	srom->bw = tmp;

	/* Configure SMC_BC register */
	srom->bc[srom_bank] = srom_bc_conf;
}

#ifdef CONFIG_DRIVER_DM9000
#define DM9000_Tacs	(0x0)	// 0clk		address set-up
#define DM9000_Tcos	(0x0)	// 4clk		chip selection set-up
#define DM9000_Tacc	(0x7)	// 14clk	access cycle
#define DM9000_Tcoh	(0x0)	// 1clk		chip selection hold
#define DM9000_Tah	(0x0)	// 4clk		address holding time
#define DM9000_Tacp	(0x0)	// 6clk		page mode access cycle
#define DM9000_PMC	(0x0)	// normal(1data)page mode configuration
static void dm9000aep_pre_init(void)
{
	unsigned int tmp;
	unsigned char smc_bank_num = 1;
	u32	smc_bw_conf=0;
	u32	smc_bc_conf=0;
	smc_bw_conf &= ~(0xf<<4);
	smc_bw_conf |= (1<<7) | (1<<6) | (1<<5) | (1<<4);
    smc_bc_conf = ((DM9000_Tacs << 28)
					| (DM9000_Tcos << 24)
					| (DM9000_Tacc << 16)
					| (DM9000_Tcoh << 12)
					| (DM9000_Tah << 8)
					| (DM9000_Tacp << 4)
					| (DM9000_PMC));
	s5p_config_sromc(smc_bank_num,smc_bw_conf,smc_bc_conf);
}
#endif

int board_init(void)
{
#ifdef CONFIG_DRIVER_DM9000
	dm9000aep_pre_init();
#endif
	gd->bd->bi_arch_number = MACH_TYPE_SMDKC100;
	gd->bd->bi_boot_params = PHYS_SDRAM_1 + 0x100;

	return 0;
}

int dram_init(void)
{
	gd->bd->bi_dram[0].start = PHYS_SDRAM_1;
	gd->bd->bi_dram[0].size = get_ram_size((long *)PHYS_SDRAM_1,
						PHYS_SDRAM_1_SIZE);
	printf("the size fo dram is %d\n",gd->bd->bi_dram[0].size);

	return 0;
}

#ifdef CONFIG_DISPLAY_BOARDINFO
int checkboard(void)
{
	printf("Board:\tFSC100\n");
	return 0;
}
#endif

int board_eth_init(bd_t *bis)
{
	int rc = 0;
#ifdef CONFIG_DRIVER_DM9000
	rc = dm9000_initialize(bis);
#endif

	return rc;
}
