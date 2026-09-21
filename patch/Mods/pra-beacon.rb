# pra-beacon.rb  -  Directional pathfinding beacon (Steam Audio HRTF)
#
# Guides you to a chosen map target by ear, TURN BY TURN, following the ACTUAL
# walkable route around walls - not a straight-line compass.
#
# USAGE
#   1. Options -> Accessibility -> "Directional Beacon" -> On.
#   2. Scroll targets with J / L (pathfinder: travel points, NPCs, items...).
#   3. Press Shift+B to start guiding to the selected target (again to stop).
#   The beacon sound is placed in true 3D toward your NEXT step along the route
#   and re-steers as you walk. A chime plays when you arrive.
#
# AUDIO ENGINE (chosen automatically):
#   * Steam Audio HRTF (best): uses beacon.dll + phonon.dll (Valve's Steam
#     Audio) for real binaural audio - genuine left/right, front/back, and
#     distance. Runs inside the game; no external program.
#   * Fallback: Reborn's built-in directional step sounds, if the DLLs or the
#     beacon sound are missing.
#
# FILES in the game root for HRTF mode:
#   beacon.dll    (built from beacon_src/beacon.c - see beacon_src/BUILD.txt)
#   phonon.dll    (Steam Audio 4.8.1)
#   beacon.wav    (your beacon sound - MONO gives the cleanest spatialisation;
#                  beacon.mp3 also works)

#===============================================================================
# Steam Audio HRTF backend (beacon.dll + phonon.dll, driven via Ruby fiddle)
#===============================================================================
module PraBeaconAudio
  # ---- Front/back cue strength (generic HRTF renders front/back weakly, so
  # we add a pitch + muffling cue). Raise these if it is still too subtle. ----
  PITCH_RANGE = 0.22   # pitch is higher in front, LOWER behind
  BACK_DAMP   = 0.85   # how muffled a sound behind you gets (0.0 - 0.95)
  @available = false
  @started   = false
  @playing   = false

  class << self
    attr_reader :available, :started, :playing
  end

  def self.log(msg)
    File.open("beacon_error.txt", "a") { |f| f.puts("[#{Time.now}] #{msg}") } rescue nil
  end

  # Files may live inside the patch folder (drop-in distribution) or in the
  # game root (older manual installs). Search both and return an ABSOLUTE
  # path - fiddle will not accept relative ones.
  SEARCH_DIRS = ["patch/lib", "patch/audio", "."]

  def self.locate(name)
    SEARCH_DIRS.each do |d|
      p = File.join(d, name)
      return File.expand_path(p).tr("/", 92.chr) if File.exist?(p)
    end
    nil
  end

  def self.sound_file
    locate("beacon.wav") || locate("beacon.mp3")
  end

  def self.init
    return @available if @started
    @started = true
    snd    = sound_file
    dll    = locate("beacon.dll")
    phonon = locate("phonon.dll")
    if snd.nil? && locate("beacon.ogg")
      log("Found beacon.ogg, but OGG Vorbis is not supported. Convert it to WAV or MP3 (mono is best) and name it beacon.wav. Using built-in beeps for now.")
      return false
    end
    unless dll && phonon && snd
      log("Steam Audio mode off: need patch/lib/beacon.dll, patch/lib/phonon.dll and patch/audio/beacon.wav. Using built-in beeps.")
      return false
    end
    begin
      require 'fiddle'
      require 'fiddle/import'
      # phonon.dll MUST be resident before beacon.dll loads, or Windows cannot
      # resolve the import of it inside beacon.dll.
      Fiddle.dlopen(phonon)
      unless defined?(BeaconLib)
        beacon_path = dll
        Object.const_set(:BeaconLib, Module.new do
          extend Fiddle::Importer
          dlload beacon_path
          extern "int beacon_init(char*)"
          extern "int beacon_ready()"
          extern "int beacon_start()"
          extern "void beacon_stop()"
          extern "void beacon_set_direction(float, float, float)"
          extern "void beacon_set_gain(float)"
          extern "void beacon_set_tuning(float, float)"
          extern "void beacon_shutdown()"
          extern "char* beacon_last_error()"
        end)
      end
      rc = BeaconLib.beacon_init(snd)
      if rc != 0
        log("Steam Audio init failed (code #{rc}: #{BeaconLib.beacon_last_error.to_s}). Using built-in beeps.")
        @available = false
        return false
      end
      BeaconLib.beacon_set_tuning(PITCH_RANGE, BACK_DAMP)
      @available = true
      log("Steam Audio HRTF beacon ready (sound: #{snd}).")
      true
    rescue => e
      log("Steam Audio load failed (#{e.class}: #{e.message}). Using built-in beeps.")
      @available = false
      false
    end
  end

  # Point the beacon along the next route step.
  # Steam Audio is right-handed: +x right, +y up, -z FORWARD.
  # Game grid: +x east, +y south. North (up) => dy negative => z negative =>
  # in front of you, so passing (dx, 0, dy) is already correct.
  def self.point(dx, dy, dist)
    return false unless @available
    BeaconLib.beacon_set_direction(dx.to_f, 0.0, dy.to_f)
    gain = 0.35 + (0.65 * (1.0 - [dist / 25.0, 1.0].min)) # louder as you close in
    BeaconLib.beacon_set_gain(gain)
    unless @playing
      BeaconLib.beacon_start
      @playing = true
    end
    true
  rescue => e
    log("point error: #{e.message}")
    false
  end

  def self.stop
    return unless @available && @playing
    BeaconLib.beacon_stop rescue nil
    @playing = false
  end
