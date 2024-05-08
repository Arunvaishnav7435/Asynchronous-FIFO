//Problem statement : To create SV Testbench to verify a Async. FIFO
//======================================

//fifo interface
interface fifo_if(input bit rclock, input bit wclock);
  logic [7:0] rdata;  
  logic [7:0] wdata;
  logic empty, full, ren, wen, wrst_n, rrst_n;
  
  clocking read_cb @(posedge rclock);//read clocking block @ read clock
    default input #0 output #0; //no clock skew
    input rdata, empty;			//DUT outputs are TB inputs
    output ren, rrst_n;
  endclocking
  
  clocking write_cb@(posedge wclock); //@write clock
    default input #0 output #0; //no clock skew
    input full;
    output wen, wrst_n, wdata;
  endclocking
  
  //two modports for read and write
  modport read_mp (clocking read_cb);
  modport write_mp (clocking write_cb);
endinterface

class read_xtn extends uvm_sequence_item;//read transaction
  `uvm_object_utils(read_xtn)  //object factory registration
  
  bit ren;
  logic empty;
  logic [7:0] rdata [$];
  
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
  rand logic [7:0] wdata;
  logic full;
  
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
  
  bit is_active;
  
  function new(string name = "write_agent_config");
    super.new(name);
  endfunction
endclass : write_agent_config
    
class read_agent_config extends uvm_object;//to configure read agents
  `uvm_object_utils(read_agent_config)
  
  bit is_active;
  
  function new(string name = "read_agent_config");
    super.new(name);
  endfunction
endclass : read_agent_config


class env_config extends uvm_object;//configuring enviornment
  `uvm_object_utils(env_config)
  
  bit is_active;
  virtual fifo_if write_if;
  virtual fifo_if read_if;
  
  read_agent_config ragent_config;
  write_agent_config wagent_config;
  
  function new(string name = "env_config");
    super.new(name);
  endfunction
endclass : env_config

class write_driver extends uvm_driver#(write_xtn);//write driver
  `uvm_component_utils(write_driver)  //component factory registration
  
  virtual fifo_if.write_mp ifh;//virtual interface to interact with DUT
  
  //TLM
  
  
  function new(string name = "write_driver", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    //if(!uvm_config_db#(virtual fifo_if)::get(this, "", "ifr")
  endfunction
endclass : write_driver

class read_driver extends uvm_driver#(read_xtn); //read driver
  `uvm_component_utils(read_driver)
  
  //TLM
  
  function new(string name = "read_driver", uvm_component parent);
    super.new(name, parent);
  endfunction
endclass : read_driver
    
class write_monitor extends uvm_monitor;//to monitor written data
  `uvm_component_utils(write_monitor)
  
  //TLM
  
  function new(string name = "write_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction
endclass : write_monitor

class read_monitor extends uvm_monitor;//to monitor read side ports
  `uvm_component_utils(read_monitor)
  
  //TLM
  
  function new(string name = "read_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction
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
    //connecting tlm ports
    
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

class env extends uvm_env;
  //environment class
  `uvm_component_utils(env);
  
  read_agent ragent;		//read agent
  write_agent wagent;   //write agent
  
  env_config cfgh;
  
  //virtual sequencer
  
  function new(string name = "env", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db#(env_config)::get(this, "", "env_config", cfgh))
      $fatal("Base Test ", "Getting env config failed");
      
    
    if(cfgh.ragent_config != null) //if read config is not null that means the read agent config is created and we need read agent
      begin
    	ragent = read_agent::type_id::create("ragent", this);
        uvm_config_db#(read_agent_config)::set(this, "*", "read_agent_config", cfgh.ragent_config);//set read agent config to be used in agent
      end
    
    if(cfgh.wagent_config != null)//write agent config is created means we need write agent
      begin
    	wagent = write_agent::type_id::create("wagent", this);
        uvm_config_db#(write_agent_config)::set(this, "*", "write_agent_config", cfgh.wagent_config);
      end
    
  endfunction
endclass : env
    
class base_test extends uvm_test;
  `uvm_component_utils(base_test);
  
  env enviornment;
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
        cfgh.ragent_config =read_agent_config::type_id::create("ragent_config");
        if(read_active_agent)
      		cfgh.ragent_config.is_active = 1;//assign is active
        else
          cfgh.ragent_config.is_active = 0;
      end
    
    if(has_write)
      begin
        cfgh.wagent_config=write_agent_config::type_id::create("wagent_config");
        if(write_active_agent)
          cfgh.wagent_config.is_active = 1;
        else
          cfgh.wagent_config.is_active = 1;
      end
    
    if(!uvm_config_db#(virtual fifo_if)::get(this, "", "ifr", cfgh.read_if))
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
    
    uvm_config_db #(virtual fifo_if)::set(null, "*", "ifr", ifr);
    uvm_config_db #(virtual fifo_if)::set(null, "*", "ifw", ifw);
    
    run_test("base_test");
  end
endmodule
    
