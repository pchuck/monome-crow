--- cmss-tremolo - tremolo prototype/collaboration
--    tremolo as in amplitude modulation, not vibrato (as in pitch)
--    pb. the colorado modular society, sine mountain and patchogram
--    https://github.com/pchuck/monome-crow
--
-- A configurable parametric tremolo effect/envelopes generator
--
--  in1: gate
--  in2: v/o pitch
-- out1: tremolo oscillation/decay/envelope 1
-- out2: tremolo oscillation/decay/envelope 2 (phase shifted)
-- out3: tremolo oscillation/decay/envelope 3
-- out4: tremolo oscillation/decay/envelope 4 (phase shifted)
--

-- constants
local M_PERIOD = 0.001 -- time() interval in seconds
local V_THRESH = 1.0 -- trigger threshold in volts
local V_HYST = 0.1 -- hysteresis voltage
local TRIG = 'rising' -- trigger condition
local GATE = 1 ; PITCH = 2 -- inputs - logical ids of the inputs
local OUTS = { 1, 2, 3, 4 } -- outputs - logical ids of the lfo outputs
local V_MIN = 1.0 -- min output voltage
local V_MAX = 8.0 -- max output voltage

-- public/configurable parameters
public.add( 'rate',   50, {   1, 100}) -- osc rate (# div per tap/clock period)
public.add('accel',  1.1, { 1.0, 1.5}) -- time compression per tremolo interval
public.add('decay', -0.8, {-3.0, 1.0}) -- voltage decay per tremolo interval
public.add('shape', 'sin', -- envelope shape
           { 'lin', 'sin', 'log', 'exp', 'over', 'under', 'rebound'})

-- initialization - setup the callbacks for reacting to triggers/gates
function init()
   input[GATE].mode('change', V_THRESH, V_HYST, TRIG) -- trig on clock edge
   input[GATE].change = function() change(1) end -- the call-back function
end

-- tremolo lfo w/ support for +/- offsets, shapes and dynamic values
function tremolo(sid, pitch, period, offset, level)
   local shape = public.shape -- envelope shape
   local sub = period / public.rate -- time per oscillation, compressed by accel
   local accel = public.accel -- time-based modulation accel/deceleration 
   local ld = public.decay -- amplitude decay per oscillation
   local up = to( offset,                     dyn{time=sub}:mul(accel), shape )
   local dn = to( dyn{height=level}:step(ld), dyn{time=sub}:mul(accel), shape )
   -- invert odd/even output waveforms for a leslie speaker-like stereo effect
   if sid % 2 == 0 then return loop { up, dn } 
   else                 return loop { dn, up } end
end

-- update the tremolo parameters and trigger the envelope
local time_last = { 0, 0 } -- last time each output's envelope was triggered
function change(sid)
   local time_now = time()
   local time_delta = (time_now - time_last[sid]) * M_PERIOD -- seconds (1/f)
   time_last[sid] = time_now -- record the current time
   
   -- capture pitch, create and trigger the tremolo envelope for specified out
   local pitch = input[PITCH].volts -- unused; could affect tremolo depth
   for _, v in pairs(OUTS) do
      output[v].action = { tremolo(v, pitch, time_delta, V_MIN, V_MAX) }
      output[v]() -- (re)trigger the envelope
   end
end
