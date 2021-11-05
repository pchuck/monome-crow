--- krell-dual - behold the flying krow-ell!
--    https://github.com/pchuck/monome-crow
--
-- A CV controlled 'melodic' interpretation of the 'krell' patch, for crows.
--
--   A pseudo-random generative sequencer that outputs two pairs of envelope
--   and v/o on outputs 1/2 and 3/4. Inputs 1/2 control the velocity
--   (via CV) of the two independent sequences.
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

-- quantization
-- scales (via bowery/quantizer)
scales = { ['none']   = { },
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
local V_PO  = 1.0 -- volts per octave

-- input control voltage range
local CV_RANGE = { -5.00, 5.00 } -- min/max input voltage range (v)

-- envelope settings
local ENV_SHP = 'lin' -- envelope shape
local ENV_MAX = 8.00 -- max envelope output voltage

-- A/R settings
local  ATTACK = { 0.01, 1.00 } -- env attack min/max time (s)
local RELEASE = { 0.05, 4.00 } -- env release min/max time (s)

-- note settings
local    DELAY = { 0.00, 2.00} -- min/max delay between envelopes (s)
local OV_RANGE = { 0.00, 2.00} -- v/o range (octave range) (v)

-- table indices
local MIN = 1; MAX = 2

-- outputs - logical ids of the krell sequencers
local SEQS = { 1, 2 }

-- sequencer info - envelope and pitch output ids of the krell sequencers
local SEQ = { { ['env'] = 1, ['vpo'] = 2 },
              { ['env'] = 3, ['vpo'] = 4 } }


-- initialization
function init()
    -- note: no callbacks for inputs (read on-demand in krell())
    -- envelope outputs; hooks for retriggering on EOC
    output[SEQ[1]['env']].done = retrigger_1
    output[SEQ[2]['env']].done = retrigger_2
    for i, v in pairs(SEQS) do
        output[SEQ[i]['vpo']].scale(SCALE, TET12, VPO) -- pitch outputs
        krell(i) -- krell sequencer -- initial trigger
    end
end

-- return a factor between 0 and 1.0 representing the position of 'v' in min-max
function s_factor(v, range)
    return(      (v - range[MIN]) / (range[MAX] - range[MIN]))
end

-- return a factor between 0 and 1.0 representing the position of 'v' in max-min
function s_factor_i(v, range)
    return(1.0 - (v - range[MIN]) / (range[MAX] - range[MIN]))
end

-- generate a random float between 'min' and 'max'
function rand_float(range)
    return math.random() * (range[MAX] - range[MIN]) + range[MIN]
end

-- generate a random envelope, scaled by pitch, for the specified sequence
function random_ar(seq_idx, pitch)
    local v = input[seq_idx].volts -- current 'pace' cv
    local i_factor = s_factor_i(v,     CV_RANGE) -- higher cv -> shorter env
    local p_factor = s_factor_i(pitch, OV_RANGE) -- higher pitch -> shorter env
    local  attack = rand_float(ATTACK)  * p_factor * i_factor + ATTACK[MIN]
    local release = rand_float(RELEASE) * p_factor * i_factor + RELEASE[MIN]

    -- debug
    -- print('v - ', v)
    -- print(seq_idx, '- p/a/r = ', pitch, '/', attack, '/', release)
    return(ar(attack, release, ENV_MAX, ENV_SHAPE))
end

-- generate a random pause in the form of a 'noop' envelope
function pause(seq_idx)
    local v = input[seq_idx].volts -- current 'pace' cv
    local i_factor = s_factor_i(v, CV_RANGE) -- higher cv -> shorter delay
    local delay = rand_float(DELAY) * i_factor + DELAY[MIN]
    return(ar(0.0, delay, 0, 'linear')) -- an envelope with zero magnitude
end

-- generate a pitch, create and trigger the envelope, for the specified sequence
function krell(seq_idx)
    local pitch = rand_float(OV_RANGE) -- generate a random voltage
    output[SEQ[seq_idx]['vpo']].volts = pitch -- set the pitch
    output[SEQ[seq_idx]['env']].action = -- create env and variable pause
        { random_ar(seq_idx, pitch), pause(seq_idx) } 
    output[SEQ[seq_idx]['env']]() -- retrigger the envelope
end

-- retrigger callbacks
-- note: better/possible to pass SEQ as a (single) anon func param in lua?
function retrigger_1() krell(1) end
function retrigger_2() krell(2) end
