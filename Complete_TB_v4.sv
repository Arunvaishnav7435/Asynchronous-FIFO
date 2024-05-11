//Problem statement : To create SV Testbench to verify a Async. FIFO
//======================================

//fifo interface
interface fifo_if(input bit rclock, input bit wclock);
  logic [7:0] rdata;  
  logic [7:0] wdata;
  logic empty, full, ren, wen, wrst_n, rrst_n;
  
  clocking read_driver_cb @(posedge rclock);//read clocking block @ read clock
    default input #0 output #0; //no clock skew
    input empty, rdata;
    output ren, rrst_n;
  endclocking
  
  clocking read_monitor_cb@(posedge rclock);
    default input #0 output #0;
    input rdata, empty, ren, rrst_n;
  endclocking 
  
  clocking write_driver_cb@(posedge wclock); //@write clock
    default input #0 output #0; //no clock skew
    input full;
    output wen, wrst_n, wdata;
  endclocking
  
  clocking write_monitor_cb@(wclock);
    default input #0 output #0;
    input full, wen, wrst_n, wdata;
  endclocking
  
  //two modports for read and write
  modport read_driver_mp (clocking read_driver_cb);
  modport read_monitor_mp (clocking read_monitor_cb);
      
  modport write_driver_mp (clocking write_driver_cb);
  modport write_monitor_mp (clocking write_monitor_cb);
endinterface

class read_xtn extends uvm_sequence_item;//read transaction
  `uvm_object_utils(read_xtn)  //object factory registration
  
  rand bit ren;
  bit empty;
  bit [7:0] rdata [$];
  
  //read enable should be high most of the time
  constraint READ {ren dist{1:=9, 0:= 1};}
  
  function new(string name = "read_xtn");//constructor
    super.new(name);
  endfunction
  
  function void do_print(uvm_printer printer);//print function
    printer.print_field("read enable", ren, 1, UVM_BIN);
    printer.print_field("empty", empty, 1, UVM_BIN);
    foreach(rdata[i])
      printer.print_field($sformatf("read data[%0d]", i), rdata[i], 8, UVM_HEX);
  endfunction
endclass : read_xtn

class write_xtn extends uvm_sequence_item;//write transaction
  `uvm_object_utils(write_xtn)
  
  bit wen;
  rand bit [7:0] wdata [];
  bit full;
  
  //write data burst size between 1 and 32
  constraint write_data {wdata.size inside{[1:3]};}
  
  function new(string name = "write_xtn");
    super.new(name);
  endfunction
  
  function void do_print(uvm_printer printer);//print function
    printer.print_field("write enable", wen, 1, UVM_BIN);
    printer.print_field("full", full, 1, UVM_BIN);
    foreach(wdata[i])
      printer.print_field($sformatf("write data[%0d]", i), wdata[i], 8, UVM_HEX);
  endfunction
endclass : write_xtn

class write_agent_config extends uvm_object;//to configure write agents
  `uvm_object_utils(write_agent_config)
  
  virtual fifo_if ifw;
  
  bit is_active;
  
  function new(string name = "write_agent_config");
    super.new(name);
  endfunction
endclass : write_agent_config
    
class read_agent_config extends uvm_object;//to configure read agents
  `uvm_object_utils(read_agent_config)
  
  virtual fifo_if ifr;
  
  bit is_active;
  
  function new(string name = "read_agent_config");
    super.new(name);
  endfunction
endclass : read_agent_config

