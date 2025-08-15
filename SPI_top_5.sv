module SPI_top_5 (
    input  logic clk,            // Clock 12MHz
    input  logic rst_n,          // Asynchronous active-low reset
    output logic SCLK,           // Serial Clock
    output logic RCLK,           // Register Clock (Latch)
    output logic DIO,            // Data Input/Output
    // SPI MASTER INTERFACE TO LIS3DH SENSOR
    output       SCLK_2,
    output       CS_N,
    output       MOSI,
    input        MISO
);

    // USER LEDS
    logic [7:0] USER_LEDS;
    logic [7:0] USER_LEDS_2;
    logic [7:0] USER_LEDS_3;

// SPI_x	 
    SPI_xyz_4 SPI_xyz_4_inst (
	 .CLK_12M(clk), .RST_BTN_N(rst_n), .SCLK(SCLK_2), .CS_N(CS_N), .MOSI(MOSI), .MISO(MISO), .USER_LEDS(USER_LEDS), .USER_LEDS_2(USER_LEDS_2), .USER_LEDS_3(USER_LEDS_3)
);


// Giá trị hiển thị cho 3 LED 7 đoạn
logic [3:0] display_value [0:2]; // 0: LED1, 1: LED2, 2: LED3

// 7-segment LED encoding table (common cathode)
logic [7:0] LED_0F [0:15] = '{
  8'hC0, // 0
  8'hF9, // 1
  8'hA4, // 2
  8'hB0, // 3
  8'h99, // 4
  8'h92, // 5
  8'h82, // 6
  8'hF8, // 7
  8'h80, // 8
  8'h90, // 9
  8'h88, // A (10)
  8'h83, // b (11)
  8'hC6, // C (12)
  8'hA1, // d (13)
  8'h86, // E (14)
  8'h8E  // F (15)
};

// Digit selection (active-low) cho 3 LED
logic [7:0] digit_select [0:2] = '{
  8'b11110100, // Chọn LED 1
  8'b11110010, // Chọn LED 2
  8'b11110001  // Chọn LED 3
};

// FSM states
typedef enum logic [1:0] {
  IDLE,
  SEND_SEGMENT,
  SEND_DIGIT,
  LATCH
} display_state_t;

display_state_t current_state;

// Clock divider for LED scanning (~6kHz)
logic [15:0] fast_counter = 0;
logic fast_clk = 0;

// Index cho LED hiện tại đang được điều khiển
logic [1:0] led_index = 0;

// Xử lý dữ liệu đầu vào cho 3 LED
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    display_value[0] <= 0;
    display_value[1] <= 0;
    display_value[2] <= 0;
  end else begin
    // Lấy 4 bit thấp của từng đầu vào (0-15)
    display_value[0] <= USER_LEDS[3:0];   // LED 1
    display_value[1] <= USER_LEDS_2[3:0]; // LED 2
    display_value[2] <= USER_LEDS_3[3:0]; // LED 3
  end
end

