require 'curses'

class Player
  attr_accessor :inventory, :pos_x, :pos_y, :hp, :dmg, :game

  def initialize game
    @steps = 0
    @inventory = Hash.new
    @pos_x = 0
    @pos_y = 0
    @hp = 100
    @dmg = 3
    @game = game
  end

  def add_to_inventory item
    if self.inventory[item] == nil
      self.inventory[item] = 1
    else
      self.inventory[item] += 1
    end
  end

  def figure
    return "@"
  end

  def move direction, value
    @game.level[pos_x][pos_y] = " "
    @steps+=value.abs
    @game.log << "#{Time.now.strftime "%H:%M:%S"} p moves #{direction} #{value}"
    case direction
      when :x then @pos_x += value
      when :y then @pos_y += value
    end
    @game.level[pos_x][pos_y] = self.figure
  end

  def receive_damage dmg
    self.hp -= dmg
    if hp <= 0
      self.is_dead = true
    end
  end

  def hit c, dmg
    c.receive_damage dmg
    @game.log << "Player hits creature, dmg: #{self.dmg}"
  end

  def behaviour_on_direction direction, value
    next_pos = {x: self.pos_x, y: self.pos_y}
    if direction == :x
      next_pos[:x] += value
    elsif direction == :y
      next_pos[:y] += value
    end

    @game.log << "next is: #{@game.level[next_pos[:x]][next_pos[:y]]}"
    if @game.class.areas_player_able_to_walk.include? @game.level[next_pos[:x]][next_pos[:y]]
      @game.log << @game.class.areas_player_able_to_walk
      self.move direction, value
    elsif @game.level[next_pos[:x]][next_pos[:y]] == Chest::close_chest_figure
      @game.level[next_pos[:x]][next_pos[:y]] = Chest::open_chest_figure
      self.add_to_inventory self.game.item_from_chest(next_pos[:x], next_pos[:y])
    elsif @game.level[next_pos[:x]][next_pos[:y]] == @game.class.next_level
      #TODO: should be next level
      exit 0
    elsif @game.level[next_pos[:x]][next_pos[:y]] == Creature::normal_figure
      c = @game.find_creature_by_position next_pos[:x], next_pos[:y]
      self.hit c, self.dmg
    end
  end
end

class Chest
  attr_accessor :item, :is_open, :pos_x, :pos_y

  def initialize item, pos_x, pos_y
    self.item = item
    self.is_open = false
    self.pos_x = pos_x
    self.pos_y = pos_y
  end

  def figure
    is_open ? self.class.close_chest_figure : self.class.open_chest_figure
  end

  def self.open_chest_figure
    "]"
  end

  def self.close_chest_figure
    "c"
  end

end

class Creature
  attr_accessor :dmg, :hp, :pos_x, :pos_y, :is_dead

  def initialize game, pos_x, pos_y
    @dmg = 3
    @hp = 3
    @game = game
    @pos_x = pos_x
    @pos_y = pos_y
    @is_dead = false
  end

  def receive_damage dmg
    self.hp -= dmg
    if hp <= 0
      self.is_dead = true
      @game.level[pos_x][pos_y] = self.figure
    end
  end

  def hit_player
    @game.player.receive_damage self.dmg
    @game.log << "Creature hits player, dmg: #{self.dmg}"
  end

  def do_action
    return if is_dead || (hp <= 0)
    old_pos_x = @pos_x
    old_pos_y = @pos_y
    vec = {
      x: @game.player.pos_x - @pos_x,
      y: @game.player.pos_y - @pos_y
    }

    #hit if in next to player
    if (vec[:x] == 0 && vec[:y].abs == 1) || (vec[:y] == 0 && vec[:x].abs == 1)
      @game.log << "#{Time.now.strftime "%H:%M:%S"} Creature hits player, dmg: #{dmg}"
      #TODO: THIS IS SO UGLY!!!
      self.hit_player
    elsif vec[:x].abs > 0 && vec[:y]==0
      v = (vec[:x] > 0 ? 1 : -1)
      self.move :x, v
    elsif vec[:y].abs > 0 && vec[:x]==0
      v = (vec[:y] > 0 ? 1 : -1)
      self.move :y, v
    else
      if Random.rand > 0.5
        v = (vec[:y] > 0 ? 1 : -1)
        if @game.level[@pos_x][@pos_y+v] == " "
          self.move :y, v
        end
      else
        v = (vec[:x] > 0 ? 1 : -1)
        if @game.level[@pos_x+v][@pos_y] == " "
          self.move :x, v
        end
      end
    end
    @game.level[old_pos_x][old_pos_y] = " "
    @game.level[@pos_x][@pos_y] = "m"
  end

  def move direction, value
    @game.level[pos_x][pos_y] = " "
    case direction
    when :x then
      return if @game.level[pos_x+value][pos_y] != " "
      @pos_x += value
    when :y then
      return if @game.level[pos_x][pos_y+value] != " "
      @pos_y += value
    end
    @game.log << "#{Time.now.strftime "%H:%M:%S"} c moves #{direction} #{value}"
  end

  def figure
    if hp <= 0
      return self.class.dead_creature_figure
    else
      return self.class.normal_figure
    end
  end

  def self.dead_creature_figure
    return ","
  end

  def self.normal_figure
    return "m"
  end
