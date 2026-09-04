# HX7A75A routes the fixed OV5640 PCLK pin C13 through non-clock fabric.
# This file is added to the project only when ENABLE_CAMERA=1.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets camera_pclk_IBUF]
