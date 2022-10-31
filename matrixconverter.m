function matrixconverter(k)
 [r,c] = size(k)
 
 for i = 1:r
    temp = sprintf('%d,', k(r,1:c))
    temp(end) = []
 end 