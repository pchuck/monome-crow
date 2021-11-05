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
M_PERIOD = 0.01 -- metro-based counter interval
V_THRESH = 1.0 -- trigger threshold in volts
V_HYST = 0.1 -- hysteresis voltage
TRIG = 'rising' -- trigger condition

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
local  ATTACK = { { 0.05, 0.5 }, -- seq 1&2, env attack min/max time (s)
                  { 0.05, 0.5 } }
local RELEASE = { { 0.1, 1.00 }, -- seq 1&2, env release min/max time (s)
                  { 0.1, 1.00 } }

-- note settings
local OV_RANGE = { 0.00, 2.00} -- v/o range (octave range) (v)

-- table indices
local MIN = 1; MAX = 2

-- outputs - logical ids of the krell sequencers
local SEQS = { 1, 2 }

-- sequencer info - envelope and pitch output ids of the krell sequencers
local SEQ = { { ['env'] = 1, ['vpo'] = 2 },
              { ['env'] = 3, ['vpo'] = 4 } }

-- frequencies of the input clocks (Hz)
local FREQS = { 0, 0 }
SAMPLE_RATE = 1 -- frequency in seconds for sampling clock frequencies

-- initialization
function init()
    -- initialize the input modes to accept clock triggers
    for i, v in pairs(SEQS) do
        input[i].mode('change', V_THRESH, V_HYST, TRIG)
    end
    -- initialize the clock callbacks
    input[SEQS[1]].change = change_1
    input[SEQS[2]].change = change_2
    -- quantize the outputs
    for i, v in pairs(SEQS) do
        output[SEQ[i]['vpo']].scale(SCALE, TET12, VPO) -- pitch outputs
    end
    -- setup a predictable timer to track frequency (and set env duration)
    counter = metro.init { event = count_event,
                           time = M_PERIOD,
                           count = -1 }
    counter:start()
end

-- update the timer counter (tracks time in intervals of M_PERIOD)
gc_global = 0
function count_event(count)
    gc_global = gc_global + 1
end

-- adjust the envelope based on the provided clock interval period
function adjust_ard(id, p)
    -- attack and release min/max times are a fraction of the trigger interval
    ATTACK[id][MAX] = 1 / p / 4
    RELEASE[id][MAX] = 1 / p / 3
    ATTACK[id][MIN] = ATTACK[id][MAX] / 5
    RELEASE[id][MIN] = RELEASE[id][MAX] / 3
end

-- update the attack/release parameters and trigger the envelope
gc_last = { 0, 0 } -- the last time each sequencer's envelope was triggered
function change(id, state)
    local gc_delta = (gc_global - gc_last[id]) * M_PERIOD -- hz
    local p = 1 / gc_delta -- clock period, in seconds
    adjust_ard(id, p) -- adjust the envelope based on clock rate
    gc_last[id] = gc_global -- record the current tick
    trigger(id)
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
function random_ar(id, pitch)
    local p_factor = s_factor_i(pitch, OV_RANGE) -- higher pitch -> shorter env
    local  attack = rand_float(ATTACK[id])  * p_factor + ATTACK[id][MIN]
    local release = rand_float(RELEASE[id]) * p_factor + RELEASE[id][MIN]

    -- debug
    -- print(id, '- p/a/r = ', pitch, '/', attack, '/', release)
    return(ar(attack, release, ENV_MAX, ENV_SHAPE))
end

-- generate a pitch, create and trigger the envelope, for the specified sequence
function krell(id)
    local pitch = rand_float(OV_RANGE) -- generate a random voltage
    output[SEQ[id]['vpo']].volts = pitch -- set the pitch
    output[SEQ[id]['env']].action = random_ar(id, pitch) -- env 
    output[SEQ[id]['env']]() -- retrigger the envelope
end

-- trigger and change callback wrappers
function trigger(id) krell(id) end
function change_1(state) change(SEQS[1], state) end
function change_2(state) change(SEQS[2], state) end