// Clock divider for LED scanning (~6kHz)
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    fast_counter <= 0;
    fast_clk <= 0;
  end else begin
    if (fast_counter >= 16'd50) begin
      fast_counter <= 0;
      fast_clk <= ~fast_clk;
    end else begin
      fast_counter <= fast_counter + 1;
    end
  end
end

// Display FSM (use fast clock)
logic [3:0] delay_cnt;
logic [7:0] shift_data;
logic [3:0] bit_cnt;

always_ff @(posedge fast_clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    SCLK <= 1;
    RCLK <= 1;
    DIO <= 0;
    bit_cnt <= 0;
    delay_cnt <= 0;
    led_index <= 0;
  end else begin
    SCLK <= 1;
    RCLK <= 1;
    DIO <= 0;
    delay_cnt <= 0;

    case (current_state)
      IDLE: begin
        // Chọn dữ liệu hiển thị cho LED hiện tại
        shift_data <= LED_0F[display_value[led_index]]; 
        bit_cnt <= 0;
        current_state <= SEND_SEGMENT;
      end

      SEND_SEGMENT: begin
        if (bit_cnt < 8) begin
          SCLK <= 0;
          DIO <= shift_data[7];
          if (delay_cnt < 2) begin
            delay_cnt <= delay_cnt + 1;
          end else begin
            SCLK <= 1;
            shift_data <= shift_data << 1;
            bit_cnt <= bit_cnt + 1;
            delay_cnt <= 0;
          end
        end else begin
          shift_data <= digit_select[led_index]; // Chọn digit tương ứng
          bit_cnt <= 0;
          current_state <= SEND_DIGIT;
        end
      end

      SEND_DIGIT: begin
        if (bit_cnt < 8) begin
          SCLK <= 0;
          DIO <= shift_data[7];
          if (delay_cnt < 2) begin
            delay_cnt <= delay_cnt + 1;
          end else begin
            SCLK <= 1;
            shift_data <= shift_data << 1;
            bit_cnt <= bit_cnt + 1;
            delay_cnt <= 0;
          end
        end else begin
          RCLK <= 0;
          if (delay_cnt < 5) begin
            delay_cnt <= delay_cnt + 1;
          end else begin
            RCLK <= 1;
            current_state <= LATCH;
          end
        end
      end

      LATCH: begin
        // Chuyển sang LED tiếp theo
        led_index <= (led_index == 2) ? 0 : led_index + 1;
        current_state <= IDLE;
      end
    endcase
  end
end

endmodule    

/*module SPI_top_5 (
//    input  logic [7:0] data_in,  // Đầu vào 8 bit
    input  logic clk,            // Clock 12MHz
    input  logic rst_n,          // Asynchronous active-low reset
    output logic SCLK,           // Serial Clock
    output logic RCLK,           // Register Clock (Latch)
    output logic DIO,             // Data Input/Output
	 
    // SPI MASTER INTERFACE TO LIS3DH SENSOR
    output       SCLK_2,
    output       CS_N,
    output       MOSI,
    input        MISO
    
);

// SPI_x	 
    SPI_top_4 SPI_top_4_inst (
	 .CLK_12M(clk), .RST_BTN_N(rst_n), .SCLK(SCLK_2), .CS_N(CS_N), .MOSI(MOSI), .MISO(MISO), .USER_LEDS(USER_LEDS), .USER_LEDS_2(USER_LEDS_2), .USER_LEDS_3(USER_LEDS_3)
);
// USER LEDS
    logic [7:0] USER_LEDS_2;
	 
	 
// Giá trị hiển thị (0-15, lấy 4 bit thấp của đầu vào)
logic [3:0] display_value;

// 7-segment LED encoding table (common cathode)
logic [7:0] LED_0F [0:15] = '{
  8'hC0, // 0
  8'hF9, // 1
  8'hA4, // 2
  8'hB0, // 3
  8'h99, // 4
  8'h92, // 5
  8'h82, // 6
  8'hF8, // 7
  8'h80, // 8
  8'h90, // 9
  8'h88, // A (10)
  8'h83, // b (11)
  8'hC6, // C (12)
  8'hA1, // d (13)
  8'h86, // E (14)
  8'h8E  // F (15)
};

// Digit selection (chọn digit đầu tiên - active low)
logic [7:0] digit_select = 8'b11111000; // Đã sửa thành giá trị chính xác

// FSM states
typedef enum logic [1:0] {
  IDLE,
  SEND_SEGMENT,
  SEND_DIGIT,
  LATCH
} display_state_t;

display_state_t current_state;

// Clock divider for LED scanning (~6kHz)
logic [15:0] fast_counter = 0;
logic fast_clk = 0;

// Xử lý dữ liệu đầu vào
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    display_value <= 0;
  end else begin
    // Lấy 4 bit thấp của đầu vào (0-15)
    display_value <= USER_LEDS_2[3:0];
  end
end

// Clock divider for LED scanning (~6kHz)
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    fast_counter <= 0;
    fast_clk <= 0;
  end else begin
    if (fast_counter >= 16'd50) begin
      fast_counter <= 0;
      fast_clk <= ~fast_clk;
    end else begin
      fast_counter <= fast_counter + 1;
    end
  end
end

// Display FSM (use fast clock)
logic [3:0] delay_cnt;
logic [7:0] shift_data;
logic [3:0] bit_cnt;

always_ff @(posedge fast_clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    SCLK <= 1;
    RCLK <= 1;
    DIO <= 0;
    bit_cnt <= 0;
    delay_cnt <= 0;
  end else begin
    SCLK <= 1;
    RCLK <= 1;
    DIO <= 0;
    delay_cnt <= 0;

    case (current_state)
      IDLE: begin
        shift_data <= LED_0F[display_value]; // Chỉ hiển thị giá trị hiện tại
        bit_cnt <= 0;
        current_state <= SEND_SEGMENT;
      end

      SEND_SEGMENT: begin
        if (bit_cnt < 8) begin
          SCLK <= 0;
          DIO <= shift_data[7];
          if (delay_cnt < 2) begin
            delay_cnt <= delay_cnt + 1;
          end else begin
            SCLK <= 1;
            shift_data <= shift_data << 1;
            bit_cnt <= bit_cnt + 1;
            delay_cnt <= 0;
          end
        end else begin
          shift_data <= digit_select; // Sử dụng giá trị digit select chính xác
          bit_cnt <= 0;
          current_state <= SEND_DIGIT;
        end
      end

      SEND_DIGIT: begin
        if (bit_cnt < 8) begin
          SCLK <= 0;
          DIO <= shift_data[7];
          if (delay_cnt < 2) begin
            delay_cnt <= delay_cnt + 1;
          end else begin
            SCLK <= 1;
            shift_data <= shift_data << 1;
            bit_cnt <= bit_cnt + 1;
            delay_cnt <= 0;
          end
        end else begin
          RCLK <= 0;
          if (delay_cnt < 5) begin
            delay_cnt <= delay_cnt + 1;
          end else begin
            RCLK <= 1;
            current_state <= LATCH;
          end
        end
      end

      LATCH: begin
        current_state <= IDLE;
      end
    endcase
  end
end

endmodule
*/

////////////////////////////////////////////////

module SPI_xyz_4 (
    input        CLK_12M,     // system clock 12 MHz
    input        RST_BTN_N,   // low active reset button
    // SPI MASTER INTERFACE TO LIS3DH SENSOR
    output       SCLK,
    output       CS_N,
    output       MOSI,
    input        MISO,
    // USER LEDS
    output logic [7:0] USER_LEDS,
	 output logic [7:0] USER_LEDS_2,
	 output logic [7:0] USER_LEDS_3,
	 output test
);

    wire rst_btn;
    wire reset;

	 reg [7:0] timeout_cnt;
	 
    reg [7:0] spi_din;
    reg spi_din_last;
    reg spi_din_vld;
    wire spi_din_rdy;
    wire [7:0] spi_dout;
    wire spi_dout_vld;

    // FSM states
    localparam [3:0] 
        cfg1_addr = 0,
        cfg1_wr   = 1,
        out_x_addr  = 2,
        out_x_rd    = 3,
        out_x_do    = 4,
		  out_y_addr  =5,
		  out_y_rd    =6,
		  out_y_do    =7,
		  out_z_addr  =8,
		  out_z_rd    =9,
		  out_z_do    =10;
		  

    
    reg [3:0] fsm_pstate;
    reg [3:0] fsm_nstate;

    reg sensor_wr_x;
	 reg sensor_wr_y;
	 
	 reg sensor_wr_z ;
	 
    reg [7:0] x_data_unsigned;
	 reg [7:0] y_data_unsigned;
	 reg [7:0] z_data_unsigned;
    reg signed [7:0] x_data;
	 reg signed [7:0] y_data;
	 reg signed [7:0] z_data;

    assign rst_btn = ~RST_BTN_N;

	 assign test = sensor_wr_z;
	 
    // Reset synchronizer
    RST_SYNC rst_sync_i (
        .CLK(CLK_12M),
        .ASYNC_RST(rst_btn),
        .SYNCED_RST(reset)
    );

    // SPI Master instance
    SPI_MASTER #(
        .CLK_FREQ(12_000_000),
        .SCLK_FREQ(1_000_000),
        .SLAVE_COUNT(1)
    ) spi_master_i (
        .CLK(CLK_12M),
        .RST(reset),
        // SPI MASTER INTERFACE
        .SCLK(SCLK),
        .CS_N(CS_N),
        .MOSI(MOSI),
        .MISO(MISO),
        // USER INTERFACE
        .DIN_ADDR(0),
        .DIN(spi_din),
        .DIN_LAST(spi_din_last),
        .DIN_VLD(spi_din_vld),
        .DIN_RDY(spi_din_rdy),
        .DOUT(spi_dout),
        .DOUT_VLD(spi_dout_vld)
    );

    // FSM state register
    always @(posedge CLK_12M) begin
        if (reset) begin
            fsm_pstate <= cfg1_addr;
        end else begin
            fsm_pstate <= fsm_nstate;
        end
    end

    // FSM next state and output logic
    always @(*) begin
        fsm_nstate = fsm_pstate;
        spi_din = 8'b0;
        spi_din_last = 1'b0;
        spi_din_vld = 1'b0;
        sensor_wr_x = 1'b0;
		  sensor_wr_y =1'b0;
		  sensor_wr_z =1'b0;

        case (fsm_pstate)
            cfg1_addr: begin
                spi_din = 8'b00100000;
                spi_din_vld = 1'b1;
                if (spi_din_rdy) begin
                    fsm_nstate = cfg1_wr;
                end
            end
            
            cfg1_wr: begin
                spi_din = 8'h37;
                spi_din_vld = 1'b1;
                spi_din_last = 1'b1;
                if (spi_din_rdy) begin
                    fsm_nstate = out_x_addr;
                end
            end
            


            out_x_addr: begin
                spi_din = 8'b10101001;
                spi_din_vld = 1'b1;
                if (spi_din_rdy) begin
                    fsm_nstate = out_x_rd;
                end
            end
            
            out_x_rd: begin
                spi_din_vld = 1'b1;
                spi_din_last = 1'b1;
                if (spi_din_rdy) begin
                    fsm_nstate = out_x_do;
                end
            end
            
            out_x_do: begin
                if (spi_dout_vld) begin
                    sensor_wr_x = 1'b1;
                    fsm_nstate = out_y_addr;
                end
            end
				
				 out_y_addr: begin
                spi_din = 8'b10101011;
                spi_din_vld = 1'b1;
                if (spi_din_rdy) begin
                    fsm_nstate = out_y_rd;
                end
            end
				
				 out_y_rd: begin
                spi_din_vld = 1'b1;
                spi_din_last = 1'b1;
                if (spi_din_rdy) begin
                    fsm_nstate = out_y_do;
                end
            end
				
				out_y_do: begin
                if (spi_dout_vld) begin
                    sensor_wr_y = 1'b1;
                    fsm_nstate = out_z_addr;
                end
            end
				
				out_z_addr: begin
                spi_din = 8'b10101101;
                spi_din_vld = 1'b1;
                if (spi_din_rdy) begin
                    fsm_nstate = out_z_rd;
                end
            end
				
				 out_z_rd: begin
                spi_din_vld = 1'b1;
                spi_din_last = 1'b1;
                if (spi_din_rdy) begin
                    fsm_nstate = out_z_do;
                end
            end
				
				out_z_do: begin
               if (spi_dout_vld) begin
               sensor_wr_z = 1'b1;
               fsm_nstate = out_x_addr;
               //end else if (timeout_cnt > 100) begin
               //fsm_nstate = out_x_addr;
              end
            end
        endcase
    end
	 
/*	 // Time out
	 always_ff @(posedge CLK_12M or posedge reset) begin
    if (reset) begin
        timeout_cnt <= 8'd0;
    end else if (fsm_pstate != out_z_do) begin
        timeout_cnt <= 8'd0;
    end else if (!spi_dout_vld) begin
        timeout_cnt <= timeout_cnt + 1;
    end else begin
        timeout_cnt <= 8'd0;
    end
end */

    // Sensor data register
    always @(posedge CLK_12M) begin
        if (sensor_wr_x) begin
            x_data_unsigned <= spi_dout;
        end 
		  if (sensor_wr_y) begin
            y_data_unsigned <= spi_dout;
        end 
		  if ( sensor_wr_z ) begin
            z_data_unsigned <= spi_dout;
        end
    end

  // LED output logic
    assign x_data = $signed(x_data_unsigned);
    assign y_data = $signed(y_data_unsigned);
    assign z_data= $signed(z_data_unsigned);

    // LED output logic for X-axis (original)
    always @(posedge CLK_12M) begin
        USER_LEDS <= 8'b00000000;
        
        if (x_data <= -90) begin
            USER_LEDS <= 8'b00001001;
        end
        else if (x_data > -90 && x_data <= -80) begin
            USER_LEDS <= 8'b00001000;
        end
        else if (x_data > -80 && x_data <= -70) begin
            USER_LEDS <= 8'b00000111;
        end
        else if (x_data > -70 && x_data <= -60) begin
            USER_LEDS <= 8'b00000110;
        end
		  else if (x_data > -60 && x_data <= -50) begin
            USER_LEDS <= 8'b00000101;
        end
		  else if (x_data > -50 && x_data <= -40) begin
            USER_LEDS <= 8'b00000100;
        end
		  else if (x_data > -40 && x_data <= -30) begin
            USER_LEDS <= 8'b00000011;
        end
		  else if (x_data > -30 && x_data <= -20) begin
            USER_LEDS <= 8'b00000010;
        end
		  else if (x_data > -20 && x_data <= -10) begin
            USER_LEDS <= 8'b00000001;
        end
        else if (x_data > -10 && x_data < 10) begin
            USER_LEDS <= 8'b00000000;
        end
        else if (x_data >= 10 && x_data < 20) begin
            USER_LEDS <= 8'b00000001;
        end
        else if (x_data >= 20 && x_data < 30) begin
            USER_LEDS <= 8'b00000010;
        end
        else if (x_data >= 30 && x_data < 40) begin
            USER_LEDS <= 8'b00000011;
        end
		  else if (x_data >= 40 && x_data < 50) begin
            USER_LEDS <= 8'b00000100;
        end
		  else if (x_data >= 50 && x_data < 60) begin
            USER_LEDS <= 8'b00000101;
        end
		  else if (x_data >= 60 && x_data < 70) begin
            USER_LEDS <= 8'b00000110;
        end
		  else if (x_data >= 70 && x_data < 80) begin
            USER_LEDS <= 8'b00000111;
        end
		  else if (x_data >= 80 && x_data < 90) begin
            USER_LEDS <= 8'b00001000;
        end
        else if (x_data >= 90) begin
            USER_LEDS <= 8'b00001001;
        end
    end

    // LED output logic for Y-axis (new)
    always @(posedge CLK_12M) begin
        USER_LEDS_2 <= 8'b00000000;
        
        if (y_data <= -90) begin
            USER_LEDS_2 <= 8'b00001001;
        end
        else if (y_data > -90 && y_data <= -80) begin
            USER_LEDS_2 <= 8'b00001000;
        end
        else if (y_data > -80 && y_data <= -70) begin
            USER_LEDS_2 <= 8'b00000111;
        end
        else if (y_data > -70 && y_data <= -60) begin
            USER_LEDS_2 <= 8'b00000110;
        end
		  else if (y_data > -60 && y_data <= -50) begin
            USER_LEDS_2 <= 8'b00000101;
        end
		  else if (y_data > -50 && y_data <= -40) begin
            USER_LEDS_2 <= 8'b00000100;
        end
		  else if (y_data > -40 && y_data <= -30) begin
            USER_LEDS_2 <= 8'b00000011;
        end
		  else if (y_data > -30 && y_data <= -20) begin
            USER_LEDS_2 <= 8'b00000010;
        end
		  else if (y_data > -20 && y_data <= -10) begin
            USER_LEDS_2 <= 8'b00000001;
        end
        else if (y_data > -10 && y_data < 10) begin
            USER_LEDS_2 <= 8'b00000000;
        end
        else if (y_data >= 10 && y_data < 20) begin
            USER_LEDS_2 <= 8'b00000001;
        end
        else if (y_data >= 20 && y_data < 30) begin
            USER_LEDS_2 <= 8'b00000010;
        end
        else if (y_data >= 30 && y_data < 40) begin
            USER_LEDS_2 <= 8'b00000011;
        end
		  else if (y_data >= 40 && y_data < 50) begin
            USER_LEDS_2 <= 8'b00000100;
        end
		  else if (y_data >= 50 && y_data < 60) begin
            USER_LEDS_2 <= 8'b00000101;
        end
		  else if (y_data >= 60 && y_data < 70) begin
            USER_LEDS_2 <= 8'b00000110;
        end
		  else if (z_data >= 70 && y_data < 80) begin
            USER_LEDS_2 <= 8'b00000111;
        end
		  else if (y_data >= 80 && y_data < 90) begin
            USER_LEDS_2 <= 8'b00001000;
        end
        else if (y_data >= 90) begin
            USER_LEDS_2 <= 8'b00001001;
        end
    end

    // LED output logic for Z-axis (new)
    always @(posedge CLK_12M) begin
        USER_LEDS_3 <= 8'b00000000;
        
        if (z_data <= -90) begin
            USER_LEDS_3 <= 8'b00001001;
        end
        else if (z_data > -90 && z_data <= -80) begin
            USER_LEDS_3 <= 8'b00001000;
        end
       else if (z_data > -80 && z_data <= -70) begin
            USER_LEDS_3 <= 8'b00000111;
        end
        else if (z_data > -70 && z_data <= -60) begin
            USER_LEDS_3 <= 8'b00000110;
        end
		  else if (z_data > -60 && z_data <= -50) begin
            USER_LEDS_3 <= 8'b00000101;
        end
		  else if (z_data > -50 && z_data <= -40) begin
            USER_LEDS_3 <= 8'b00000100;
        end
		  else if (z_data > -40 && z_data <= -30) begin
            USER_LEDS_3 <= 8'b00000011;
        end
		  else if (z_data > -30 && z_data <= -20) begin
            USER_LEDS_3 <= 8'b00000010;
        end
		  else if (z_data > -20 && z_data <= -10) begin
            USER_LEDS_3 <= 8'b00000001;
        end
        else if (z_data > -10 && z_data < 10) begin
            USER_LEDS_3 <= 8'b00000000;
        end
        else if (z_data >= 10 && z_data < 20) begin
            USER_LEDS_3 <= 8'b00000001;
        end
        else if (z_data >= 20 && z_data < 30) begin
            USER_LEDS_3 <= 8'b00000010;
        end
        else if (z_data >= 30 && z_data < 40) begin
            USER_LEDS_3 <= 8'b00000011;
        end
		  else if (z_data >= 40 && z_data < 50) begin
            USER_LEDS_3 <= 8'b00000100;
        end
		  else if (z_data >= 50 && z_data < 60) begin
            USER_LEDS_3 <= 8'b00000101;
        end
		  else if (z_data >= 60 && z_data < 70) begin
            USER_LEDS_3 <= 8'b00000110;
        end
		  else if (z_data >= 70 && z_data < 80) begin
            USER_LEDS_3 <= 8'b00000111;
        end
		  else if (z_data >= 80 && z_data < 90) begin
            USER_LEDS_3 <= 8'b00001000;
        end
        else if (z_data >= 90) begin
            USER_LEDS_3 <= 8'b00001001;
        end
    end

endmodule

// Reset Synchronizer
module RST_SYNC (
    input  CLK,
    input  ASYNC_RST,
    output SYNCED_RST
);

    reg meta_reg;
    reg reset_reg;

    always @(posedge CLK or posedge ASYNC_RST) begin
        if (ASYNC_RST) begin
            meta_reg  <= 1'b1;
            reset_reg <= 1'b1;
        end else begin
            meta_reg  <= 1'b0;
            reset_reg <= meta_reg;
        end
    end

    assign SYNCED_RST = reset_reg;

endmodule

// SPI Master Module
module SPI_MASTER #(
    parameter CLK_FREQ    = 12_000_000,
    parameter SCLK_FREQ   = 1_000_000,
    parameter WORD_SIZE   = 8,
    parameter SLAVE_COUNT = 1
)(
    input  CLK,
    input  RST,
    // SPI MASTER INTERFACE
    output SCLK,
    output [SLAVE_COUNT-1:0] CS_N,
    output MOSI,
    input  MISO,
    // INPUT USER INTERFACE
    input  [WORD_SIZE-1:0] DIN,
    input  [$clog2(SLAVE_COUNT)-1:0] DIN_ADDR,
    input  DIN_LAST,
    input  DIN_VLD,
    output DIN_RDY,
    // OUTPUT USER INTERFACE
    output [WORD_SIZE-1:0] DOUT,
    output DOUT_VLD
);

    localparam DIVIDER_VALUE = (CLK_FREQ/SCLK_FREQ)/2;
    localparam WIDTH_CLK_CNT = $clog2(DIVIDER_VALUE);
    localparam WIDTH_ADDR    = $clog2(SLAVE_COUNT);
    localparam BIT_CNT_WIDTH = $clog2(WORD_SIZE);

    // FSM states
    localparam [2:0] 
        idle         = 0,
        first_edge   = 1,
        second_edge  = 2,
        transmit_end = 3,
        transmit_gap = 4;

    reg [WIDTH_ADDR-1:0] addr_reg;
    reg [WIDTH_CLK_CNT-1:0] sys_clk_cnt;
    wire sys_clk_cnt_max;
    reg spi_clk;
	 wire spi_clk_temp;
    wire spi_clk_rst;
    reg din_last_reg_n;
    wire first_edge_en;
    wire second_edge_en;
    reg chip_select_n;
    wire load_data;
    reg miso_reg;
    reg [WORD_SIZE-1:0] shreg;
    reg [BIT_CNT_WIDTH-1:0] bit_cnt;
    wire bit_cnt_max;
    wire rx_data_vld;
    wire master_ready;
    reg [2:0] present_state;
    reg [2:0] next_state;

    assign load_data = master_ready & DIN_VLD;
    assign DIN_RDY = master_ready;
    assign sys_clk_cnt_max = (sys_clk_cnt == DIVIDER_VALUE-1);
    assign bit_cnt_max = (bit_cnt == WORD_SIZE-1);
    
    // System clock counter
    always @(posedge CLK) begin
        if (RST || sys_clk_cnt_max) begin
            sys_clk_cnt <= 0;
        end else begin
            sys_clk_cnt <= sys_clk_cnt + 1;
        end
    end

 /*   // SPI clock generator
    always @(posedge CLK) begin
        if (RST || spi_clk_rst) begin
            spi_clk <= 0;
        end else if (sys_clk_cnt_max) begin
            spi_clk <= ~spi_clk;
        end
    end
*/


  PLL pll(
	.inclk0(CLK),
	.c0(spi_clk_temp) );
	
