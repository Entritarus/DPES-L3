from vunit import VUnit

# Create VUnit instance
prj = VUnit.from_argv()

prj.add_osvvm()

lab_lib = prj.add_library("lab_lib")

lab_lib.add_source_files("../src/traffic_splitter.vhd")
lab_lib.add_source_files("../tb/tb.vhd")
lab_lib.add_source_files("../pkg/util_pkg.vhd")


prj.main()