class env_config extends uvm_object;//configuring enviornment
  `uvm_object_utils(env_config)
  
  bit is_active;
  bit has_read_agent = 0;
  bit has_write_agent = 0;
  
  virtual fifo_if write_if;
  virtual fifo_if read_if;
  
  function new(string name = "env_config");
    super.new(name);
  endfunction
endclass : env_config

class write_driver extends uvm_driver#(write_xtn);//write driver
  `uvm_component_utils(write_driver)  //component factory registration
  
  virtual fifo_if.write_driver_mp ifh;//virtual interface to interact with DUT
  write_agent_config cfg;
  
  function new(string name = "write_driver", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db#(write_agent_config)::get(this, "", "write_agent_config", cfg))//getting write agent config object for interface connection
       $fatal("Write Driver ", "Getting virtual interface failed in write driver");
  endfunction
  
  function void connect_phase(uvm_phase phase);
    ifh = cfg.ifw; //assigning interfacce object to local if handle
  endfunction
  
  //reset phase to reset the write and read side together
  task reset_phase(uvm_phase phase);
    ifh.write_driver_cb.wrst_n <= 0; //active low reset
    @ifh.write_driver_cb;
    ifh.write_driver_cb.wrst_n <= 1;
  endtask
  
  task drive_dut;
    req.print();    //printing the generated transaction
    foreach(req.wdata[i])    //write random length of burst data
      begin
        while(ifh.write_driver_cb.full)
          @ifh.write_driver_cb;		//wait for clock edge
        
        @ifh.write_driver_cb;		//wait for clock edge
        ifh.write_driver_cb.wen <= 1;     //write enable high
        ifh.write_driver_cb.wdata <= req.wdata[i];//writing data
      end
    @ifh.write_driver_cb;		//wait for clock edge
    ifh.write_driver_cb.wen <= 0;     //write enable low
  endtask
  
  task run_phase(uvm_phase phase);
    forever begin
    	seq_item_port.get_next_item(req);
      	drive_dut();
    	seq_item_port.item_done();
    end
  endtask
endclass : write_driver

class read_driver extends uvm_driver#(read_xtn); //read driver
  `uvm_component_utils(read_driver)
  
  virtual fifo_if.read_driver_mp ifh;
  
  read_agent_config cfg;
  
  function new(string name = "read_driver", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db#(read_agent_config)::get(this, "", "read_agent_config", cfg))
      $fatal("Read Driver ", "Getting failed in read driver for virtual interface");
  endfunction
  
  function void connect_phase(uvm_phase phase);
    ifh = cfg.ifr;
  endfunction
  
  task reset_phase(uvm_phase phase);
    //reset DUT
    @ifh.read_driver_cb;
    ifh.read_driver_cb.rrst_n <= 0;
    @ifh.read_driver_cb;
    ifh.read_driver_cb.rrst_n <= 1;
  endtask
  
  task drive_dut;
    ifh.read_driver_cb.ren <= 0;//stop reading
    @ifh.read_driver_cb;//wait for 1 clk to write data so that empty goes down
    
    while(!ifh.read_driver_cb.empty)//read until fifo is empty
      begin
        ifh.read_driver_cb.ren <= req.ren;
        @ifh.read_driver_cb;
      end      
  endtask
  
  task run_phase(uvm_phase phase);    
    forever begin
    	seq_item_port.get_next_item(req);//inbuilt tlm port
    	drive_dut;
    	seq_item_port.item_done();
    end
  endtask
endclass : read_driver
    
class write_monitor extends uvm_monitor;//to monitor written data
  `uvm_component_utils(write_monitor)
  
  //TLM
  uvm_analysis_port #(read_xtn) wmp;
  
  //virtual interface
  virtual fifo_if.write_monitor_mp ifh;
  
  //config class for interface
  write_agent_config cfg;
  
  function new(string name = "write_monitor", uvm_component parent);
    super.new(name, parent);
    
    wmp = new("wmp", this);//instantiating tlm port
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db#(write_agent_config)::get(this, "", "write_agent_config", cfg))
      $fatal("Write Monitor ", "Getting IF failed");
  endfunction
  
  function void connect_phase(uvm_phase phase);
    ifh = cfg.ifw;//assigning virtual interface to local IF
  endfunction
  
  task collect_data;
    read_xtn written_data;
    written_data = read_xtn::type_id::create("written_data");
    
    @ifh.write_monitor_cb;
    
    while(ifh.write_monitor_cb.wen)
      begin
        while(ifh.write_monitor_cb.full)
          @ifh.write_monitor_cb;
        
        written_data.rdata.push_back(ifh.write_monitor_cb.wdata);
        @ifh.write_monitor_cb;
        written_data.print;
        if(!ifh.write_monitor_cb.wen)
          begin
            written_data.print;
            wmp.write(written_data);
            @ifh.write_monitor_cb;
          end
      end
  endtask
  
  task run_phase(uvm_phase phase);
    //write monitor logic
    forever
      collect_data;
  endtask
endclass : write_monitor

class read_monitor extends uvm_monitor;//to monitor read side ports
  `uvm_component_utils(read_monitor)
   
  virtual fifo_if.read_monitor_mp ifh;
  
  read_agent_config cfg;
  
  //TLM
  uvm_analysis_port#(read_xtn) rmp;
  
  function new(string name = "read_monitor", uvm_component parent);
    super.new(name, parent);
    
    rmp = new("rmp", this);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db#(read_agent_config)::get(this, "", "read_agent_config", cfg))
      $fatal("Read Monitor ", "Getting read monitor IF failed");
  endfunction
      
  function void connect_phase(uvm_phase phase);
    ifh = cfg.ifr;
  endfunction
  
  task run_phase(uvm_phase phase);
    //forever
    //collect_data
  endtask
endclass : read_monitor
    
class write_sequencer extends uvm_sequencer#(write_xtn);
  //write sequencer
  `uvm_component_utils(write_sequencer)
  
  function new(string name = "write_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction
endclass : write_sequencer
    
class read_sequencer extends uvm_sequencer#(read_xtn);
  //read sequencer
  `uvm_component_utils(read_sequencer)
  
  function new(string name = "read_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction
endclass : read_sequencer

class virtual_sequencer extends uvm_sequencer#(uvm_sequence_item);
  `uvm_component_utils(virtual_sequencer)
  
  read_sequencer rseqrh;
  write_sequencer wseqrh;
  
  function new(string name = "virtual_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction
endclass : virtual_sequencer
  
class write_sequence extends uvm_sequence#(write_xtn);
  `uvm_object_utils(write_sequence)
  
  function new(string name = "write_sequence");
    super.new(name);
  endfunction
  
  task body;
    `uvm_do(req);
  endtask
endclass : write_sequence
    
class read_sequence extends uvm_sequence#(read_xtn);
  `uvm_object_utils(read_sequence)
      
  function new(string name = "read_sequence");
    super.new(name);    
  endfunction
  
  task body;
    `uvm_do(req);
  endtask
endclass : read_sequence
    
class virtual_sequence extends uvm_sequence#(uvm_sequence_item);
  `uvm_object_utils(virtual_sequence)
  
  read_sequence rseqh;
  write_sequence wseqh;
  
  read_sequencer rseqrh;
  write_sequencer wseqrh;
  
  virtual_sequencer vseqrh;
  
  function new(string name = "virtual_sequence");
    super.new(name);
  endfunction
  
  task body;
    //body method of virtual sequence
    
    //m_sequencer points to virtual sequencer of env, now we take that pointer to virtual sequencer of virtual sequence
    assert($cast(vseqrh, m_sequencer)) else
      $error("Virtual Sequence ","Body method casting to virtual sequencer from m_sequencer failed");
      
    //local sequencer pointing sequencer of  virtual sequencer
    rseqrh = vseqrh.rseqrh;
    wseqrh = vseqrh.wseqrh;
    
    //instantiating sequences
    rseqh = read_sequence::type_id::create("rseqh");
    wseqh = write_sequence::type_id::create("wseqh");
    
    //starting individual sequences to sequencers present in virtual sequence
    rseqh.start(rseqrh);
    wseqh.start(wseqrh);
  endtask
endclass : virtual_sequence
    
class write_agent extends uvm_agent;
  //write agent
	`uvm_component_utils(write_agent)
    
  write_driver drvh;  //driver handle
  write_monitor monh; //monitor handle
  write_sequencer seqrh; //sequencer handle
  
  write_agent_config cfg; //configuration handle
  
	function new(string name = "write_agent", uvm_component parent);
    	super.new(name, parent);
	endfunction
  
  function void connect_phase(uvm_phase phase);
    //connecting tlm port of driver and sequencer
    drvh.seq_item_port.connect(seqrh.seq_item_export);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db#(write_agent_config)::get(this, "", "write_agent_config", cfg))
      $fatal("Write Agent", "Failed to get write agent config object");
    
    //monitor instantiation
    monh = write_monitor::type_id::create("monh", this);
    
    if(cfg.is_active) //if active then create driver and sequencer
      begin
        drvh = write_driver::type_id::create("drvh", this);
        seqrh = write_sequencer::type_id::create("seqrh", this);
      end
  endfunction
endclass : write_agent
    
class read_agent extends uvm_agent;
  `uvm_component_utils(read_agent)
  
  read_driver drvh;
  read_monitor monh;
  read_sequencer seqrh;
  
  read_agent_config cfg;
  
  function new(string name = "read_agent", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void connect_phase(uvm_phase phase);
    //connect tlm ports
    drvh.seq_item_port.connect(seqrh.seq_item_export);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db#(read_agent_config)::get(this, "", "read_agent_config", cfg))
      $fatal("Read Agent", "Getting read agent config failed");
    
    monh = read_monitor::type_id::create("monh", this);
    
    if(cfg.is_active)
      begin
        drvh = read_driver::type_id::create("drvh", this);
        seqrh = read_sequencer::type_id::create("seqrh", this);
      end
  endfunction
endclass : read_agent

class fifo_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(fifo_scoreboard)
 
  //tlm port
  uvm_tlm_analysis_fifo #(read_xtn) wmp;
  uvm_tlm_analysis_fifo #(read_xtn) rmp;
  
  read_xtn written_data;
  read_xtn read_data;
  
  //coverage
  
  function new(string name = "fifo_scoreboard", uvm_component parent);
    super.new(name, parent);
    
    wmp = new("wmp", this);
    rmp = new("rmp", this);
    
    //instantiate coverage
  endfunction
  
  task run_phase(uvm_phase phase);
    //forkjoin
    //read
    //write
  endtask
endclass : fifo_scoreboard
    
class env extends uvm_env;
  //environment class
  `uvm_component_utils(env);
  
  read_agent ragent;		//read agent
  write_agent wagent;   //write agent
  
  env_config cfgh;
  read_agent_config rcfgh;
  write_agent_config wcfgh;
  
  //virtual sequencer
  virtual_sequencer virtual_seqrh;
  
  //scoreboard
  fifo_scoreboard sb;
  
  function new(string name = "env", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db#(env_config)::get(this, "", "env_config", cfgh))
      $fatal("Base Test ", "Getting env config failed");
      
    //scoreboard instance
    sb = fifo_scoreboard::type_id::create("sb", this);
    
    //virtual sequencer instance
    virtual_seqrh = virtual_sequencer::type_id::create("virtual_seqrh", this);
    
    
    if(cfgh.has_read_agent) //if read config is not null that means the read agent config is created and we need read agent
      begin
    	ragent = read_agent::type_id::create("ragent", this);
        
        rcfgh = read_agent_config::type_id::create("rcfgh");
        
     	rcfgh.is_active = cfgh.is_active;
        
        rcfgh.ifr = cfgh.read_if;
        
        uvm_config_db#(read_agent_config)::set(this, "*", "read_agent_config", rcfgh);//set read agent config to be used in agent
      end
    
    if(cfgh.has_write_agent)//write agent config is created means we need write agent
      begin
    	wagent = write_agent::type_id::create("wagent", this);
        wcfgh = write_agent_config::type_id::create("wcfgh");
        wcfgh.is_active = cfgh.is_active;
        
        wcfgh.ifw = cfgh.write_if;
        
        uvm_config_db#(write_agent_config)::set(this, "*", "write_agent_config", wcfgh);
      end
  endfunction
  
  function void connect_phase(uvm_phase phase);
    //connect write monitor with scoreboard
    wagent.monh.wmp.connect(sb.wmp.analysis_export);
    
    //connect read monitor with scoreboard
    ragent.monh.rmp.connect(sb.rmp.analysis_export);
    
    //connect sequencer with sequencer of virtual sequencer
    virtual_seqrh.wseqrh = wagent.seqrh;
    virtual_seqrh.rseqrh = ragent.seqrh;
    
  endfunction
endclass : env
    
class base_test extends uvm_test;
  `uvm_component_utils(base_test);
  
  env enviornment;
  virtual_sequence virtual_seqh;
  
  env_config cfgh;
  
  bit has_read = 1;//1 if we need read side
  bit has_write = 1; //0 if we do not need write side
  bit read_active_agent = 1; //is read agent active
  bit write_active_agent = 1; //is write agent active
  
  //virtual sequence
  
  function new(string name = "base_test", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  	
    cfgh = env_config::type_id::create("cfgh");
    
    if(has_read)
      begin //if read is required then create read agent config
        cfgh.has_read_agent = 1;
        
        if(read_active_agent)
      		cfgh.is_active = 1;//assign is active
        else
          cfgh.is_active = 0;
      end
    
    if(has_write)
      begin
        cfgh.has_write_agent = 1;
        if(write_active_agent)
          cfgh.is_active = 1;
        else
          cfgh.is_active = 0;
      end
    
    //getting read and write interface which is set in TB module
    if(!uvm_config_db#(virtual fifo_if)::get(this, "", "ifr", cfgh .read_if))
      `uvm_fatal("Test", "Getting virtual read IF config failed")
    
      if(!uvm_config_db#(virtual fifo_if)::get(this, "", "ifw", cfgh.write_if))
        `uvm_fatal("Test", "Getting virtual write IF config failed")
        
    //set env config everywhere
    uvm_config_db #(env_config)::set(this, "*", "env_config", cfgh);
    
    enviornment = env::type_id::create("enviornment", this);
  endfunction
  
  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction
  
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);//raising objection 
    
    virtual_seqh = virtual_sequence::type_id::create("virtual_seqh");//instantiating virtual sequence
    virtual_seqh.start(enviornment.virtual_seqrh);//starting v sequence on v sequencer
    
    phase.drop_objection(this);//dropping objection
  endtask
endclass : base_test
    
module tb;
  import uvm_pkg::*;
  
  bit read_clock, write_clock;
  
  always #5 write_clock =~ write_clock;
  always #7.5 read_clock =~ read_clock;
  
  fifo_if ifw(read_clock, write_clock);
  fifo_if ifr(read_clock, write_clock);
  
  async_fifo #(8, 16) DUT(ifr.rdata, ifr.empty, ifw.full, write_clock, read_clock, ifr.ren, ifw.wen, ifw.wrst_n, ifr.rrst_n, ifw.wdata);
  
  initial begin
    {read_clock, write_clock} = 0;
    
    //setting the interface
    uvm_config_db #(virtual fifo_if)::set(null, "*", "ifr", ifr);
    uvm_config_db #(virtual fifo_if)::set(null, "*", "ifw", ifw);
    
    run_test("base_test");//running test class
    
    //regression testing
    
    
    //Run option: +UVM_TESTNAME=base_test
    //Run option: +ntb_random_seed_automatic
  end
endmodule
    