// Synchronizer for SPI_CLK_1M (avoid metastability crossing domains)
    reg sclk_sync_0, sclk_sync_1, sclk_sync_2;
    always @(posedge CLK) begin
        sclk_sync_0 <= spi_clk_temp;
        sclk_sync_1 <= sclk_sync_0;
        sclk_sync_2 <= sclk_sync_1;
    end
	 
  
    always @(posedge CLK) begin
        if (RST || spi_clk_rst) begin
            spi_clk <= 0;
				end else begin
				spi_clk = sclk_sync_2; end
				end
 assign SCLK = spi_clk;
	 
    // Bit counter
    always @(posedge CLK) begin
        if (RST || spi_clk_rst) begin
            bit_cnt <= 0;
        end else if (second_edge_en) begin
            bit_cnt <= bit_cnt + 1;
        end
    end

    // SPI master addressing
    always @(posedge CLK) begin
        if (RST) begin
            addr_reg <= 0;
        end else if (load_data) begin
            addr_reg <= DIN_ADDR;
        end
    end

    // Chip select generation
	 
	 genvar i;
    generate
        if (SLAVE_COUNT == 1) begin
            assign CS_N = chip_select_n;
        end else begin

            for (i = 0; i < SLAVE_COUNT; i = i + 1) begin : chepsil
                assign CS_N[i] = (addr_reg == i) ? chip_select_n : 1'b1;
            end
        end
    endgenerate

    // DIN LAST register
    always @(posedge CLK) begin
        if (RST) begin
            din_last_reg_n <= 0;
        end else if (load_data) begin
            din_last_reg_n <= ~DIN_LAST;
        end
    end

    // MISO sample register
    always @(posedge CLK) begin
        if (first_edge_en) begin
            miso_reg <= MISO;
        end
    end

    // Data shift register
    always @(posedge CLK) begin
        if (load_data) begin
            shreg <= DIN;
        end else if (second_edge_en) begin
            shreg <= {shreg[WORD_SIZE-2:0], miso_reg};
        end
    end

    assign DOUT = shreg;
    assign MOSI = shreg[WORD_SIZE-1];
    
    // Data out valid register
    always @(posedge CLK) begin
        if (RST) begin
            DOUT_VLD <= 0;
        end else begin
            DOUT_VLD <= rx_data_vld;
        end
    end

    // FSM state register
    always @(posedge CLK) begin
        if (RST) begin
            present_state <= idle;
        end else begin
            present_state <= next_state;
        end
    end

    // FSM next state logic
    always @(*) begin
        next_state = present_state;
        
        case (present_state)
            idle: begin
                if (DIN_VLD) begin
                    next_state = first_edge;
                end
            end
            
            first_edge: begin
                if (sys_clk_cnt_max) begin
                    next_state = second_edge;
                end
            end
            
            second_edge: begin
                if (sys_clk_cnt_max) begin
                    if (bit_cnt_max) begin
                        next_state = transmit_end;
                    end else begin
                        next_state = first_edge;
                    end
                end
            end
            
            transmit_end: begin
                if (sys_clk_cnt_max) begin
                    next_state = transmit_gap;
                end
            end
            
            transmit_gap: begin
                if (sys_clk_cnt_max) begin
                    next_state = idle;
                end
            end
            
            default: begin
                next_state = idle;
            end
        endcase
    end

    // FSM output logic
    always @(*) begin
        master_ready = 1'b0;
        chip_select_n = ~din_last_reg_n;
        spi_clk_rst = 1'b1;
        first_edge_en = 1'b0;
        second_edge_en = 1'b0;
        rx_data_vld = 1'b0;
        
        case (present_state)
            idle: begin
                master_ready = 1'b1;
            end
            
            first_edge: begin
                chip_select_n = 1'b0;
                spi_clk_rst = 1'b0;
                first_edge_en = sys_clk_cnt_max;
            end
            
            second_edge: begin
                chip_select_n = 1'b0;
                spi_clk_rst = 1'b0;
                second_edge_en = sys_clk_cnt_max;
            end
            
            transmit_end: begin
                chip_select_n = 1'b0;
                rx_data_vld = sys_clk_cnt_max;
            end
            
            transmit_gap: begin
                // Default outputs are fine
            end
        endcase
    end

endmodule




   