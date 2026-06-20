-- Cuando el pueblo
-- agota su paciencia,
-- hace tronar
-- el escarmiento

engine.name = "Glut"

local SAMPLE_PATH = _path.audio .. "marcha_peronista.wav"

-- estado
local sample_loaded  = false
local phase_pos      = 0.0
local poll_phase     = nil
local waveform       = {}
local waveform_ready = false
local screen_dirty   = true
local metro_screen   = nil
local any_note_active = false  -- para congelar el cabezal visual

-- Polifonía: 4 voces
local NUM_VOICES  = 4
local voice_note  = {}
local next_voice  = 1

local function alloc_voice()
  for v = 1, NUM_VOICES do
    if voice_note[v] == nil then return v end
  end
  local v = next_voice
  next_voice = (next_voice % NUM_VOICES) + 1
  return v
end

local function find_voice(note)
  for v = 1, NUM_VOICES do
    if voice_note[v] == note then return v end
  end
  return nil
end

local function count_active()
  local c = 0
  for v = 1, NUM_VOICES do
    if voice_note[v] ~= nil then c = c + 1 end
  end
  return c
end

-- splash
local splash_active = true
local splash_frame  = 0
local SPLASH_FRAMES = 45

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

-- Arc
local my_arc = arc.connect()
local reverse_on = false

-- Protege contra glitches: limita granos superpuestos simultáneos.
-- overlap = size * density (cuántos granos suenan a la vez en promedio)
-- Si supera MAX_OVERLAP, recorta la densidad efectiva enviada al engine.
local MAX_OVERLAP = 6
local function safe_density(size_val, density_val)
  local overlap = size_val * density_val
  if overlap > MAX_OVERLAP then
    return MAX_OVERLAP / size_val
  end
  return density_val
end

