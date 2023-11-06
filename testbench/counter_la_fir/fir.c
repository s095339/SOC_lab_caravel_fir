#include "fir.h"
#include <stdint.h> 
#include <stdbool.h>
// The base address of user project

/*
User Project Memory Starting: 3800_0000
User Project FIR Base Address : 3000_0000 
0x00 – [0] - ap_start (r/w) 
set, when ap_start signal assert
reset, when start data transfer, i.e. 1st axi-stream data come in
[1] – ap_done (ro) -> when FIR process all the dataset, i.e. receive tlast and last Y generated/transferred
[2] – ap_idle (ro) -> indicate FIR is actively processing data
[3] – Reserved (ro) -> read zero
[4] – X[n]_ready to accept input (ro) -> X[n] is ready to accept input. 
[5] - Y[n] is ready to read -> set when Y[n] is ready, reset when 0x00 is read
0x10-13 - data-length
0x40-7F – Tap parameters, (e.g., 0x40-43 Tap0, in sequence …)
0x80-83 – X[n] input (r/w)
0x84-87 – Y[n] output (ro)
*/




void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	//initial your fir
	
	send_wb(mprj_datlen, data_len);
	// send tap data
	for(uint8_t i = 0; i<N; i++){
		send_wb(addr_offset(mprj_tapparam_base,i<<2), taps[i]);
	}

	// read back tap data for debugging
	for(uint8_t i = 0; i<N; i++){
		int32_t register tmp =  read_wb(addr_offset(mprj_tapparam_base,i<<2));
		send_wb(checkbit, tmp);
	}


}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(){
	//initfir();
	enum BLKLVL blklvl;
	send_wb(mprj_datlen, data_len);
	// check ap_idle and send ap_start
	//while( read_wb(mprj_blklvl_base) & (1<<ap_done ) != 0x00000004);
	//send_wb(mprj_blklvl_base,  (1 << ap_start) );
	int32_t register i = 0;
	int32_t is_full = 0;
	while(i<data_len){
		if(read_wb(axisin_full) == 0x00000000){
			send_wb(fir_axisin, i++);
		}
		
	}
	

	return outputsignal;
}
		
