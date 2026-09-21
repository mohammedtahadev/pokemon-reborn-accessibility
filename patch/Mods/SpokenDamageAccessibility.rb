# Spoken Damage accessibility patch (drop into patch/Mods)
# Reborn 19.5.x compatible
# By Mohammed Taha (mohammedtahadev)
# https://github.com/mohammedtahadev/pokemon-reborn-accessibility
#
# Speaks the exact damage every hit deals and the HP left, from any source.
# Options -> Accessibility -> Spoken Damage turns it on or off.

class PokemonOptions
  attr_accessor :spokenDamage

  alias spoken_damage_fix_missing_values fixMissingValues
  def fixMissingValues
    spoken_damage_fix_missing_values
    @spokenDamage = 0 if @spokenDamage.nil? # 0=On, 1=Off
  end
end

class PokemonBlindstepOptionScene < PokemonOptionScene
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

class PokeBattle_Move
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