-- Sensibilidad de teclado: velocity MIDI (0-127) → volumen del grano.
-- 5 niveles cuantizados (suave, medio-suave, medio, medio-fuerte, fuerte)
-- para que el toque se sienta expresivo sin ser frágil.
local VELOCITY_LEVELS = {0.35, 0.5, 0.7, 0.85, 1.0}
local function velocity_to_volume(vel)
  local idx = math.ceil((vel / 127) * #VELOCITY_LEVELS)
  idx = math.max(1, math.min(#VELOCITY_LEVELS, idx))
  return VELOCITY_LEVELS[idx]
end

-- ─────────────────────────────────────────
function init()
  params:add_separator("EL RAYO PERONIZADOR")

  params:add_control("position", "Position",
    controlspec.new(0.0, 1.0, "lin", 0.001, 0.5, ""))
  params:set_action("position", function(val)
    if sample_loaded then
      for v = 1, NUM_VOICES do engine.seek(v, val) end
    end
    screen_dirty = true
    redraw_arc()
  end)

  params:add_control("size", "Grain Size",
    controlspec.new(0.005, 0.4, "lin", 0.001, 0.06, "s"))
  params:set_action("size", function(val)
    if sample_loaded then
      for v = 1, NUM_VOICES do
        engine.size(v, val)
        engine.density(v, safe_density(val, params:get("density")))
      end
    end
    screen_dirty = true
    redraw_arc()
  end)

  params:add_control("density", "Density",
    controlspec.new(1, 60, "lin", 1, 8, "g/s"))
  params:set_action("density", function(val)
    if sample_loaded then
      for v = 1, NUM_VOICES do
        engine.density(v, safe_density(params:get("size"), val))
      end
    end
    screen_dirty = true
    redraw_arc()
  end)

  params:add_control("pitch", "Pitch",
    controlspec.new(0.25, 4.0, "exp", 0.01, 1.0, "x"))
  params:set_action("pitch", function(val)
    if sample_loaded then
      for v = 1, NUM_VOICES do engine.pitch(v, val) end
    end
  end)

  params:add_control("reverb_mix", "Reverb Mix",
    controlspec.new(0.0, 1.0, "lin", 0.01, 0.12, ""))
  params:set_action("reverb_mix", function(val)
    if sample_loaded then
      -- reverb_mix/room/damp son GLOBALES en Glut (un solo bus de efecto
      -- compartido por todas las voces), NO llevan número de voz.
      engine.reverb_mix(val)
      if val <= 0.001 then
        engine.reverb_room(0.0)   -- corta el bus: silencio real
      else
        engine.reverb_room(0.5)
      end
    end
    screen_dirty = true
    redraw_arc()
  end)

  params:add_separator("MIDI")
  params:add_number("midi_ch", "Canal MIDI", 1, 16, 1)

  params:read()

  -- MIDI
  if #midi.devices > 0 then
    local midi_device = midi.connect(1)
    midi_device.event = midi_event
  end

  -- Poll cabezal — solo actualiza si hay notas activas
  poll_phase = poll.set("phase_1", function(val)
    if any_note_active then
      phase_pos    = val
      screen_dirty = true
    end
  end)
  poll_phase.time = 1/15
  poll_phase:start()

  -- Metro pantalla
  metro_screen = metro.init()
  metro_screen.time = 1/15
  metro_screen.event = function()
    if splash_active then
      splash_frame = splash_frame + 1
      draw_splash()
      if splash_frame >= SPLASH_FRAMES then
        splash_active = false
        screen_dirty  = true
      end
    elseif screen_dirty then
      redraw()
      screen_dirty = false
    end
  end
  metro_screen:start()

  -- Cargar sample con delay
  clock.run(function()
    clock.sleep(1.0)
    load_sample()
  end)

  print("El Rayo Peronizador listo ✓")
end

-- ─────────────────────────────────────────
function load_sample()
  if not file_exists(SAMPLE_PATH) then
    print("AVISO: no se encontró " .. SAMPLE_PATH)
    screen_dirty = true
    return
  end

  for v = 1, NUM_VOICES do
    engine.read(v, SAMPLE_PATH)
  end

  clock.run(function()
    clock.sleep(1.5)
    for v = 1, NUM_VOICES do
      engine.volume(v, 1.0)
      engine.envscale(v, 0.3)     -- envelope más corto = respuesta más ágil
      engine.jitter(v, 0.1)
      engine.size(v, params:get("size"))
      engine.density(v, safe_density(params:get("size"), params:get("density")))
      engine.pitch(v, params:get("pitch"))
      engine.speed(v, 1.0)
      engine.spread(v, 0)
      engine.seek(v, 0.5)
      engine.gate(v, 0)
    end

    -- Reverb: comando global, una sola vez (no por voz)
    engine.reverb_mix(params:get("reverb_mix"))
    engine.reverb_room(0.5)
    engine.reverb_damp(0.6)

    sample_loaded = true
    print("Sample cargado ✓")
    screen_dirty = true
    generate_waveform()
    redraw_arc()
  end)
end

-- ─────────────────────────────────────────
function generate_waveform()
  waveform = {}
  math.randomseed(12345)
  local raw = {}
  for i = 1, 128 do
    local x = i / 128.0
    local v = math.abs(
      math.sin(x * math.pi * 3.7)  * 0.5 +
      math.sin(x * math.pi * 7.3)  * 0.3 +
      math.sin(x * math.pi * 13.1) * 0.15 +
      (math.random() - 0.5)        * 0.1
    )
    raw[i] = v
  end
  for i = 1, 128 do
    local sum, count = 0, 0
    for j = math.max(1, i-2), math.min(128, i+2) do
      sum = sum + raw[j]; count = count + 1
    end
    waveform[i] = sum / count
  end
  local mx = 0.001
  for _, v in ipairs(waveform) do if v > mx then mx = v end end
  for i = 1, 128 do waveform[i] = waveform[i] / mx end

  waveform_ready = true
  screen_dirty   = true
  print("Forma de onda lista ✓")
end

-- ─────────────────────────────────────────
-- Encoders Norns
-- ─────────────────────────────────────────
function enc(n, delta)
  if     n == 1 then params:delta("position", delta * 0.1)
  elseif n == 2 then params:delta("size",     delta * 0.15)
  elseif n == 3 then params:delta("density",  delta)
  end
  screen_dirty = true
end

local random_pos_on = false
local random_pos_metro = nil

local function start_random_position()
  if random_pos_metro then random_pos_metro:stop() end
  random_pos_metro = metro.init()
  random_pos_metro.time = 0.6   -- cada 0.6s salta a una posición nueva
  random_pos_metro.event = function()
    local new_pos = math.random()
    params:set("position", new_pos)
  end
  random_pos_metro:start()
end

local function stop_random_position()
  if random_pos_metro then
    random_pos_metro:stop()
    random_pos_metro = nil
  end
end

function key(n, z)
  if z ~= 1 then return end

  if n == 2 then
    -- K2: Random Position toggle (modo automático continuo)
    random_pos_on = not random_pos_on
    if random_pos_on then
      start_random_position()
    else
      stop_random_position()
    end
    screen_dirty = true

  elseif n == 3 then
    -- K3: Reverse toggle
    reverse_on = not reverse_on
    apply_reverse()
    screen_dirty = true
    redraw_arc()
  end
end

-- ─────────────────────────────────────────
-- Arc 4: ring1=POS, ring2=SIZE, ring3=DENS, ring4=REVERB MIX
-- ─────────────────────────────────────────
function my_arc.delta(n, delta)
  if n == 1 then
    params:delta("position", delta * 0.004)
  elseif n == 2 then
    params:delta("size", delta * 0.01)
  elseif n == 3 then
    params:delta("density", delta * 0.3)
  elseif n == 4 then
    params:delta("reverb_mix", delta * 0.03)
  end
end

function apply_reverse()
  -- speed controla la DIRECCION de reproducción (no el pitch/transposición)
  local base_speed = 1.0
  local signed = reverse_on and -base_speed or base_speed
  if sample_loaded then
    for v = 1, NUM_VOICES do engine.speed(v, signed) end
  end
end

function redraw_arc()
  if not my_arc.device then return end
  my_arc:all(0)

  local pos  = params:get("position")
  local size = params:get("size")
  local dens = params:get("density")
  local rmix = params:get("reverb_mix")

  -- Ring 1: position (0-1 → 0-64 LEDs)
  draw_arc_ring(1, pos, 0, 1)
  -- Ring 2: size
  draw_arc_ring(2, (size - 0.005) / 0.395, 0, 1)
  -- Ring 3: density
  draw_arc_ring(3, dens / 60, 0, 1)
  -- Ring 4: reverb mix
  draw_arc_ring(4, rmix, 0, 1)

  my_arc:refresh()
end

function draw_arc_ring(ring, norm, lo, hi)
  norm = math.max(0, math.min(1, norm))
  local lit = math.floor(norm * 64)
  for led = 0, 63 do
    if led < lit then
      my_arc:led(ring, led + 1, 12)
    else
      my_arc:led(ring, led + 1, 1)
    end
  end
end

-- ─────────────────────────────────────────
-- MIDI — polifonía 4 voces, acordes
-- ─────────────────────────────────────────
function midi_event(data)
  local msg = midi.to_msg(data)
  if msg.ch ~= params:get("midi_ch") then return end

  if msg.type == "note_on" and msg.vel > 0 then
    local semis = msg.note - 69
    local ratio = math.pow(2, semis / 12.0)  -- transposición (siempre positiva)
    local spd   = reverse_on and -1.0 or 1.0  -- dirección de reproducción
    local vol   = velocity_to_volume(msg.vel)  -- sensibilidad a la fuerza del toque

    if sample_loaded then
      local v = alloc_voice()
      voice_note[v] = msg.note
      engine.size(v, params:get("size"))
      engine.density(v, safe_density(params:get("size"), params:get("density")))
      engine.pitch(v, ratio)
      engine.speed(v, spd)
      engine.seek(v, params:get("position"))
      engine.volume(v, vol)
      engine.gate(v, 1)
      any_note_active = true
    end

  elseif msg.type == "note_off" or (msg.type == "note_on" and msg.vel == 0) then
    if sample_loaded then
      local v = find_voice(msg.note)
      if v then
        engine.gate(v, 0)
        voice_note[v] = nil
      end
      if count_active() == 0 then
        for i = 1, NUM_VOICES do engine.gate(i, 0) end
        any_note_active = false
      end
    end

  elseif msg.type == "cc" then
    local v = msg.val / 127.0
    if     msg.cc == 1 then params:set("position", v)
    elseif msg.cc == 2 then params:set("size", 0.005 + v * 0.395)
    elseif msg.cc == 3 then params:set("density", math.floor(1 + v * 59))
    end
  end
end

-- ─────────────────────────────────────────
-- Dibuja una mano con dedos índice y mayor en V (símbolo peronista)
-- centrada en (cx, cy), escala aproximada 'scale'
function draw_v_hand(cx, cy, scale, lvl)
  screen.level(lvl)
  screen.line_width(1.3)

  -- Palma (contorno simple con líneas rectas)
  screen.move(cx - 5*scale, cy + 7*scale)
  screen.line(cx - 6*scale, cy + 2*scale)
  screen.line(cx - 5*scale, cy - 1*scale)
  screen.line(cx - 3*scale, cy - 3*scale)
  screen.line(cx - 3*scale, cy + 7*scale)
  screen.line(cx - 5*scale, cy + 7*scale)
  screen.stroke()

  -- Dedo índice (hacia arriba-izquierda, forma la V)
  screen.move(cx - 3*scale, cy - 2*scale)
  screen.line(cx - 5*scale, cy - 12*scale)
  screen.line(cx - 3*scale, cy - 13*scale)
  screen.line(cx - 1*scale, cy - 3*scale)
  screen.stroke()

  -- Dedo mayor (hacia arriba-derecha, forma la V)
  screen.move(cx - 1*scale, cy - 3*scale)
  screen.line(cx + 1*scale, cy - 13*scale)
  screen.line(cx + 3*scale, cy - 12*scale)
  screen.line(cx + 1*scale, cy - 2*scale)
  screen.stroke()

  -- Resto de la mano (dedos cerrados + pulgar, forma compacta)
  screen.move(cx + 1*scale, cy - 2*scale)
  screen.line(cx + 4*scale, cy - 1*scale)
  screen.line(cx + 5*scale, cy + 2*scale)
  screen.line(cx + 5*scale, cy + 7*scale)
  screen.line(cx - 3*scale, cy + 7*scale)
  screen.stroke()

  -- Pulgar
  screen.move(cx + 4*scale, cy - 1*scale)
  screen.line(cx + 7*scale, cy + 1*scale)
  screen.line(cx + 6*scale, cy + 4*scale)
  screen.line(cx + 5*scale, cy + 2*scale)
  screen.stroke()
end

function draw_splash()
  screen.clear()
  screen.aa(1)
  local t    = splash_frame / SPLASH_FRAMES
  local fade = math.sin(t * math.pi)
  local lvl  = math.max(1, math.floor(fade * 15))

  -- Icono: mano en V, de costado, a la izquierda del título
  draw_v_hand(18, 32, 1.0, lvl)

  screen.level(lvl)
  screen.font_face(23)   -- VeraSe: serif, con más carácter, look más clásico
  screen.font_size(11)
  screen.move(72, 28) screen.text_center("EL RAYO")
  screen.move(72, 42) screen.text_center("PERONIZADOR")

  screen.level(math.floor(lvl * 0.5))
  screen.font_face(2)    -- ALEPH: tipografía con personalidad propia
  screen.font_size(6)
  screen.move(64, 56) screen.text_center("by elektrones_libres")

  screen.update()
end

-- ─────────────────────────────────────────
function redraw()
  screen.clear()
  screen.aa(1)

  local pos  = params:get("position")
  local size = params:get("size")
  local dens = params:get("density")

  screen.level(10)
  screen.font_face(1)
  screen.font_size(6)
  screen.move(64, 7)
  screen.text_center("EL RAYO PERONIZADOR")

  local WY  = 10
  local WH  = 28
  local mid = WY + math.floor(WH / 2)

  if not sample_loaded then
    screen.level(5)
    screen.font_size(6)
    screen.move(64, mid + 4)
    screen.text_center("cargando sample...")

  elseif waveform_ready then
    screen.level(4)
    for i = 1, 128 do
      local amp = waveform[i] * (WH / 2)
      screen.move(i - 1, mid - amp)
      screen.line(i - 1, mid + amp)
    end
    screen.stroke()

    local px_pos   = math.floor(pos * 128)
    local px_size  = math.max(2, math.floor(size * 25))
    local px_left  = math.max(0,   px_pos - math.floor(px_size / 2))
    local px_right = math.min(128, px_left + px_size)

    screen.level(2)
    screen.rect(px_left, WY, px_right - px_left, WH)
    screen.fill()

    screen.level(14)
    for i = px_left + 1, px_right do
      if waveform[i] then
        local amp = waveform[i] * (WH / 2)
        screen.move(i - 1, mid - amp)
        screen.line(i - 1, mid + amp)
      end
    end
    screen.stroke()

    -- cabezal: blanco si suena, gris si está congelado
    local ph = math.floor(phase_pos * 128)
    screen.level(any_note_active and 15 or 6)
    screen.line_width(1)
    screen.move(ph, WY)
    screen.line(ph, WY + WH)
    screen.stroke()
  end

  screen.level(3)
  screen.move(0, WY + WH + 2)
  screen.line(128, WY + WH + 2)
  screen.stroke()

  draw_mini_param("POS",  string.format("%.2f",  pos),              pos,              0)
  draw_mini_param("SIZE", string.format("%.2fs", size),             (size-0.005)/0.395, 43)
  draw_mini_param("DENS", string.format("%d",    math.floor(dens)), dens/60,          86)

  -- Indicadores de estado: REVERSE y RANDOM
  local status = ""
  if reverse_on    then status = status .. "◄REV " end
  if random_pos_on then status = status .. "⟳RND" end

  screen.level((reverse_on or random_pos_on) and 14 or 2)
  screen.font_size(6)
  screen.move(64, 63)
  if status ~= "" then
    screen.text_center(status)
  else
    screen.text_center("K2:rnd  K3:rev")
  end

  screen.update()
end

function draw_mini_param(label, value_str, norm, x)
  norm = math.max(0, math.min(1, norm))
  local y = 46
  screen.level(5)
  screen.font_size(6)
  screen.move(x, y)
  screen.text(label)
  screen.level(12)
  screen.move(x, y + 8)
  screen.text(value_str)
  screen.level(2)
  screen.rect(x, y + 10, 38, 2)
  screen.fill()
  screen.level(11)
  screen.rect(x, y + 10, math.floor(norm * 38), 2)
  screen.fill()
end

-- ─────────────────────────────────────────
function cleanup()
  if metro_screen then metro_screen:stop() end
  if poll_phase   then poll_phase:stop()   end
  if random_pos_metro then random_pos_metro:stop() end
  params:write()
end
