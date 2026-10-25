# Spoken Damage accessibility patch (drop into patch/Mods)
# Reborn 19.5.x compatible
# By Mohammed Taha (mohammedtahadev)
# https://github.com/mohammedtahadev/pokemon-reborn-accessibility
#
# Speaks the exact damage every hit deals and the HP left, from any source.
# Options -> Accessibility -> Spoken Damage turns it on or off.
#
# RELOAD GUARDS
# -------------
# Every hook below is wrapped in "unless method_defined?". Reborn's F12 soft
# reset re-runs every file in patch/Mods inside the SAME Ruby VM, so without
# the guard the alias would be made a second time and would then point at
# THIS file's own previous definition - a method calling itself forever.
# After one soft reset that broke "stack level too deep" in three places at
# once: the Accessibility options screen (so the Directional Beacon row
# vanished), the settings defaults (so the beacon could not be switched on),
# and every hit taken in battle. Install each hook once and only once.

class PokemonOptions
  attr_accessor :spokenDamage

  unless method_defined?(:spoken_damage_fix_missing_values)
    alias spoken_damage_fix_missing_values fixMissingValues
    def fixMissingValues
      spoken_damage_fix_missing_values
      @spokenDamage = 0 if @spokenDamage.nil? # 0=On, 1=Off
    end
  end
end

class PokemonBlindstepOptionScene < PokemonOptionScene
  unless method_defined?(:spoken_damage_init_options)
    alias spoken_damage_init_options initOptions
    def initOptions
      optionList = spoken_damage_init_options
      insert_index = optionList.find_index { |opt| opt.name == _INTL("Accessibility Volume") } || 0
      optionList.insert(insert_index, EnumOption.new(
        _INTL("Spoken Damage"), [_INTL("On"), _INTL("Off")],
        proc { $Settings.spokenDamage },
        proc { |value| $Settings.spokenDamage = value },
        "Speaks exact damage dealt and remaining HP during battle."
      ))
      return optionList
    end
  end
end

class PokeBattle_Battle
  def pbSpeakDamage(target, damage)
    return if !target || !damage || damage <= 0
    return if !$Settings || !$Settings.respond_to?(:spokenDamage) || $Settings.spokenDamage != 0

    if target.hp <= 0
      tts(_INTL("{1} took {2} damage and fainted.", target.pbThis, damage))
    else
      tts(_INTL("{1} took {2} damage. {3} HP left.", target.pbThis, damage, target.hp))
    end
  end
end

class PokeBattle_Battler
  unless method_defined?(:spoken_damage_pbReduceHP)
    alias spoken_damage_pbReduceHP pbReduceHP
    def pbReduceHP(amt, anim = false, emercheck = true)
      oldhp = self.hp
      dealt = spoken_damage_pbReduceHP(amt, anim, emercheck)
      if self.battle && self.battle.respond_to?(:pbSpeakDamage)
        actual = oldhp - self.hp
        self.battle.pbSpeakDamage(self, actual) if actual > 0
      end
      return dealt
    end
  end
end

class PokeBattle_Move
  unless method_defined?(:spoken_damage_pbReduceHPDamage)
    alias spoken_damage_pbReduceHPDamage pbReduceHPDamage
    def pbReduceHPDamage(damage, attacker, opponent)
      oldhp = opponent ? opponent.hp : nil
      dealt = spoken_damage_pbReduceHPDamage(damage, attacker, opponent)
      if opponent && @battle && @battle.respond_to?(:pbSpeakDamage) && oldhp
        actual = oldhp - opponent.hp
        @battle.pbSpeakDamage(opponent, actual) if actual > 0
      end
      return dealt
    end
  end
end
