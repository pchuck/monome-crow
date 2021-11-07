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
M_PERIOD = 0.001 -- time() interval in seconds
V_THRESH = 1.0 -- trigger threshold in volts
V_HYST = 0.1 -- hysteresis voltage
TRIG = 'rising' -- trigger condition
TET12 = 12  -- temperament
VPO = 1.0 -- volts per octave
ATTACK = { { 0.05, 0.5 }, { 0.05, 0.5 } } -- min/max time (s) for krell seq 1&2
RELEASE = { { 0.1, 1.00 }, { 0.1, 1.00 } } -- min/max time (s) for krell seq 1&2
MIN = 1; MAX = 2 -- table indices for ranges
SEQS = { 1, 2 } -- outputs - logical ids of the krell sequencers
-- sequencer info - envelope and pitch output ids of the two krell sequencers
SEQ = { { ['env'] = 1, ['vpo'] = 2 }, { ['env'] = 3, ['vpo'] = 4 } }

-- scales (via bowery/quantizer)
scale_names = { 'none', 'octave', 'major', 'harMin', 'dorian', 'majTri',
                'dom7th', 'wholet', 'chroma' }
scale_notes = { ['none']   = 'none',
                ['octave'] = {0},
                ['major' ] = {0, 2, 4, 5, 7, 9, 11},
                ['harMin'] = {0, 2, 3, 5, 7, 8, 10},
                ['dorian'] = {0, 2, 3, 5, 7, 9, 10},
                ['majTri'] = {0, 4, 7},
                ['dom7th'] = {0, 4, 7, 10},
                ['wholet'] = {0, 2, 4, 6, 8, 10},
                ['chroma'] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },}

-- public (eg, at run-time, from remote, or druid: > public.scale = 'chroma')
public.add('scale', 'dom7th', scale_names, -- scale
           function() set_scale(public.scale) end)
public.add('env_shp', 'logarithmic', -- envelope shape
           {'linear', 'sine', 'logarithmic', 'exponential',
            'over', 'under', 'rebound'}) 
public.add('n_min_v', 0.0, {-5, 0}) -- note minimum output (v/o) voltage level
public.add('n_max_v', 2.0, { 0, 5}) -- note maximum output (v/o) voltage level
public.add('e_max_v', 8.0, { 0, 10.0}) -- gain; /envelope max voltage level


-- initialization
function init()
   -- initialize mode, call-back and quantization
   for _, v in pairs(SEQS) do
      input[v].mode('change', V_THRESH, V_HYST, TRIG) -- trig on clock edge
      input[v].change = function() change(v) end -- trig call-back function
   end
   set_scale(public.scale)
end

-- set/reset scale at runtime
function set_scale(s)
   local notes = scale_notes[s]
   for _, v in pairs(SEQS) do
      output[SEQ[v]['vpo']].scale(notes, TET12, VPO) -- pitch output quant
   end
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
time_last = { 0, 0 } -- last time each sequencer's envelope was triggered
function change(sid)
   local time_now = time()
   local time_delta = (time_now - time_last[sid]) * M_PERIOD -- hz
   local p = 1 / time_delta -- clock period, in seconds
   adjust_ard(sid, p) -- adjust the envelope based on clock rate
   time_last[sid] = time_now -- record the current time
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
   local n_range = {public.n_min_v, public.n_max_v}
   local p_factor = s_factor_i(pitch, n_range) -- higher pitch -> shorter env
   local  attack = rand_float(ATTACK[sid])  * p_factor + ATTACK[sid][MIN]
   local release = rand_float(RELEASE[sid]) * p_factor + RELEASE[sid][MIN]

   -- debug
   -- print(sid, '- p/a/r = ', pitch, '/', attack, '/', release)
   return(ar(attack, release, public.e_max_v, public.env_shp))
end

-- generate pitch, create and trigger the envelope, for the specified sequencer
function krell(sid)
   local n_range = {public.n_min_v, public.n_max_v}
   local pitch = rand_float(n_range) -- generate a random voltage
   output[SEQ[sid]['vpo']].volts = pitch -- set the pitch
   output[SEQ[sid]['env']].action = random_ar(sid, pitch) -- env 
   output[SEQ[sid]['env']]() -- retrigger the envelope
end


