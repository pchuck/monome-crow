--- adsr - adsr envelope generator
--    https://github.com/pchuck/monome-crow
--
-- in1: trigger
-- in2: n/a
-- out1: adsr envelope 
-- out2: "
-- out3: "
-- out4: "

-- constants
local V_THRESH = 1.0 -- trigger threshold in volts
local V_HYST = 0.1 -- hysteresis voltage
local TRIG = 'rising' -- trigger condition
local IN_GATE = 1 -- gate input
local IN_CV = 2 -- cv input (not used in this version)
local OUTS = { 1, 2, 3, 4 } -- outputs - logical ids of the lfo outputs
local MAX_V = 7 -- maximum envelope output (v)
local MAX_T = 10.0 -- maximum phase length (s)

-- public (values that can be changed remotely or at run-time, eg via druid:)
--   > public.a = 0.1
--
--                 __ a_level
--    / \   ___        __ s_level
--  /            \         __ e_level
--   
-- | a | d | s | r
--
public.add('a',       0.05, { 0, MAX_T }) -- attack time (s)
public.add('d',       0.1,  { 0, MAX_T }) -- decay time (s)
public.add('s',       0.2,  { 0, MAX_T }) -- sustain time (s)
public.add('r',       0.5,  { 0, MAX_T }) -- release time (s)
public.add('a_level',   7,  { 0, MAX_V }) -- attack level (v)
public.add('s_level',   4,  { 0, MAX_V }) -- sustain level (v)
public.add('e_level',   0,  { 0, MAX_V }) -- end level (v)
public.add('shape', 'logarithmic', -- envelope shape
           {'linear', 'sine', 'logarithmic', 'exponential',
            'over', 'under', 'rebound'}) 

-- initialization
function init()
   -- trigger on first input
   input[IN_GATE].mode('change', V_THRESH, V_HYST, TRIG)
   input[IN_GATE].change = function() change() end -- the call-back function
   print('adsr initialized')
end

-- improvement over the asllib adsr() envelope function
--   allows specification of separate initial attack and sustain levels
--   doesn't require additional directives
function adsr2(a, d, s, r, a_level, s_level, e_level, shape)
   return{ to(a_level, a, shape),
           to(s_level, d, shape),
           to(s_level, s, shape),
           to(e_level, r, shape)
         }
end

-- trigger call-back
function change()
   local cv = input[IN_CV].volts
   for _, v in pairs(OUTS) do -- output same env on all outputs
      output[v].action = { adsr2(public.a,
                                 public.d,
                                 public.s,
                                 public.r,
                                 public.a_level,
                                 public.s_level,
                                 public.e_level, 
                                 public.shape) }
      output[v]() -- (re)trigger the envelope
   end
end
