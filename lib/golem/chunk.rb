module Golem

  BLOCKS = {
    0  => :air,
    1  => :stone,
    2  => :grass,
    3  => :dirt,
    4  => :cobble,
    5  => :wood,
    6  => :sapling,
    7  => :bedrock,
    8  => :water,
    9  => :still_water,
    10 => :lava,
    11 => :still_lava,
    12 => :sand,
    13 => :gravel,
    14 => :gold_ore,
    15 => :iron_ore,
    16 => :coal_ore,
    17 => :log,
    18 => :leaves,
    19 => :sponge,
    20 => :glass,
    35 => :cloth,
    37 => :yellow_flower,
    38 => :red_rose,
    39 => :brown_mushroom,
    40 => :red_mushroom,
    41 => :gold_block,
    42 => :iron_block,
    43 => :double_step,
    44 => :step,
    45 => :brick,
    46 => :tnt,
    47 => :bookcase,
    48 => :mossy_cobble,
    49 => :obsidian,
    50 => :torch,
    51 => :fire,
    52 => :mob_spawner,
    53 => :wood_stairs,
    54 => :chest,
    55 => :redstone_wire,
    56 => :diamond_ore,
    57 => :diamond_block,
    58 => :workbench,
    59 => :crops,
    60 => :soil,
    61 => :furnace,
    62 => :burning_furnace,
    63 => :sign_post,
    64 => :wood_door,
    65 => :ladder,
    66 => :minecart_tracks,
    67 => :cobble_stairs,
    68 => :wall_sign,
    69 => :lever,
    70 => :stone_plate,
    71 => :iron_door,
    72 => :wood_plate,
    73 => :redstone_ore,
    74 => :glowing_redstone_ore,
    75 => :redstone_torch_off,
    76 => :redstone_torch_on,
    77 => :stone_button,
    78 => :snow,
    79 => :ice,
    80 => :snow_block,
    81 => :cactus,
    82 => :clay,
    83 => :reed,
    84 => :jukebox,
    85 => :fence,
    86 => :pumpkin,
    87 => :bloodstone,
    88 => :slow_sand,
    89 => :lightstone,
    90 => :portal,
    91 => :jack_o_lantern
  }

  SOLID = [
    :stone,
    :grass,
    :dirt,
    :cobble,
    :wood,
    :bedrock,
    # allow swimming
    # :water,
    # :still_water,
    :lava,
    :still_lava,
    :sand,
    :gravel,
    :gold_ore,
    :iron_ore,
    :coal_ore,
    :log,
    :leaves,
    :sponge,
    :glass,
    :cloth,
    :gold_block,
    :iron_block,
    # require special-casing
    # :double_step,
    # :step,
    :brick,
    :tnt,
    :bookcase,
    :mossy_cobble,
    :obsidian,
    :fire,
    :mob_spawner,
    # :wood_stairs,
    :chest,
    :diamond_ore,
    :diamond_block,
    :workbench,
    :soil,
    :furnace,
    :burning_furnace,
    :sign_post,
    :wood_door,
    # :minecart_tracks,
    # :cobble_stairs,
    :iron_door,
    :redstone_ore,
    :glowing_redstone_ore,
    :snow,
    # :ice,
    :snow_block,
    :cactus,
    :clay,
    :jukebox,
    # special case:
    :fence,
    :bloodstone,
    :slow_sand,
    :lightstone
  ]

  WATER = [
    :water,
    :still_water
  ]

  TOOLS = {
    # shovel
    277 => [:grass, :dirt, :sand, :gravel, :soil, :snow, :snow_block, :slow_sand],
    # pick
    278 => [:stone, :cobble, :gold_ore, :iron_ore, :coal_ore, :gold_block, :iron_block, :double_step, :step, :brick, :mossy_cobble, :obsidian, :diamond_ore, :diamond_block, :cobble_stairs, :redstone_ore, :glowing_redstone_ore, :ice, :cactus, :bloodstone, :lightstone],
    # axe
    279 => [:wood, :log, :leaves, :fence]
  }

  DIGS = {
    :stone => 29,
    :grass => 12,
    :dirt => 10,
    :cobble => 38,
    :wood => 38,
    :sand => 10,
    :gravel => 12,
    :gold_ore => 57,
    :iron_ore => 57,
    :coal_ore => 57,
    :log => 38,
    :leaves => 30,
    :sponge => 90,
    :glass => 46,
    :cloth => 121,
    :gold_block => 57,
    :iron_block => 94,
    :brick => 301,
    :bookcase => 226,
    :mossy_cobble => 38,
    :obsidian => 1501,
    :chest => 376,
    :diamond_ore => 57,
    :diamond_block => 94,
    :workbench => 376,
    :soil => 90,
    :furnace => 350,
    :burning_furnace => 350,
    :sign_post => 151,
    :redstone_ore => 450,
    :glowing_redstone_ore => 450,
    :snow_block => 4,
    :clay => 90,
    :jukebox => 301,
    :fence => 301,
    :bloodstone => 8,
    :slow_sand => 76,
    :lightstone => 46
  }

  class Chunk

    FULL_CHUNK = 16 * 16 * 128

    attr_reader :x, :y, :z
    attr_reader :size_x, :size_y, :size_z

    def initialize(x, y, z, size_x, size_y, size_z, data)
      # sizes are raw from packet, so add 1
      @x, @y, @z = x, y, z
      @size_x, @size_y, @size_z = size_x + 1, size_y + 1, size_z + 1

      if data
        @data = data
      else
        @blocks = Array.new(@size_x * @size_y * @size_z) { :air }
      end
    end

    def full_chunk?
      blocks.size == FULL_CHUNK
    end

    def valid?
      blocks.all? {|b| b}
    end

    # for iterating over and sending updates
    def each_column
      (0...size_x).each do |x|
        (0...size_z).each do |z|
          offset = (x * size_z * size_y) + (z * size_y)
          yield x + self.x, self.y, z + self.z, blocks[offset...(offset + size_y)]
        end
      end
    end

    def update(x, y, z, data)
      x = x - self.x
      y = y - self.y
      z = z - self.z
      offset = (x * size_z * size_y) + (z * size_y) + y
      blocks[offset...(offset+data.size)] = data
    end

    # access using chunk-localized coords, x=0..15, y=0..127, z=0..15
    def local(x, y, z)
      blocks[(x * size_z * size_y) + (z * size_y) + y]
    end

    # access using map-absolute coords
    def [](x, y, z)
      # chunk is at -16, -16, then -3 maps to -3 -(-16) == 16 - 3 == 13
      local(x - self.x, y - self.y, z - self.z)
    end

    # assign using map-absolute coords
    def []=(x, y, z, type)
      blocks[(x - self.x) * size_z * size_y + y - self.y + (z - self.z) * size_y] = type
    end

    def find(type, absolute=true)
      found = []
      blocks.each.with_index do |b, i|
        if b == type
          x, y, z = [i / (size_x * size_y), i % size_y, i % (size_x*size_y) / size_y]
          if absolute
            found << [x + self.x, y + self.y, z + self.z]
          else
            found << [x, y, z]
          end
        end
      end
      found
    end

    protected

    def blocks
      return @blocks if @blocks
      @blocks = []
      data = Zlib::Inflate.inflate(@data)
      size = @size_x * @size_y * @size_z
      *block_types = data[0...size].unpack("c#{size}")
      block_types.each do |code|
        @blocks << BLOCKS[code]
      end
      @blocks
    end

  end
end
