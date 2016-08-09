require 'curses'

class Player
  attr_accessor :inventory, :pos_x, :pos_y, :hp, :dmg, :game

  def initialize game
    @steps = 0
    @inventory = Hash.new
    @pos_x = 0
    @pos_y = 0
    @hp = 10
    @dmg = 1
    @game = game
  end

  def damage
    return 2
  end

  def add_to_inventory item
    if self.inventory[item] == nil
      self.inventory[item] = 1
    else
      self.inventory[item] += 1
    end
  end

  def figure
    "o"
  end

  def move direction, value
    @game.level[pos_x][pos_y] = " "
    @steps+=value.abs
    @game.log << "p moves #{direction} #{value}"
    case direction
    when :x then self.pos_x += value
    when :y then self.pos_y += value
    end
    @game.level[pos_x][pos_y] = self.figure
  end
end

class Creature
  attr_accessor :dmg, :hp, :pos_x, :pos_y

  def initialize game, pos_x, pos_y
    @dmg = 3
    @hp = 3
    @game = game
    @pos_x = pos_x
    @pos_y = pos_y
  end

  def move_towards_player
    #TODO move to player
    @game.level[pos_x][pos_y] = " "
    vec = {
      x: @game.player.pos_x - @pos_x,
      y: @game.player.pos_y - @pos_y,
    }
    if (vec[:x] == 0 && vec[:y] == 1) || (vec[:y] == 0 && vec[:x] == 1)
      @game.log << "Creature hits player, dmg: #{dmg}"
    elsif vec[:x].abs < vec[:y].abs
      v = (vec[:y] > 0 ? 1 : -1)
      if @game.level[@pos_x][@pos_y+v] == " "
        self.move :y, v
      end
    elsif vec[:x].abs > vec[:y].abs
      v = (vec[:x] > 0 ? 1 : -1)
      if @game.level[@pos_x+v][@pos_y] == " "
        self.move :x, v
      end
    elsif vec[:x].abs == vec[:y].abs
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
    @game.level[@pos_x][@pos_y] = "m"
  end

  def move direction, value
    @game.log << "c moves #{direction} #{value}"
    case direction
    when :x then @pos_x += value
    when :y then @pos_y += value
    end
  end

  def figure
    "m"
  end
end

class Game
  attr_accessor :level, :player, :creatures, :info_window, :player_window, :log

  @@chest = "c"
  @@open_chest = "^"
  @@next_level = "N"
  @@start_position = "W"
  @@creature = "m"

  def initialize
    @level = self.class.read_maze_from_file "levels/1.lvl"
    @player = Player.new self
    pos = self.class.find_val_in_arr @level, @@start_position
    @player.pos_x = pos[:x]
    @player.pos_y = pos[:y]
    @creatures = self.find_monsters_in_level @level, @@creature
    @log = []
  end

  def refresh_screens
    @info_window.clear
    @info_window.box("|", "-", "x")
    line = 0
    @info_window.setpos((line+=1), 1)
    @info_window.addstr("pos: {x: #{@player.pos_x}, y: #{@player.pos_y}}")
    @info_window.setpos((line+=1), 1)
    @info_window.addstr("dmg: #{@player.dmg}, hp: #{@player.hp}")
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
    @player_window.refresh
  end

  def run
    Curses.init_screen
    # Curses.noecho
    Curses.stdscr.keypad = true
    Curses.curs_set(0)  # Invisible cursor
    # Curses.timeout = 1
    @info_window = Curses::Window.new(20, 40, 0, 0)
    @player_window = Curses::Window.new(@level.count+1, @level[0].count+1, 30, 0)
    refresh_screens
    loop do
      x = 0
      y = 0
      @level.each do |line|
        line.each do |p|
          @player_window.setpos(x,y)
          @player_window << p
          y+=1
        end
        y=0
        x+=1
      end
      @player_window.setpos(@player.pos_x, @player.pos_y)
      @player_window << @player.figure
      refresh_screens

      creatures.each do |creature|
        @player_window.setpos(creature.pos_x, creature.pos_y)
        @player_window << creature.figure
        refresh_screens
      end
      input = Curses.getch
      @player_window.addch ?\n
      #player moves
      case input
      when Curses::KEY_UP
        if @level[@player.pos_x-1][@player.pos_y] == " "
          @player.move :x, -1
        elsif @level[@player.pos_x-1][@player.pos_y] == @@chest
          @level[@player.pos_x-1][@player.pos_y] = @@open_chest
          @player.add_to_inventory item_from_chest
        elsif @level[@player.pos_x-1][@player.pos_y] == @@next_level
          #TODO: should be next level
          exit 0
        elsif @level[@player.pos_x-1][@player.pos_y] == @@creature
          self.log << "Player hits creature, dmg: #{@player.dmg}"
        end
      when Curses::KEY_DOWN
        if @level[@player.pos_x+1][@player.pos_y] == " "
          @player.move :x, +1
        elsif @level[@player.pos_x+1][@player.pos_y] == @@chest
          @level[@player.pos_x+1][@player.pos_y] = @@open_chest
          @player.add_to_inventory item_from_chest
        elsif @level[@player.pos_x+1][@player.pos_y] == @@next_level
          #TODO: should be next level
          exit 0
        elsif @level[@player.pos_x+1][@player.pos_y] == @@creature
          self.log << "Player hits creature, dmg: #{@player.dmg}"
        end
      when Curses::KEY_LEFT
        if @level[@player.pos_x][@player.pos_y-1] == " "
          @player.move :y, -1
        elsif @level[@player.pos_x][@player.pos_y-1] == @@chest
          @level[@player.pos_x][@player.pos_y-1] = @@open_chest
          @player.add_to_inventory item_from_chest
        elsif @level[@player.pos_x][@player.pos_y-1] == @@next_level
          #TODO: should be next level
          exit 0
        elsif @level[@player.pos_x][@player.pos_y-1] == @@creature
          self.log << "Player hits creature, dmg: #{@player.dmg}"
        end
      when Curses::KEY_RIGHT
        if @level[@player.pos_x][@player.pos_y+1] == " "
          @player.move :y, +1
        elsif @level[@player.pos_x][@player.pos_y+1] == @@chest
          @level[@player.pos_x][@player.pos_y+1] = @@open_chest
          @player.add_to_inventory item_from_chest
        elsif @level[@player.pos_x][@player.pos_y+1] == @@next_level
          #TODO: should be next level
          exit 0
        elsif @level[@player.pos_x][@player.pos_y+1] == @@creature
          self.log << "Player hits creature, dmg: #{@player.dmg}"
        end
      end
      #creatures moves
      creatures.each do |creature|
        creature.move_towards_player
        @player_window.setpos(creature.pos_x, creature.pos_y)
        @player_window << creature.figure
        refresh_screens
      end
    end
    @player_window.close
    @info_window.close
  end

  def item_from_chest
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

  def find_monsters_in_level level, monster_letter
    arr = []
    level.each_with_index do |line, x|
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

end

g = Game.new
g.run