end

#===============================================================================
# Setting: Options -> Accessibility -> Directional Beacon (0 = Off, 1 = On)
#===============================================================================
class PokemonOptions
  attr_accessor :beaconEnabled
  if method_defined?(:fixMissingValues) && !method_defined?(:pra_beacon_fix_missing)
    alias pra_beacon_fix_missing fixMissingValues
    def fixMissingValues
      pra_beacon_fix_missing
      @beaconEnabled = 0 if @beaconEnabled.nil?
    end
  end
end

class PokemonBlindstepOptionScene < PokemonOptionScene
  unless method_defined?(:pra_beacon_init_options)
    alias pra_beacon_init_options initOptions
    def initOptions
      optionList = pra_beacon_init_options
      insert_index = optionList.find_index { |opt| opt.name == _INTL("Accessibility Volume") } || 0
      optionList.insert(insert_index, EnumOption.new(
        _INTL("Directional Beacon"), [_INTL("Off"), _INTL("On")],
        proc { $Settings.beaconEnabled },
        proc { |value| $Settings.beaconEnabled = value },
        "Guides you to the selected map target with a 3D beacon. Scroll targets with J and L, then press Shift and B to start or stop guiding."
      ))
      return optionList
    end
  end
end

#===============================================================================
# Beacon state
#===============================================================================
module PraBeacon
  # Fallback (non-HRTF) directional step sounds + pan [x, z].
  DIR_SOUND = { "left" => "Blindstep- Footstep_L", "right" => "Blindstep- Footstep_R",
                "up" => "Blindstep- Footstep_U", "down" => "Blindstep- Footstep_D" }
  DIR_PAN   = { "left" => [-1.0, 0.0], "right" => [1.0, 0.0],
                "up" => [0.0, 1.0], "down" => [0.0, -1.0] }
  ARRIVED_SOUND = "Blindstep- Door"
  BASE_INTERVAL = 30
  MIN_INTERVAL  = 12
  NEAR_TILES    = 20.0

  class << self
    attr_accessor :active, :target, :counter, :no_path_announced
    attr_accessor :route_cache, :last_pos, :recalc
  end
  self.active = false
  self.target = nil
  self.counter = 0
  self.no_path_announced = false
  self.route_cache = nil
  self.last_pos = nil
  self.recalc = 0
end

