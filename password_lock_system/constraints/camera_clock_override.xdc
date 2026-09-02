# HX7A75A routes the fixed OV5640 PCLK pin C13 through non-clock fabric.
# This implementation-only exception is required for the camera connector.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets camera_pclk_IBUF]
