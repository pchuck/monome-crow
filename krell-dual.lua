--- krell-dual - behold the flying krow-ell!
--    https://github.com/pchuck/monome-crow
--
-- A CV controlled 'melodic' interpretation of the 'krell' patch, for crows.
--
--   A pseudo-random generative sequencer that outputs two pairs of envelope
--   and v/o on outputs 1/2 and 3/4. Inputs 1/2 control the velocity
--   (via relative CV level) of the two independent sequences.
--
--   Input CV voltage ranges, output scale, quantization and envelope
--   parameters can be customized in the constants section below.
--
--  in1: cv over velocity of the first krell sequence  (see 'CV_RANGE')
--  in2: cv over velocity of the second krell sequence (see 'CV_RANGE')
-- out1: envelope for first krell sequence
-- out2: v/o for first krell sequence
-- out3: envelope for second krell sequence
-- out4: v/o for second krell sequence
--

-- constants
TET12 = 12  -- temperament
VPO = 1.0 -- volts per octave
CV_RANGE = { -5.00, 5.00 } -- min/max input voltage range (v)
ATTACK = { 0.01, 1.00 } -- min/max attack time (s) 
RELEASE = { 0.05, 4.00 } -- min/max release time (s) 
DELAY = { 0.00, 2.00} -- min/max delay between envelopes (s)
MIN = 1; MAX = 2 -- table indices for ranges
SEQS = { 1, 2 } -- outputs - logical ids of the krell sequencers
-- sequencer info - envelope and pitch output ids of the two krell sequencers
SEQ = { { ['env'] = 1, ['vpo'] = 2 }, { ['env'] = 3, ['vpo'] = 4 } }

-- scales (via bowery/quantizer)
scale_names = { 'octave', 'major', 'harMin', 'dorian', 'majTri', 'dom7th',
                'wholet', 'chroma' }
scale_notes = { ['none']   = { },
                ['octave'] = {0},
                ['major' ] = {0, 2, 4, 5, 7, 9, 11},
                ['harMin'] = {0, 2, 3, 5, 7, 8, 10},
                ['dorian'] = {0, 2, 3, 5, 7, 9, 10},
                ['majTri'] = {0, 4, 7},
                ['dom7th'] = {0, 4, 7, 10},
                ['wholet'] = {0, 2, 4, 6, 8, 10},
                ['chroma'] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 },}

-- public (values that can be changed remotely or at run-time, eg via druid:)
--   > public.scale = 'chroma' -- for a more authentic krell sound
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
   -- envelope outputs; hooks for retriggering on EOC and quantization
   for _, v in pairs(SEQS) do
      output[SEQ[v]['env']].done = function() krell(v) end -- env re-trigger
      set_scale(public.scale)
      krell(v) -- krell sequencer -- jump-start w/ initial trigger
   end
end

-- set/reset scale at runtime
function set_scale(s)
   local notes = scale_notes[s]
   for _, v in pairs(SEQS) do
      output[SEQ[v]['vpo']].scale(notes, TET12, VPO) -- pitch output quant
   end
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
   local n_range = { public.n_min_v, public.n_max_v }
   local v = input[sid].volts -- current 'pace' cv
   local i_factor = s_factor_i(v,     CV_RANGE) -- higher cv -> shorter env
   local p_factor = s_factor_i(pitch, n_range) -- higher pitch -> shorter env
   local  attack = rand_float(ATTACK)  * p_factor * i_factor + ATTACK[MIN]
   local release = rand_float(RELEASE) * p_factor * i_factor + RELEASE[MIN]

   -- debug
   -- print('v - ', v)
   -- print(sid, '- p/a/r = ', pitch, '/', attack, '/', release)
   return(ar(attack, release, public.e_max_v, public.env_shp))
end

-- random pause in the form of a 'noop' envelope, for the specified sequencer
function pause(sid)
   local v = input[sid].volts -- current 'pace' cv
   local i_factor = s_factor_i(v, CV_RANGE) -- higher cv -> shorter delay
   local delay = rand_float(DELAY) * i_factor + DELAY[MIN]
   return(ar(0.0, delay, 0, 'linear')) -- an envelope with zero magnitude
end

-- generate pitch, create and trigger the envelope, for the specified sequencer
function krell(sid)
   local n_range = { public.n_min_v, public.n_max_v }
   local pitch = rand_float(n_range) -- generate a random voltage
   output[SEQ[sid]['vpo']].volts = pitch -- set the pitch
   output[SEQ[sid]['env']].action = -- create env and variable pause
      { random_ar(sid, pitch), pause(sid) } 
   output[SEQ[sid]['env']]() -- retrigger the envelope
end

