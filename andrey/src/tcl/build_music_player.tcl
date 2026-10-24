# Build the keyboard-controlled player as a separate project.
# This keeps the existing audio synthesizer project intact.
set src_dir [file normalize [file join [file dirname [file normalize [info script]] ] ..]]
set repo_root [file dirname $src_dir]
set project_dir [file join $repo_root vivado_music_player]

create_project -force player_music $project_dir -part xc7a100tcsg324-1
set_property target_language Verilog [current_project]

add_files -norecurse [list \
    [file join $src_dir rtl ps2_receiver.sv] \
    [file join $src_dir rtl player_controller.sv] \
    [file join $src_dir rtl player_top.sv] \
    [file join $src_dir rtl music_timer.v] \
    [file join $src_dir rtl music_renderer.v] \
    [file join $src_dir rtl music_sevenseg.v] \
    [file join $src_dir rtl vga_adapter_timing.v] \
    [file join $src_dir ipcores vga_clk40.xci]]
add_files -fileset constrs_1 -norecurse [file join $src_dir xdc nexys_a7_player.xdc]
set_property top player_top [get_filesets sources_1]
generate_target all [get_ips vga_clk40]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {![string match "*Complete!" [get_property STATUS [get_runs synth_1]]]} {
    error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}

launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {![string match "*Complete!" [get_property STATUS [get_runs impl_1]]]} {
    error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
}
puts "Built bitstream: [file join $project_dir player_music.runs impl_1 player_top.bit]"
