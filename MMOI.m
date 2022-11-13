function j = MMOI(osc_time, COM_string, l_string, m)
    
    j = (9.81 * m * osc_time^2 * COM_string^2)/(l_string * 4 * pi^2);