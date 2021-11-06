--- krell-clocked - behold the flying krow-ell! 
--    https://github.com/pchuck/monome-crow
--
-- A clocked 'melodic' interpretation of the 'krell' patch, for crows.
--
--   A pseudo-random generative sequencer that outputs two pairs of envelope
--   and v/o on outputs 1/2 and 3/4, independently clocked by inputs 1/2.
--
--   Output scale, quantization and envelope parameters can be customized
--   in the constants section below.
--
--  in1: clock 1
--  in2: clock 2
-- out1: envelope for first krell sequence
-- out2: v/o for first krell sequence
-- out3: envelope for second krell sequence
-- out4: v/o for second krell sequence
--

-- constants
local M_PERIOD = 0.01 -- metro-based counter interval in seconds
local V_THRESH = 1.0 -- trigger threshold in volts
local V_HYST = 0.1 -- hysteresis voltage
local TRIG = 'rising' -- trigger condition

-- quantization
-- scales (via bowery/quantizer)
local scales = { ['none']   = { },
                 ['octave'] = {0},
                 ['major' ] = {0, 2, 4, 5, 7, 9, 11},
                 ['harMin'] = {0, 2, 3, 5, 7, 8, 10},
                 ['dorian'] = {0, 2, 3, 5, 7, 9, 10},
                 ['majTri'] = {0, 4, 7},
                 ['dom7th'] = {0, 4, 7, 10},
                 ['wholet'] = {0, 2, 4, 6, 8, 10},
                 ['chroma'] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },}
-- local SCALE = scales['chroma'] -- for a true 'krell' experience
local SCALE = scales['dom7th'] -- or, something more melodic
local TET12 = 12  -- temperament
local VPO   = 1.0 -- volts per octave

-- input control voltage range
local CV_RANGE = { -5.00, 5.00 } -- min/max input voltage range (v)

-- envelope settings
local ENV_SHP = 'log' -- envelope shape, eg linear, log, expo, rebound, etc
local ENV_MAX = 8.00 -- max envelope output voltage

-- A/R settings
local  ATTACK = { { 0.05, 0.5 }, -- seq 1&2, env attack min/max time (s)
                  { 0.05, 0.5 } }
local RELEASE = { { 0.1, 1.00 }, -- seq 1&2, env release min/max time (s)
                  { 0.1, 1.00 } }

-- note settings
local OV_RANGE = { 0.00, 2.00} -- v/o range (octave range) (v)

-- table indices
local MIN = 1; local MAX = 2

-- outputs - logical ids of the krell sequencers
local SEQS = { 1, 2 }

-- sequencer info - envelope and pitch output ids of the krell sequencers
local SEQ = { { ['env'] = 1, ['vpo'] = 2 },
              { ['env'] = 3, ['vpo'] = 4 } }


-- initialization
function init()
   -- initialize mode, call-back and quantization
   for _, v in pairs(SEQS) do
      input[v].mode('change', V_THRESH, V_HYST, TRIG) -- trig on clock edge
      input[v].change = function() change(v) end -- trig call-back function
      output[SEQ[v]['vpo']].scale(SCALE, TET12, VPO) -- pitch output quant
   end
   -- a predictable timer to track frequency (and set env duration)
   local counter = metro.init { event = count_event,
                                time = M_PERIOD,
                                count = -1 }
   counter:start()
end

-- update the timer counter (tracks time in intervals of M_PERIOD)
local gc_global = 0
function count_event(count)
   gc_global = gc_global + 1
end

-- adjust the envelope based on the provided clock interval period
function adjust_ard(sid, p)
   -- attack and release min/max times are a fraction of the trigger interval
   ATTACK[sid][MAX] = 1 / p / 4
   RELEASE[sid][MAX] = 1 / p / 3
   ATTACK[sid][MIN] = ATTACK[sid][MAX] / 5
   RELEASE[sid][MIN] = RELEASE[sid][MAX] / 3
end

-- update the attack/release parameters and trigger the envelope
local gc_last = { 0, 0 } -- last time each sequencer's envelope was triggered
function change(sid)
   local gc_delta = (gc_global - gc_last[sid]) * M_PERIOD -- hz
   local p = 1 / gc_delta -- clock period, in seconds
   adjust_ard(sid, p) -- adjust the envelope based on clock rate
   gc_last[sid] = gc_global -- record the current tick
   krell(sid)
end

-- return a factor between 0 and 1.0 representing the position of 'v' in max-min
function s_factor_i(v, range)
   return(1.0 - (v - range[MIN]) / (range[MAX] - range[MIN]))
end

-- generate a random float between 'min' and 'max'
function rand_float(range)
   return math.random() * (range[MAX] - range[MIN]) + range[MIN]
end

-- generate a random envelope, for the specified sequencer, scaled by pitch
function random_ar(sid, pitch)
   local p_factor = s_factor_i(pitch, OV_RANGE) -- higher pitch -> shorter env
   local  attack = rand_float(ATTACK[sid])  * p_factor + ATTACK[sid][MIN]
   local release = rand_float(RELEASE[sid]) * p_factor + RELEASE[sid][MIN]

   -- debug
   -- print(sid, '- p/a/r = ', pitch, '/', attack, '/', release)
   return(ar(attack, release, ENV_MAX, ENV_SHP))
end

-- generate pitch, create and trigger the envelope, for the specified sequencer
function krell(sid)
   local pitch = rand_float(OV_RANGE) -- generate a random voltage
   output[SEQ[sid]['vpo']].volts = pitch -- set the pitch
   output[SEQ[sid]['env']].action = random_ar(sid, pitch) -- env 
   output[SEQ[sid]['env']]() -- retrigger the envelope
end