#===============================================================================
# Player hook
#===============================================================================
class Game_Player < Game_Character
  unless method_defined?(:pra_beacon_original_update)
    alias_method :pra_beacon_original_update, :update
    def update
      pra_beacon_original_update
      pra_beacon_handle_input
      pra_beacon_tick
    end
  end

  def pra_beacon_enabled?
    $Settings && $Settings.respond_to?(:beaconEnabled) && $Settings.beaconEnabled == 1
  end

  def pra_beacon_handle_input
    return if $game_temp && ($game_temp.in_battle || $game_temp.message_window_showing)
    if Input.pressex?(0x10) && Input.triggerex?(0x42) # Shift + B
      pra_beacon_toggle
    end
  end

  def pra_beacon_toggle
    unless pra_beacon_enabled?
      tts("Directional Beacon is off. Turn it on under Options, Accessibility.")
      return
    end
    if PraBeacon.active
      PraBeacon.active = false
      PraBeacon.target = nil
      PraBeaconAudio.stop
      tts("Beacon off.")
      return
    end
    tgt = pra_beacon_selected_target
    unless tgt
      tts("No target selected. Use J and L to pick one first.")
      return
    end
    PraBeaconAudio.init # lazy: sets up HRTF the first time, else beep fallback
    PraBeacon.target = tgt
    PraBeacon.active = true
    PraBeacon.counter = 0
    PraBeacon.no_path_announced = false
    PraBeacon.route_cache = nil
    PraBeacon.last_pos = nil
    PraBeacon.recalc = 0
    label = tgt[:name] && !tgt[:name].empty? ? tgt[:name] : "target"
    mode = PraBeaconAudio.available ? "3D beacon" : "beacon"
    tts("#{mode} tracking #{label}.")
  end

  def pra_beacon_selected_target
    return nil unless defined?(PraSession) && PraSession.respond_to?(:selected_event_index)
    idx = PraSession.selected_event_index
    list = PraSession.mapevents
    return nil if idx.nil? || idx < 0 || list.nil? || list[idx].nil?
    ev = list[idx]
    cands = (ev.respond_to?(:candidates) && ev.candidates) ? ev.candidates.map { |c| [c[0], c[1]] } : []
    # Prefer the name you actually hear when you press K.
    label = nil
    label = ev.custom_name if ev.respond_to?(:custom_name) && ev.custom_name
    label = (ev.name rescue nil) if label.nil? || label.to_s.strip.empty?
    real = (defined?(VirtualEvent) && ev.is_a?(VirtualEvent)) ? nil : ev
    { map_id: $game_map.map_id, x: ev.x, y: ev.y, candidates: cands, name: label, event: real }
  end

  def pra_beacon_route
    t = PraBeacon.target
    return [] unless t && t[:map_id] == $game_map.map_id
    # The pathfinder's shared search, so P and the beacon always agree on
    # whether a target is reachable. The code below is the fallback for a
    # pathfinder too old to have it.
    if respond_to?(:a11y_best_route)
      return a11y_best_route(t[:x], t[:y], t[:candidates], t[:event])
    end
    if t[:candidates] && !t[:candidates].empty?
      t[:candidates].each do |tile|
        r = aStern(Node.new(@x, @y), Node.new(tile[0], tile[1]))
        return r unless r.empty?
      end
    end
    r = aStern(Node.new(@x, @y), Node.new(t[:x], t[:y]))
    return r unless r.empty?
    [[t[:x] + 1, t[:y]], [t[:x] - 1, t[:y]], [t[:x], t[:y] + 1], [t[:x], t[:y] - 1]].each do |ax, ay|
      alt = aStern(Node.new(@x, @y), Node.new(ax, ay))
      return alt unless alt.empty?
    end
    []
  rescue
    []
  end

  def pra_beacon_tick
    return unless pra_beacon_enabled? && PraBeacon.active && PraBeacon.target
    return if $game_temp && ($game_temp.in_battle || $game_temp.message_window_showing)

    t = PraBeacon.target
    if t[:map_id] != $game_map.map_id
      tts("Beacon target is on another map. Beacon off.")
      PraBeacon.active = false; PraBeacon.target = nil; PraBeaconAudio.stop
      return
    end

    dist = Math.sqrt((t[:x] - @x)**2 + (t[:y] - @y)**2)
    if (t[:x] - @x).abs <= 1 && (t[:y] - @y).abs <= 1
      PraBeaconAudio.stop
      pbAccessibilitySEPlay(PraBeacon::ARRIVED_SOUND, nil, 100, x: 0, y: 0, z: 0)
      tts("Arrived.")
      PraBeacon.active = false; PraBeacon.target = nil
      PraBeacon.route_cache = nil; PraBeacon.last_pos = nil
      return
    end

    PraBeacon.recalc = PraBeacon.recalc.to_i + 1
    moved = (PraBeacon.last_pos != [@x, @y])
    rc = PraBeacon.route_cache

    # Walking ALONG the route costs nothing: stepping onto its next tile just
    # consumes that tile. The full search only runs when the route is stale,
    # missing, or you wander off it. Before this, every single step re-ran
    # the search - and with no path, several failed full-map searches PER
    # STEP, forever (measured in the Desolation port as a big-map slowdown).
    if rc && !rc.empty? && moved && rc[0].x == @x && rc[0].y == @y
      rc.shift
      PraBeacon.last_pos = [@x, @y]
      PraBeacon.recalc   = 0
      moved = false
    end

    need = if PraBeacon.route_cache.nil?
             true
           elsif PraBeacon.no_path_announced
             # No path last time. Standing still cannot create one, so only
             # retry once the player has moved, and at most every 2 seconds.
             moved && PraBeacon.recalc >= 120
           elsif PraBeacon.route_cache.empty?
             true
           else
             moved || PraBeacon.recalc >= 60
           end
    if need
      PraBeacon.route_cache = pra_beacon_route
      PraBeacon.last_pos    = [@x, @y]
      PraBeacon.recalc      = 0
    elsif moved
      PraBeacon.last_pos = [@x, @y]
    end
    route = PraBeacon.route_cache
    if route.nil? || route.empty?
      if dist <= 2.5
        PraBeaconAudio.stop
        pbAccessibilitySEPlay(PraBeacon::ARRIVED_SOUND, nil, 100, x: 0, y: 0, z: 0)
        tts("Arrived.")
        PraBeacon.active = false; PraBeacon.target = nil
        PraBeacon.route_cache = nil; PraBeacon.last_pos = nil
        return
      end
      PraBeaconAudio.stop
      unless PraBeacon.no_path_announced
        tts("No path to the beacon target from here.")
        PraBeacon.no_path_announced = true
      end
      return
    end
    PraBeacon.no_path_announced = false
    dir = findRelativeDirection(Node.new(@x, @y), route[0])

    # HRTF mode: continuously position a looping 3D source. Updated every tick
    # so the direction and loudness track you smoothly.
    if PraBeaconAudio.available
      PraBeaconAudio.point(route[0].x - @x, route[0].y - @y, dist)
      return
    end

    # Fallback mode: throttled directional step-sound beeps.
    closeness = 1.0 - [dist / PraBeacon::NEAR_TILES, 1.0].min
    interval = (PraBeacon::BASE_INTERVAL - (PraBeacon::BASE_INTERVAL - PraBeacon::MIN_INTERVAL) * closeness).to_i
    PraBeacon.counter += 1
    return if PraBeacon.counter < interval
    PraBeacon.counter = 0
    sound = PraBeacon::DIR_SOUND[dir]
    pan = PraBeacon::DIR_PAN[dir] || [0.0, 0.0]
    pbAccessibilitySEPlay(sound, nil, 100, x: pan[0], y: 0, z: pan[1]) if sound
  rescue
  end
end

#===============================================================================
# The beacon PAUSES for battles. Game_Player#update stops running the moment a
# battle begins, so the tick above can never silence the loop - the 3D tone
# would drone through the whole fight. Every battle, wild or trainer, starts
# through the battle scene's pbStartBattle (Reborn's Events.onStartBattle
# fires for wild battles only), so the pause rides that. PraBeacon.active and
# the target are left alone: the first map tick after the battle points the
# source again and the loop restarts by itself - a pause, not a cancel.
# Ported from the Desolation fix a player confirmed.
#===============================================================================
if defined?(PokeBattle_Scene) && PokeBattle_Scene.method_defined?(:pbStartBattle)
  class PokeBattle_Scene
    unless method_defined?(:pra_beacon_start_battle)
      alias_method :pra_beacon_start_battle, :pbStartBattle
      def pbStartBattle(*args)
        begin
          PraBeaconAudio.stop
        rescue Exception
        end
        pra_beacon_start_battle(*args)
      end
    end
  end
end
