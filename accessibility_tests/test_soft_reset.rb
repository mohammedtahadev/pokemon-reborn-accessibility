# Soft reset (F12) regression test.
#
# Reborn's F12 reset re-runs its own scripts AND every file in patch/Mods, in
# the same Ruby VM. A hook whose alias is re-made on that second load ends up
# pointing at its own previous definition, so the method calls itself forever.
# A player found this the hard way: after a soft reset the Directional Beacon
# row was gone from Options -> Accessibility and the beacon would not switch
# on, because three separate things were dying with "stack level too deep" -
# the options list, the settings defaults, and every hit taken in battle.
#
# This loads the real mods three times - a first start and two soft resets -
# and checks that the option rows, the settings defaults, moving on the map
# and taking damage all still work every time.
#
#   ruby test_soft_reset.rb <path to your Reborn folder>
#
# Point it at a Reborn install that has this pack and Lorenzo's mods in
# patch/Mods. Nothing is written; the game is only read.

$pass = 0; $fail = 0
def check(c, n); c ? ($pass += 1; puts "PASS: #{n}") : ($fail += 1; puts "FAIL: #{n}"); end

ROOT = ARGV[0] || File.expand_path("../..", __dir__)
MODS = File.join(ROOT, "patch", "Mods")
unless File.directory?(MODS)
  puts "No patch/Mods in #{ROOT} - pass your Reborn folder as the argument."
  exit 2
end

# ── Just enough of Reborn to load the mods ──────────────────────────────────
def _INTL(s, *a); a.each_with_index { |v, i| s = s.gsub("{#{i + 1}}", v.to_s) }; s; end
def tts(*a); end
def pbPlayCursorSE; end
def pbPlayDecisionSE; end
def pbPlayCancelSE; end
def pbAccessibilitySEPlay(*a, **k); end
def pbGetMapNameFromId(id); ""; end
def pbIsPassableWaterTag?(t); false; end

class EnumOption
  attr_reader :name
  def initialize(name, *rest); @name = name; end
end

# The game's own options screen. A soft reset reopens this class and
# redefines the method; it does not replace the class, so whatever the mods
# added to it survives - which is exactly what makes a repeated alias
# dangerous.
class PokemonOptionScene; end
def run_base_scripts
  PokemonOptionScene.class_eval do
    def initOptions
      [EnumOption.new("Text Speed"), EnumOption.new("Accessibility Volume")]
    end
  end
end

class PokemonOptions
  attr_accessor :beaconEnabled, :spokenDamage, :aiStarter
  def fixMissingValues; end
end
$Settings = PokemonOptions.new

class Game_Character
  attr_accessor :x, :y, :direction, :through, :character_name
  def initialize; @x = 0; @y = 0; @direction = 2; @through = false; @character_name = ""; end
  def update; end
  def moving?; false; end
  def map; $game_map; end
  def passable?(x, y, d); true; end
  def screen_x; 0; end
  def screen_y; 0; end
end
class Game_Player < Game_Character; end
class Scene_Map; def main; end; def update; end; end

# The party screen, which the accessible summary wraps.
class PokemonScreen
  def pbPokemonScreen; :original; end
end
class PokemonStorageScreen
  def pbStartScreen(mode); :original; end
end

class PokeBattle_Battler
  attr_accessor :hp, :totalhp, :battle
  def initialize; @hp = 50; @totalhp = 50; end
  def pbThis(lower = false); "Growlithe"; end
  def pbReduceHP(amt, anim = false, emercheck = true); @hp -= amt; amt; end
end
class PokeBattle_Move
  attr_accessor :battle
  def pbReduceHPDamage(damage, attacker, opponent); damage; end
end
class PokeBattle_Battle; end

class GameTemp; attr_accessor :in_battle, :message_window_showing; end
$game_temp = GameTemp.new
class GameSwitches; def [](k); false; end; def []=(k, v); end; end
$game_switches = GameSwitches.new
class GameVariables; def [](k); 0; end; def []=(k, v); end; end
$game_variables = GameVariables.new
class GameSystem; end
$game_system = GameSystem.new
class GameMap
  def map_id; 1; end
  def events; {}; end
  def width; 20; end
  def height; 20; end
  def name; "Test"; end
  def valid?(x, y); true; end
  def terrain_tag(x, y); 13; end
  def passable?(*a); true; end
  def passableStrict?(*a); true; end
end
$game_map = GameMap.new
module Input
  def self.pressex?(k); false; end
  def self.triggerex?(k); false; end
  def self.trigger?(k); false; end
  def self.repeat?(k); false; end
  def self.update; end
end
module Graphics
  def self.update; end
  def self.width; 512; end
  def self.height; 384; end
end
module Kernel
  def self.pbMessage(*a); 0; end
  def self.pbMessageFreeText(*a); ""; end
  def self.pbOnStepTaken(*a); end
end
class MapFactoryStub
  def getMap(id); nil; end
  def getNewMap(x, y); nil; end
  def isPassable?(*a); true; end
end
$MapFactory = MapFactoryStub.new
module MapFactoryHelper
  def self.getMapConnections; []; end
  def self.getMapDims(id); [20, 20]; end
end
class PBTerrain
  Ledge = 1; Water = 7; DeepWater = 5; StillWater = 6
  Waterfall = 8; WaterfallCrest = 9
end
class PokemonTempStub; end
$PokemonTemp = PokemonTempStub.new

# Every mod in the folder that hooks something, in the order the game loads
# them. Missing files are skipped, so this works on an install that has only
# some of them.
WANTED = ["SpokenDamageAccessibility.rb", "pra-accessible-summary.rb",
          "pra-ai-starter.rb", "pra-beacon.rb", "pra-pathfind.rb", "pra-walk.rb"]

def load_all
  errors = []
  run_base_scripts
  WANTED.each do |f|
    path = File.join(MODS, f)
    next unless File.exist?(path)
    begin
      load path
    rescue Exception => e
      errors << "#{f}: #{e.class}: #{e.message.to_s[0, 50]}"
    end
  end
  errors
end

def works?
  rows = PokemonBlindstepOptionScene.new.initOptions.map(&:name)
  $Settings.fixMissingValues
  Game_Player.new.update
  b = PokeBattle_Battler.new
  b.battle = PokeBattle_Battle.new
  b.pbReduceHP(5)
  rows
rescue Exception => e
  e
end

["a first start", "after one soft reset", "after a second soft reset"].each_with_index do |label, i|
  errors = load_all
  check errors.empty?, "#{label}: every mod loads#{errors.empty? ? "" : " (#{errors.join("; ")})"}"
  result = works?
  if result.is_a?(Exception)
    check false, "#{label}: the game still works (#{result.class}: #{result.message.to_s[0, 40]})"
  else
    check true, "#{label}: options, settings, a step on the map and a hit in battle all still work"
    check result.include?("Directional Beacon"),
          "#{label}: the Directional Beacon row is in Options -> Accessibility"
    if File.exist?(File.join(MODS, "SpokenDamageAccessibility.rb"))
      check result.include?("Spoken Damage"), "#{label}: and the Spoken Damage row"
    end
  end
end

puts "=" * 60
puts " RESULTS: #{$pass} passed, #{$fail} failed"
puts "=" * 60
exit($fail == 0 ? 0 : 1)
