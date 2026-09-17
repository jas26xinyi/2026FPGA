`timescale 1ns/1ps
// Standalone, race-free FSM verification. Inputs change only at falling edges.
module tb_lock_controller_fsm;
    reg clk=0, rst=1, flash_init_done=0, flash_fault=0;
    reg sw1_event=0, admin_event=0, alarm_clear_event=0, temporary_event=0;
    reg key_valid=0, save_done=0, save_success=0, temporary_valid=0;
    reg [3:0] key_code=0;
    reg [15:0] stored_password=16'h1234, temporary_password=0;
    reg [7:0] scenario=0;
    reg test_pass=0;
    wire save_request, capture_start, unlocked, alarm_active, display_fault;
    wire [15:0] save_password, entry_digits;
    wire [3:0] state;
    wire [2:0] entry_count, error_count;
    wire [3:0] next_state=dut.next_state;
    wire [10:0] timer_count=dut.timer_count;
    wire activity=dut.activity;
    integer checks=0, capture_pulses=0, save_pulses=0;
    integer segfile, eventfile, covfile, start_ns, n, s, a, b;
    integer visits[0:8];
    integer edges[0:8][0:8];
    integer reset_hits[0:8];
    reg [3:0] previous_state=0;
    reg previous_rst=1, previous_capture=0, previous_save=0;
    string segment_name;
    always #5 clk=~clk;
    lock_controller #(.CLOCK_HZ(1000), .LOCK_TIMEOUT_S(1),
        .OPEN_TIMEOUT_S(2), .ERROR_DISPLAY_MS(20)) dut (.*);

    task check(input bit ok, input string message);
        begin
            checks=checks+1;
            if (!ok) $fatal(1,"FAIL @%0t scenario=%0d state=%0d: %s",$time,scenario,state,message);
        end
    endtask
    task idle(input integer cycles);
        repeat(cycles) @(negedge clk);
    endtask
    task begin_segment(input integer id, input string name);
        begin scenario=id; segment_name=name; start_ns=$time; idle(3); end
    endtask
    task end_segment;
        begin idle(4); $fdisplay(segfile,"%0d,%s,%0d,%0d",scenario,segment_name,start_ns,$time); end
    endtask
    task events(input bit sw, input bit adm, input bit clr, input bit tmp);
        begin
            @(negedge clk);
            sw1_event=sw; admin_event=adm; alarm_clear_event=clr; temporary_event=tmp;
            @(negedge clk);
            sw1_event=0; admin_event=0; alarm_clear_event=0; temporary_event=0;
        end
    endtask
    task key(input [3:0] code);
        begin @(negedge clk); key_code=code; key_valid=1;
            @(negedge clk); key_valid=0; end
    endtask
    task digits(input [15:0] value);
        begin key(value[15:12]); key(value[11:8]); key(value[7:4]); key(value[3:0]); end
    endtask
    task reset_wait;
        begin
            @(negedge clk); rst=1; flash_init_done=0; flash_fault=0;
            sw1_event=0; admin_event=0; alarm_clear_event=0; temporary_event=0;
            key_valid=0; save_done=0; save_success=0; temporary_valid=0;
            stored_password=16'h1234; temporary_password=0;
            idle(3); rst=0; idle(2); flash_init_done=1; idle(2);
            check(state==1,"reset and Flash initialization -> WAIT");
        end
    endtask
    task unlock_default;
        begin events(1,0,0,0); digits(16'h1234); key(4'hA); check(state==4,"default unlock"); end
    endtask
    task wrong;
        begin digits(16'h1111); key(4'hA); end
    endtask
    task wait_user;
        begin
            while(state==3) @(negedge clk);
            check(state==2 && entry_count==0 && entry_digits==0,"ERROR expires -> fresh USER");
        end
    endtask
    task until_timer(input integer value);
        begin
            while(timer_count<value) @(negedge clk);
            check(timer_count==value,"exact natural timer boundary");
        end
    endtask

    // Observe after nonblocking assignments; count genuine transitions and pulses.
    always @(posedge clk) begin
        #1;
        if(state<=8) visits[state]=visits[state]+1;
        if(rst && !previous_rst && previous_state<=8) reset_hits[previous_state]=reset_hits[previous_state]+1;
        if(!rst && !previous_rst && state<=8 && previous_state<=8 && state!=previous_state) begin
            edges[previous_state][state]=edges[previous_state][state]+1;
            $fdisplay(eventfile,"%0d,%0d,%0d,%0d,%0d,%0d,%0d",$time,scenario,previous_state,state,error_count,save_request,capture_start);
        end
        if(save_request) save_pulses=save_pulses+1;
        if(capture_start) capture_pulses=capture_pulses+1;
        if(!rst) begin
            check(unlocked==(state==4) && alarm_active==(state==7),"Moore outputs");
            check(!(save_request && previous_save),"save_request lasts exactly one cycle");
            check(!(capture_start && previous_capture),"capture_start lasts exactly one cycle");
            if(save_request) check(state==6 && previous_state==5,"save pulse only on ADMIN -> SAVE");
            if(capture_start) check(state==7 && previous_state==2 && error_count==4,"capture only on fourth failure");
        end
        previous_state=state; previous_rst=rst; previous_capture=capture_start; previous_save=save_request;
    end

    initial begin
        segfile=$fopen("segments.csv","w"); eventfile=$fopen("transitions.csv","w"); covfile=$fopen("coverage.txt","w");
        $fdisplay(segfile,"id,name,start_ns,end_ns");
        $fdisplay(eventfile,"time_ns,scenario,from,to,error_count,save_request,capture_start");
        for(a=0;a<9;a=a+1) begin visits[a]=0; reset_hits[a]=0; for(b=0;b<9;b=b+1) edges[a][b]=0; end
        begin_segment(1,"boot_gate"); idle(3); rst=0;
        events(1,1,1,1); key(4'h1); check(state==0 && entry_count==0,"BOOT ignores user events until Flash ready");
        flash_init_done=1; idle(2); check(state==1,"BOOT -> WAIT"); end_segment;

        begin_segment(2,"entry_edit_unlock_close"); events(1,0,0,0);
        key(4'hB); check(entry_count==0,"backspace on empty");
        key(1); key(2); key(4'hA); check(state==2 && error_count==0,"incomplete A ignored");
        key(9); key(4'hB); check(entry_digits==16'h0012 && entry_count==2,"backspace removes last digit");
        key(3); key(4); key(8); key(4'hD);
        check(entry_digits==16'h1234 && entry_count==4,"overflow digit and D do not change buffer");
        key(4'hA); check(unlocked && error_count==0,"correct permanent password");
        key(4'hA); check(state==1 && !unlocked && entry_count==0,"manual close"); end_segment;

        begin_segment(3,"user_cancel_failure_history"); events(1,0,0,0); wrong; wait_user;
        key(2); key(4'hC); check(state==1 && error_count==1 && entry_count==0,"cancel clears entry but not error history");
        events(1,0,0,0); check(error_count==1,"SW1 does not reset errors"); key(4'hC); end_segment;

        begin_segment(4,"user_timeout"); events(1,0,0,0); key(1); until_timer(998);
        check(state==2,"USER remains before threshold"); idle(1); check(timer_count==999 && state==2,"last USER cycle");
        idle(1); check(state==1 && timer_count==0 && entry_count==0,"1000 inactive cycles -> WAIT"); end_segment;

        begin_segment(5,"user_boundary_activity"); events(1,0,0,0); key(1); until_timer(998);
        key(2); check(state==2 && timer_count==0 && entry_digits==16'h0012,"digit at timer 999 wins over timeout");
        key(4'hD); check(timer_count>0 && entry_count==2,"D is not activity"); key(4'hC); end_segment;

        begin_segment(6,"admin_edit_cancel"); events(0,1,0,0); key(5); key(4'hA);
        check(state==5 && !save_request,"incomplete admin A ignored"); key(9); key(4'hB); key(6);
        check(entry_digits==16'h0056,"admin edit buffer"); key(4'hC);
        check(state==1 && entry_count==0 && !save_request,"admin cancel does not save"); end_segment;

        begin_segment(7,"admin_timeout"); events(0,1,0,0); key(5); until_timer(999);
        idle(1); check(state==1 && !save_request,"admin timeout -> WAIT without save"); end_segment;

        begin_segment(8,"save_success_new_password"); events(0,1,0,0); digits(16'h5678); key(4'hA);
        check(state==6 && save_request && save_password==16'h5678,"single-cycle save request");
        idle(3); events(1,1,1,1); key(4'hC);
        check(state==6 && !save_request && save_password==16'h5678,"SAVE ignores events and waits for response");
        @(negedge clk); save_done=1; save_success=1; stored_password=16'h5678;
        @(negedge clk); save_done=0; save_success=0;
        check(state==1 && !display_fault,"save success response");
        events(1,0,0,0); digits(16'h5678); key(4'hA); check(unlocked,"new stored password used"); key(4'hA); end_segment;

        begin_segment(9,"save_failure_flash_priority"); events(0,1,0,0); digits(16'h9090); key(4'hA);
        @(negedge clk); save_done=1; save_success=0;
        @(negedge clk); save_done=0;
        check(state==1 && display_fault && stored_password==16'h5678,"failed save retains supplied stored password");
        flash_fault=1; events(1,0,0,0); check(display_fault,"flash_fault wins over event clearing");
        flash_fault=0; events(0,1,0,0); check(!display_fault && state==2,"event clears fault but USER ignores admin transition");
        digits(16'h5678); key(4'hA); check(unlocked,"old permanent password survives failure"); key(4'hA); end_segment;

        reset_wait;
        begin_segment(10,"first_three_failures"); events(1,0,0,0);
        for(n=1;n<=3;n=n+1) begin wrong; check(state==3 && error_count==n,"first three failures -> ERROR");
            key(4'hC); check(state==3,"ERROR ignores cancel"); wait_user; end
        end_segment;
        begin_segment(11,"fourth_failure_alarm_block"); wrong;
        check(state==7 && alarm_active && capture_start && error_count==4,"fourth failure -> ALARM and capture");
        idle(3); events(1,1,0,1); key(4'hA); key(4'hC); key(2); idle(6);
        check(state==7 && !capture_start,"ALARM blocks SW1/admin/temp/keypad and does not retrigger"); end_segment;
        begin_segment(12,"alarm_clear_retry_success"); events(1,1,1,1);
        check(state==2 && error_count==0 && entry_count==0 && !alarm_active,"KEY2 clears into fresh USER even with other events");
        wrong; check(state==3 && error_count==1,"post-clear error is Err1"); wait_user;
        digits(16'h1234); key(4'hA); check(state==4 && error_count==0,"success clears failure history"); end_segment;

        begin_segment(13,"open_admin_save"); events(0,1,0,0); check(state==5 && !unlocked,"OPEN -> ADMIN closes lock");
        digits(16'h1234); key(4'hA); idle(3);
        @(negedge clk); save_done=1; save_success=1;
        @(negedge clk); save_done=0; save_success=0;
        check(state==1 && !display_fault,"successful admin save -> WAIT"); end_segment;

        begin_segment(14,"open_timeout"); unlock_default; until_timer(1999);
        check(unlocked,"OPEN persists through timer 1999"); idle(1);
        check(state==1 && !unlocked && timer_count==0,"2000 cycles -> automatic close"); end_segment;

        begin_segment(15,"open_deadline_priority"); unlock_default; until_timer(1998);
        @(negedge clk); admin_event=1; key_valid=1; key_code=1;
        @(negedge clk); admin_event=0; key_valid=0;
        check(state==1 && !unlocked,"OPEN timeout wins over digit activity and admin at deadline");
        unlock_default;
        @(negedge clk); admin_event=1; key_valid=1; key_code=4'hA;
        @(negedge clk); admin_event=0; key_valid=0;
        check(state==1,"OPEN manual A close wins over admin"); end_segment;

        begin_segment(16,"wait_event_priority"); temporary_password=16'h2468; temporary_valid=1;
        events(1,1,0,1); check(state==8,"WAIT temp > admin > SW1"); key(4'hC);
        events(1,1,0,0); check(state==5,"WAIT admin > SW1"); key(4'hC);
        events(1,0,0,0); check(state==2,"WAIT SW1 entry"); key(4'hC); end_segment;

        begin_segment(17,"temp_regenerate_priority"); events(0,0,0,1); idle(8);
        @(negedge clk); temporary_password=16'h1357; temporary_event=1; sw1_event=1; key_valid=1; key_code=4'hC;
        @(negedge clk); temporary_event=0; sw1_event=0; key_valid=0;
        check(state==8 && timer_count==0,"TEMP regeneration wins over SW1/C and resets display timer");
        events(1,0,0,0); check(state==2,"TEMP -> USER by SW1");
        digits(16'h1357); key(4'hA); check(unlocked,"current temporary password unlocks"); key(4'hA); end_segment;

        begin_segment(18,"temp_confirm_exit"); events(0,0,0,1); key(4'hA); check(state==1,"TEMP A -> WAIT"); end_segment;
        begin_segment(19,"temp_cancel_exit"); events(0,0,0,1); key(4'hC); check(state==1,"TEMP C -> WAIT"); end_segment;
        begin_segment(20,"temp_timeout"); events(0,0,0,1); until_timer(999); idle(1);
        check(state==1,"TEMP 1000 cycles -> WAIT"); end_segment;

        begin_segment(21,"temp_replacement_valid_gate"); events(0,0,0,1); temporary_password=16'h9876;
        events(0,0,0,1); events(1,0,0,0); digits(16'h1357); key(4'hA);
        check(state==3,"replaced old temporary password rejected"); wait_user;
        digits(16'h9876); key(4'hA); check(unlocked,"replacement temporary password accepted"); key(4'hA);
        temporary_valid=0; events(1,0,0,0); digits(16'h9876); key(4'hA);
        check(state==3,"matching value with temporary_valid=0 rejected"); wait_user;
        digits(16'h1234); key(4'hA); check(unlocked,"permanent password valid with temporary invalid"); key(4'hA); end_segment;

        // Reset from every legal state. No forcing of timer/entry is used.
        for(s=0;s<9;s=s+1) begin
            reset_wait;
            case(s)
                0: begin @(negedge clk); rst=1; flash_init_done=0; idle(2); rst=0; idle(2); end
                1: idle(2);
                2: events(1,0,0,0);
                3: begin events(1,0,0,0); wrong; end
                4: unlock_default;
                5: events(0,1,0,0);
                6: begin events(0,1,0,0); digits(16'h4321); key(4'hA); end
                7: begin events(1,0,0,0); for(n=0;n<3;n=n+1) begin wrong; wait_user; end wrong; end
                8: begin temporary_password=16'h2468; temporary_valid=1; events(0,0,0,1); end
            endcase
            check(state==s,"reset prerequisite state");
            begin_segment(22+s,$sformatf("reset_from_%0d",s));
            @(negedge clk); rst=1; flash_init_done=0; idle(2);
            check(state==0 && entry_count==0 && error_count==0 && !save_request && !capture_start && !display_fault,"reset clears controller registers");
            rst=0; idle(3); check(state==0,"BOOT waits again after reset");
            flash_init_done=1; idle(2); check(state==1,"Flash ready completes restart"); end_segment;
        end

        begin_segment(31,"illegal_state_recovery");
        @(negedge clk); flash_init_done=0; force dut.state=4'hF; idle(1); release dut.state;
        idle(1); check(state==0 && !unlocked && !alarm_active,"illegal encoding defaults to BOOT");
        flash_init_done=1; idle(2); check(state==1,"illegal recovery -> initialized WAIT"); end_segment;

        for(a=0;a<9;a=a+1) begin
            check(visits[a]>0 && reset_hits[a]>0,"all states visited and reset-tested");
            $fdisplay(covfile,"STATE %0d cycles=%0d resets=%0d",a,visits[a],reset_hits[a]);
            for(b=0;b<9;b=b+1) if(edges[a][b]>0) $fdisplay(covfile,"EDGE %0d -> %0d count=%0d",a,b,edges[a][b]);
        end
        check(edges[0][1]>0 && edges[1][2]>0 && edges[1][5]>0 && edges[1][8]>0 &&
            edges[2][1]>0 && edges[2][3]>0 && edges[2][4]>0 && edges[2][7]>0 && edges[3][2]>0 &&
            edges[4][1]>0 && edges[4][5]>0 && edges[5][1]>0 && edges[5][6]>0 &&
            edges[6][1]>0 && edges[7][2]>0 && edges[8][1]>0 && edges[8][2]>0,"all 17 legal non-self FSM edges");
        $fdisplay(covfile,"PASS checks=%0d save_pulses=%0d capture_pulses=%0d legal_edges=17/17 states=9/9 resets=9/9",checks,save_pulses,capture_pulses);
        $fclose(segfile); $fclose(eventfile); $fclose(covfile);
        test_pass=1; idle(3); $display("PASS tb_lock_controller_fsm checks=%0d",checks); $finish;
    end
    initial begin #1000000; $fatal(1,"Watchdog timeout"); end
endmodule
