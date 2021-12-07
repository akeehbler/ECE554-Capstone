module memory_stage(
    //Inputs
    aluResult, read2Data, clk, rst, memWrite, memRead, halt, mcDataIn, mcDataValid, evictDone,
    //Outputs
    memoryOut, cacheMiss, mcDataOut, cacheEvict, stallDMAMem
);

    input clk, rst;

    //Address to read into the memory
    input [31:0] aluResult;
    input [31:0] read2Data;

    input memWrite, memRead, halt;

    //Lets the data cache know that the data from the mc is valid data
    input mcDataValid;
    
    //Data from the mc to be written to the cache
    input [511:0] mcDataIn;

    // Signal from the MC to let the memory_stage know that an evict has completed
    input evictDone;

    //Result of a memory read
    output reg [31:0] memoryOut;
    
    //Control signal for the mc if we are requesting a block
    output reg cacheMiss;

    //Control signal for the mc if we are evicting a block
    output reg cacheEvict;

    //Data to be output if there is a cache evict
    output reg [511:0] mcDataOut;
    
    //Signal to stall because there is a DMA request in process
    output reg stallDMAMem;

    // state variables
    typedef enum logic [3:0] {  IDLE = 4'b0,
                                READ = 4'b1, EVICT_RD = 4'b10, LOAD_RD = 4'b11, WAIT_RD = 4'b100,
                                WRITE = 4'b101, EVICT_WR = 4'b110, LOAD_WR = 4'b111, WAIT_WR = 4'b1000} state;
    state currState;
    state nextState;

    //Intermediate signals for the state machine
    logic [31:0] cacheDataOut;
    logic cacheMissOut;
    logic cacheHitOut;
    logic cacheEvictOut;
    logic [511:0] cacheBlkOut;

    logic [31:0] cacheAddr;
    logic cacheEnable;
    logic [511:0] cacheBlkIn;
    logic [31:0] cacheDataIn;
    logic cacheWrite;
    logic cacheRead;
    logic cacheLoad;

    //Instantiate memory here
    data_cache iDataCache(  .clk(clk), 
                    .rst(rst), 
                    .en(cacheEnable),
                    .addr(cacheAddr),  
                    .blkIn(cacheBlkIn), 
                    .dataIn(cacheDataIn), 
                    .rd(cacheRead),
                    .wr(cacheWrite), 
                    .ld(cacheLoad),
                    //Outputs 
                    .dataOut(cacheDataOut), 
                    .hit(cacheHitOut), 
                    .miss(cacheMissOut), 
                    .evict(cacheEvictOut), 
                    .blkOut(cacheBlkOut));

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            currState <= IDLE;
        end else begin
            currState <= nextState;
        end
    end
    
    always_comb begin
        nextState = IDLE;
        //Outputs of Cache
        memoryOut = 32'b0; //output of memory stage
        cacheMiss = 1'b0; //output of memory stage
        cacheEvict = 1'b0; //output of the memory stage
        mcDataOut = 512'b0;
        //Inputs of the cache
        cacheAddr = 32'b0;
        cacheEnable = 1'b0;
        cacheBlkIn = 512'b0;
        cacheDataIn = 32'b0;
        cacheRead = 1'b0;
        cacheWrite = 1'b0;
        cacheLoad = 1'b0;
        
        stallDMAMem = 1'b0; //Output of memory stage
        
        case(currState)
            IDLE: begin              
		        nextState = (memRead) ? READ : ((memWrite) ? WRITE : IDLE);
                // Dont think this is right
                memoryOut = cacheDataOut;
            end
            READ: begin
                cacheAddr = aluResult;
                cacheEnable = 1'b1;
                cacheRead = 1'b1;
                memoryOut = cacheDataOut;
                cacheMiss = cacheMissOut;
                nextState = (cacheHitOut) ? IDLE : (cacheEvictOut) ? EVICT_RD : LOAD_RD;
            end
            EVICT_RD: begin
                cacheAddr = aluResult;
                cacheEnable = 1'b1;
                cacheEvict = 1'b1;
                mcDataOut = cacheBlkOut;
                stallDMAMem = 1'b1;
                nextState = (evictDone) ? LOAD_RD : EVICT_RD;
            end
            LOAD_RD: begin
                cacheAddr = aluResult;
                cacheEnable = 1'b1;
                stallDMAMem = 1'b1;
                cacheLoad = 1'b1;
                cacheBlkIn = mcDataIn;
                nextState = (mcDataValid) ? WAIT_RD : LOAD_RD;
            end
            WAIT_RD: begin
                stallDMAMem = 1'b1;
                nextState = READ;
            end
            WRITE: begin
                cacheAddr = aluResult;
                cacheEnable = 1'b1;
                cacheWrite = 1'b1;
                cacheDataIn = read2Data;
                nextState = (cacheHitOut) ? IDLE : (cacheEvictOut) ? EVICT_WR : LOAD_WR;
            end
            EVICT_WR: begin
                cacheAddr = aluResult;
                cacheEvict = 1'b1;
                mcDataOut = cacheBlkOut;
                stallDMAMem = 1'b1;
                nextState = (evictDone) ? LOAD_WR : EVICT_WR;
            end
            LOAD_WR: begin
                cacheAddr = aluResult;
                cacheMiss = 1'b1;
                stallDMAMem = 1'b1;
                cacheLoad = 1'b1;
                cacheBlkIn = mcDataIn;
                nextState = (mcDataValid) ? WAIT_WR : LOAD_WR;
            end
            WAIT_WR: begin
                stallDMAMem = 1'b1;
                nextState = WRITE;
            end
            default: begin
                nextState = IDLE;
                stallDMAMem = 1'b1;
            end
        endcase
    end

endmodule