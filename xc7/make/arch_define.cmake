function(ADD_XC7_ARCH_DEFINE)
  set(options)
  set(oneValueArgs ARCH YOSYS_SYNTH_SCRIPT YOSYS_CONV_SCRIPT)
  set(multiValueArgs)
  cmake_parse_arguments(
    ADD_XC7_ARCH_DEFINE
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN}
  )

  set(ARCH ${ADD_XC7_ARCH_DEFINE_ARCH})
  set(YOSYS_SYNTH_SCRIPT ${ADD_XC7_ARCH_DEFINE_YOSYS_SYNTH_SCRIPT})
  set(YOSYS_CONV_SCRIPT ${ADD_XC7_ARCH_DEFINE_YOSYS_CONV_SCRIPT})

  define_arch(
    ARCH ${ARCH}
    YOSYS_SYNTH_SCRIPT ${YOSYS_SYNTH_SCRIPT}
    YOSYS_CONV_SCRIPT ${YOSYS_CONV_SCRIPT}
    DEVICE_FULL_TEMPLATE \${DEVICE}-\${PACKAGE}
    CELLS_SIM ${YOSYS_DATADIR}/xilinx/cells_sim.v ${symbiflow-arch-defs_SOURCE_DIR}/xc7/techmap/cells_sim.v
    VPR_ARCH_ARGS "\
      --clock_modeling route \
      --place_delay_model delta_override \
      --router_lookahead connection_box_map \
      --disable_check_route on \
      --strict_checks off \
      --clustering_pin_feasibility_filter off \
      --allow_dangling_combinational_nodes on \
      --disable_errors check_unbuffered_edges:check_route \
      --congested_routing_iteration_threshold 0.8 \
      --incremental_reroute_delay_ripup off \
      --base_cost_type delay_normalized_length_bounded \
      --astar_fac 1.2 \
      --bb_factor 10 \
      --initial_pres_fac 4.0 \
      --disable_check_rr_graph on \
      --suppress_warnings \${OUT_NOISY_WARNINGS},sum_pin_class:check_unbuffered_edges:load_rr_indexed_data_T_values:check_rr_node:trans_per_R"
    RR_PATCH_TOOL
      ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_routing_import.py
    RR_PATCH_CMD "${CMAKE_COMMAND} -E env \
    PYTHONPATH=${PRJXRAY_DIR}:${symbiflow-arch-defs_SOURCE_DIR}/utils:${symbiflow-arch-defs_BINARY_DIR}/utils \
        \${PYTHON3} \${RR_PATCH_TOOL} \
        --db_root ${PRJXRAY_DB_DIR}/${ARCH} \
        --read_rr_graph \${OUT_RRXML_VIRT} \
        --write_rr_graph \${OUT_RRXML_REAL} \
        --write_rr_node_map \${OUT_RRXML_REAL}.node_map.pickle
        "
    PLACE_TOOL
      ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_create_ioplace.py
    PLACE_TOOL_CMD "${CMAKE_COMMAND} -E env \
    PYTHONPATH=${symbiflow-arch-defs_SOURCE_DIR}/utils \
    \${PYTHON3} \${PLACE_TOOL} \
        --map \${PINMAP} \
        --iostandard_defs \${OUT_EBLIF}.iostandard.json \
        --blif \${OUT_EBLIF} \
        --pcf \${INPUT_IO_FILE} \
        --net \${OUT_NET}"
    PLACE_CONSTR_TOOL
      ${symbiflow-arch-defs_SOURCE_DIR}/xc7/utils/prjxray_create_place_constraints.py
    PLACE_CONSTR_TOOL_CMD "${CMAKE_COMMAND} -E env \
    PYTHONPATH=${symbiflow-arch-defs_SOURCE_DIR}/utils \
    \${PYTHON3} \${PLACE_CONSTR_TOOL} \
        --net \${OUT_NET} \
        --arch \${DEVICE_MERGED_FILE_LOCATION} \
        --input /dev/stdin \
        --output /dev/stdout \
        \${PLACE_CONSTR_TOOL_EXTRA_ARGS}"
    BITSTREAM_EXTENSION frames
    BIN_EXTENSION bit
    FASM_TO_BIT ${PRJXRAY_DIR}/utils/fasm2frames.py
    FASM_TO_BIT_CMD "${CMAKE_COMMAND} -E env \
    PYTHONPATH=${symbiflow-arch-defs_BINARY_DIR}/env/conda/lib/python3.7/site-packages:${PRJXRAY_DIR}:${PRJXRAY_DIR}/third_party/fasm \
    \${PYTHON3} \${FASM_TO_BIT} \
        --db-root ${PRJXRAY_DB_DIR}/${ARCH} \
        --sparse \
        --emit_pudc_b_pullup \
        \${FASM_TO_BIT_EXTRA_ARGS} \
    \${OUT_FASM} \${OUT_BITSTREAM}"
    BIT_TO_BIN xc7frames2bit
    BIT_TO_BIN_CMD "xc7frames2bit \
        --frm_file \${OUT_BITSTREAM} \
        --output_file \${OUT_BIN} \
        \${BIT_TO_BIN_EXTRA_ARGS}"
    BIT_TO_V bitread
    BIT_TO_V_CMD "${CMAKE_COMMAND} -E env \
    PYTHONPATH=${symbiflow-arch-defs_BINARY_DIR}/env/conda/lib/python3.7/site-packages:${PRJXRAY_DIR}:${PRJXRAY_DIR}/third_party/fasm:${symbiflow-arch-defs_SOURCE_DIR}/xc7:${symbiflow-arch-defs_SOURCE_DIR}/utils \
        \${PYTHON3} -mfasm2bels \
        \${BIT_TO_V_EXTRA_ARGS} \
        --db_root ${PRJXRAY_DB_DIR}/${ARCH} \
        --rr_graph \${OUT_RRXML_REAL_LOCATION} \
        --route \${OUT_ROUTE} \
        --iostandard_defs \${OUT_EBLIF}.iostandard.json \
        --bitread $<TARGET_FILE:bitread> \
        --bit_file \${OUT_BIN} \
        --fasm_file \${OUT_BIN}.fasm \
        --pcf \${INPUT_IO_FILE} \
        --eblif \${OUT_EBLIF} \
        --top \${TOP} \
        \${OUT_BIT_VERILOG} \${OUT_BIT_VERILOG}.tcl"
    NO_BIT_TIME
    USE_FASM
    RR_GRAPH_EXT ".xml"
    ROUTE_CHAN_WIDTH 500
  )

endfunction()
