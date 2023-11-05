#ifndef __FIR_H__
#define __FIR_H__

#define N 11

int taps[N] = {0,-10,-9,23,56,63,56,23,-9,-10,0};
int inputbuffer[N];
int inputsignal[N] = {1,2,3,4,5,6,7,8,9,10,11};
int outputsignal[N];


// wishbone
#define mprj_base_addr 0x30000000
// The offset
#define mprj_blklvl_base 	0x30000000
#define mprj_datlen_base 	0x30000010
#define mprj_tapparam_base 	0x30000040
#define mprj_axisin_base 	0x30000080
#define mprj_axisout_base 	0x30000084
#define addr_offset(target, offset) (target+offset)
#define send_wb(target,data) (*(volatile uint32_t*)(target)) = data
#define get_wb(target)  (*(volatile uint32_t*)(target))

#endif