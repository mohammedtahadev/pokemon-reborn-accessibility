# pra-walk.rb - auto-walk
#
# ORIGINAL WORK: Lorenzo (fclorenzo), pkreborn-access
#   https://github.com/fclorenzo/pkreborn-access  (mods/pra-walk.rb)
#   Licensed under the GNU General Public License v3.0 - see LICENSE.
#
# THIS IS A MODIFIED VERSION (GPL-3.0 section 5a notice), changed by
# Mohammed Taha (mohammedtahadev), 2026-10-26: ONE change, a reload guard on
# the Game_Player#update hook. Reborn's F12 soft reset re-runs every mod, and
# without the guard the alias is re-made onto this file's own method, so
# moving on the map calls itself forever ("stack level too deep"). Reported
# upstream; this copy exists only until the fix lands there, and nothing else
# about the mod is changed.

#===============================================================================
# Auto-Walk Logic for Accessibility Pathfinding
#===============================================================================
# This mod handles the mechanics of automatically moving the player along a path.
# Key inputs are handled by the main pathfinding mod to ensure cohesion.
#===============================================================================

# Initialize the global toggle if it doesn't exist
$auto_walk = false if !$auto_walk

class Game_Player < Game_Character
  # RELOAD GUARD (added by the accessibility pack): Reborn's F12 soft reset
  # re-runs every file in patch/Mods in the same Ruby VM. Re-making this alias
  # on the second load would point it at this file's own previous definition,
  # so the method would call itself forever - "stack level too deep" on the
  # next step, hit or options screen. Install the hook once.
  unless method_defined?(:access_mod_walk_original_update)
    alias_method :access_mod_walk_original_update, :update
  end

  def update
    # 1. Run the original game logic first
    access_mod_walk_original_update

    # 2. Check Auto-Walk Logic
    if defined?($auto_walk) && $auto_walk
      
      # --- A. ENCOUNTER RATE BACKUP ---
      # We use a persistent instance variable to store the original rate.
      # This ensures we don't lose the player's original setting.
      if @pra_saved_encounter_modifier.nil?
        # Default to 1.0 (standard rate) if the variable returns nil
        current_rate = $game_variables[:EncounterRateModifier]
        @pra_saved_encounter_modifier = current_rate.nil? ? 1.0 : current_rate
        
        # Set encounters to 0 (Disable them)
        $game_variables[:EncounterRateModifier] = 0
      end

      # --- B. DESTINATION CHECK ---
      # Only disable if we had a route and it is now finished.
      if !@current_autowalk_route.nil? && @current_autowalk_route.empty?
        $auto_walk = false
        @current_autowalk_route = nil # Reset to nil
        tts("Destination reached.")
        
        # Restore encounter rates immediately
        if @pra_saved_encounter_modifier
           $game_variables[:EncounterRateModifier] = @pra_saved_encounter_modifier
           @pra_saved_encounter_modifier = nil
        end
        return
      end

      # --- C. WALK ---
      unless $game_temp.in_battle || $game_temp.message_window_showing
        follow_autowalk_path
      end

    else
      # --- D. SAFETY RESTORE ---
      # This block runs if Auto-Walk is OFF. 
      # It catches cases where you manually stopped walking (e.g., pressed J).
      # If we still have a saved rate, restore it now so the game returns to normal.
      if @pra_saved_encounter_modifier
        $game_variables[:EncounterRateModifier] = @pra_saved_encounter_modifier
        @pra_saved_encounter_modifier = nil
      end
    end
  end

# Clear the route silently (used on game load)
  def clear_autowalk_route
    @current_autowalk_route = nil
  end

  # Store a new route for auto-walking
  def start_autowalk(route)
    @current_autowalk_route = route
    tts("Auto-walking...")
  end

  # Actually consume the route and move tile by tile
  def follow_autowalk_path
    return if @current_autowalk_route.nil? || @current_autowalk_route.empty?

    # 1. Check if we have arrived at the current target node
    target = @current_autowalk_route.first
    
    if @x == target.x && @y == target.y
      # We are at the target, remove it from the list
      @current_autowalk_route.shift
      
      # If the route is now empty, return. The Safety Check in 'update' will 
      # handle disabling the toggle on the next frame.
      return if @current_autowalk_route.empty?
      
      # Update target to the next node
      target = @current_autowalk_route.first
    end

    # 2. Check if we are Adjacent + Blocked for the Final Step
    if @current_autowalk_route.length == 1
      dx = target.x - @x
      dy = target.y - @y
      
      # Check if strictly adjacent (distance 1)
      if dx.abs + dy.abs == 1
        # Determine the direction we are trying to go
        dir = 0
        dir = 6 if dx == 1
        dir = 4 if dx == -1
        dir = 2 if dy == 1
        dir = 8 if dy == -1
        
        # Check if passage is blocked
        if !passableEx?(@x, @y, dir)
           # We are stuck next to the final target. Assume we reached the interaction point.
           @current_autowalk_route.shift
           return
        end
      end
    end

    # 3. Issue the move command
    return if moving?

    dx = target.x - @x
    dy = target.y - @y

    if dx > 0
      move_right
    elsif dx < 0
      move_left
    elsif dy > 0
      move_down
    elsif dy < 0
      move_up
    end
  end
end
