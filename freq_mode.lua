--- freq_mode - input oscillation frequency calculator
--    https://github.com/pchuck/monome-crow
--
-- useful as a calibration tool, frequency follower and quantizer
-- in1: audio-rate line in
-- in2: clock in
-- out1: voltage equivalent to the input frequency
-- out2: quantized voltage based on input frequency

-- constants
local F_THRESH = 0.01 -- frequency change threshold
local SAMPLE_RATE = 0.1 -- frequency in seconds for sampling input frequency
local V_THRESH = 1.0 -- trigger threshold in volts
local V_HYST = 0.1 -- hysteresis voltage
local TRIG = 'rising' -- trigger condition
local CHROMATIC = 12


-- initialization
function init()
   -- read first input, 'freq' mode. poll at SAMPLE_RATE
   input[1].mode('freq', SAMPLE_RATE)
   -- trigger when rising, in 'change' mode. trigger when TRIG
   input[2].mode('change', V_THRESH, V_HYST, TRIG)
   print('initialized')
end

-- chromatically quantize an input voltage
function quantize(v)
   local q = math.floor(v * CHROMATIC) / CHROMATIC
   return(q)
end

-- frequency call-back
local last_f = 0
input[1].freq = function(f)
   -- report the frequency (only if changes more than threshold)
   if math.abs(last_f - f) > F_THRESH then
      print('input[1] frequency = ', f)
   end
   last_f = f

   -- debug
   -- print('f = ', f)
end

-- change/trigger call-back
input[2].change = function(state)
   -- convert frequency to voltage, and quantize
   local v = hztovolts(last_f)
   local vq = quantize(v)
   output[1].volts = v -- mirror the frequency on output 1
   output[2].volts = vq -- quantize the frequency to output 2

   -- debug
   -- print('last_f/v/vq = ', last_f, "/", v, "/", vq)
end