end

class Game
  attr_accessor :level, :player, :creatures, :chests, :info_window, :player_window, :log

  @@chest = "c"
  @@open_chest = "^"
  @@next_level = "N"
  @@start_position = "W"
  @@creature = Creature::normal_figure

  def initialize
    @level = self.class.read_maze_from_file "levels/1.lvl"
    @player = Player.new self
    pos = self.class.find_val_in_arr @level, @@start_position
    @player.pos_x = pos[:x]
    @player.pos_y = pos[:y]
    @creatures = self.find_creatures_in_level @level, @@creature
    @chests = self.find_chests_in_level @level
    @log = []
  end

  def refresh_screens
    line = 0
    @info_window.clear
    @player_window.clear
    @info_window.box("|", "-", "#")
    @info_window.setpos((line+=1), 1)
    @info_window.addstr("pos: {x: #{@player.pos_x}, y: #{@player.pos_y}}")
    @info_window.setpos((line+=1), 1)
    @info_window.addstr("player:")
    @info_window.setpos((line+=1), 1)
    @info_window.addstr("dmg: #{@player.dmg}, hp: #{@player.hp}, pos_x: #{@player.pos_x}, pos_y: #{@player.pos_y}")
    @info_window.setpos((line+=1), 1)
    @info_window.addstr("inventory:")
    @player.inventory.each do |item, count|
      @info_window.setpos((line+=1), 1)
      @info_window.addstr("#{item}, c: #{count}")
    end
    @info_window.setpos((line+=1), 1)
    @info_window.addstr("creatures:")
    @creatures.each do |creature|
      @info_window.setpos((line+=1), 1)
      @info_window.addstr("dmg: #{creature.dmg}, hp: #{creature.hp}, pos_x: #{creature.pos_x}, pos_y: #{creature.pos_y}")
    end
    @log.last(10).each do |l|
      @info_window.setpos((line+=1), 1)
      @info_window.addstr("##{l}")
    end
    @info_window.refresh

    #LEVEL
    x = 0
    y = 0
    @level.each do |l|
      l.each do |p|
        @player_window.setpos(x,y)
        el = Game::replace_places p
        @player_window << el
        y+=1
      end
      y=0
      x+=1
    end


    #CREATURES
    creatures.each do |creature|
      @player_window.setpos(creature.pos_x, creature.pos_y)
      @player_window << creature.figure
    end

    #PLAYER
    @player_window.setpos(@player.pos_x, @player.pos_y)
    @player_window << @player.figure

    @player_window.refresh
  end

  def run
    Curses.init_screen
    Curses.noecho
    Curses.stdscr.keypad = true
    Curses.curs_set(0)  # Invisible cursor
    # Curses.timeout = 1

    @info_window = Curses::Window.new(30, 40, @level.count+1, 0)
    @player_window = Curses::Window.new(@level.count+1, @level[0].count+1, 0, 0)

    loop do
      refresh_screens
      input = Curses.getch
      # @player_window.addch ?\n
      #player moves
      case input
      when Curses::KEY_UP
        @player.behaviour_on_direction :x, -1
      when Curses::KEY_DOWN
        @player.behaviour_on_direction :x,  1
      when Curses::KEY_LEFT
        @player.behaviour_on_direction :y, -1
      when Curses::KEY_RIGHT
        @player.behaviour_on_direction :y,  1
      end
      #creatures moves
      creatures.each do |creature|
        creature.do_action
      end
    end
    @player_window.close
    @info_window.close
  end

  def item_from_chest pos_x, pos_y
    #TODO: figure something out
    return "sword"
  end

  def self.find_val_in_arr array, value
    array.each_with_index do |line, x|
      line.each_with_index do |i, y|
        return {x: x, y: y} if i == value
      end
    end
  end

  def find_creatures_in_level level, monster_letter
    arr = []
    self.level.each_with_index do |line, x|
      line.each_with_index do |el, y|
        if el == monster_letter
          arr << Creature.new(self, x, y)
          level[x][y] = 'm'
        end
      end
    end
    arr
  end

  def self.read_maze_from_file file
    arr = []
    text = File.open(file).read
    text.gsub!(/\r\n?/, "\n")
    text.each_line do |line|
      arr << line.gsub!("\n", "").split("")
    end
    arr
  end

  def find_creature_by_position pos_x, pos_y
    @creatures.each do |creature|
      return creature if creature.pos_x == pos_x && creature.pos_y == pos_y
    end
  end

  def find_chest_by_position pos_x, pos_y
    @chests.each do |chest|
      return chest if chest.pos_x == pos_x && chest.pos_y == pos_y
    end
  end

  def find_chests_in_level level
    arr = []
    level.each_with_index do |line, x|
      line.each_with_index do |el, y|
        if el == @@chest
          arr << Chest.new("sword", x, y)
        end
      end
    end
    arr
  end

  def self.next_level
    return @@next_level
  end

  def self.start_position
    return @@start_position
  end

  def self.areas_player_able_to_walk
    return [Creature::dead_creature_figure, " "]
  end

  def self.doors
    "D"
  end

  def self.replace_places place
    if ["1", "2", "3", "4", "5", "6", "7", "8", "9"].include? place
      return self.doors
    else
      return place
    end
  end

end

g = Game.new
g.run
