--- snh - sample and hold + random
--    https://github.com/pchuck/monome-crow
--
-- in1: clock
-- in2: input voltage
-- out1: input (sampled/held)
-- out2: input (sampled/held/quantized
-- out3: random (held)
-- out4: random (held/quantized)

-- constants
local V_THRESH = 1.0 -- trigger threshold in volts
local V_HYST = 0.1 -- hysteresis voltage
local TRIG = 'rising' -- trigger condition
local CHROMATIC = 12
local V_MAX = 5.0


-- initialization
function init()
   -- trigger on first input
   input[1].mode('change', V_THRESH, V_HYST, TRIG)
   print('initialized')
end

-- chromatically quantize an input voltage
function quantize(v)
   return(math.floor(v * CHROMATIC) / CHROMATIC)
end

-- trigger call-back
input[1].change = function(state)
   local v = input[2].volts -- sample the input voltage
   local r = math.random() * V_MAX -- generate a random voltage (0-V_MAX)
   -- outputs
   output[1].volts = v ; output[2].volts = quantize(v)
   output[3].volts = r ; output[4].volts = quantize(r)

   -- debug
   -- print('v/vq = ', v, "/", vq)
   -- print('r/rq = ', r, "/", rq)
end

