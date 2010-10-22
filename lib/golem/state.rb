module Golem

  Position = Struct.new(:x, :y, :stance, :z, :rotation, :pitch, :flying)
  Entity = Struct.new(:position, :follow_position)

  class State

    STANCE = 1.62000000476837

    attr_reader :entities, :position, :packet_channel, :following
    attr_accessor :follow_mode

    def initialize(packet_channel, opts={})
      @packet_channel = packet_channel
      @position = Position.new
      @entities = {}
      @follow_player = opts[:follow]
      @following = nil
      @follow_mode = :watch # or :look

      send_delayed 0.5, :handshake, "golem"

      # keepalive
      EM.add_periodic_timer(5) { send_packet :flying_ack, @position.flying }

      # pending moves
      EM.add_periodic_timer(0.1) do
        if move = pending_moves.shift
          x, y, z = *move
          puts "moving to #{x} #{y} #{z}"
          position.x = x + 0.5
          position.y = y
          position.z = z + 0.5
          position.stance = y + STANCE
          position.flying = !map.solid?(x, y - 1, z)
          send_move_look
        end
      end
    end

    def update(packet)
      case packet.class.kind

      when :server_handshake
        send_packet :login, 2, "golem", "password"

      when :disconnect
        EM.stop

      when :player_move_look
        x, stance, y, z, rotation, pitch, flying = packet.values

        position.x, position.y, position.z = x, y, z
        position.stance = stance
        position.rotation, position.pitch, position.flying = rotation, pitch, flying

        # verify our position with the server
        send_packet :player_move_look, x, y, stance, z, rotation, pitch, flying

      when :entity
        # don't care

      when :vehicle_spawn, :mob_spawn
        entities[packet.id] = Entity.new([packet.x, packet.y, packet.z], nil)

      when :named_entity_spawn
        pos = [packet.x, packet.y, packet.z].map { |v| v.to_f / 32 }
        follow_pos = pos.map { |c| c.floor.to_i }
        entities[packet.id] = Entity.new pos, follow_pos
        if packet.name == @follow_player
          puts "yay, #{@follow_player} is here!"
          @following = entities[packet.id]
          follow
        end

      when :entity_move, :entity_move_look
        if entity = entities[packet.id]
          deltas = [packet.x, packet.y, packet.z].map { |v| v.to_f / 32 }
          new_pos = entity.position.map.with_index { |v, i| v + deltas[i] }
          entity.position = new_pos
          follow if entity == @following
        end

      when :entity_teleport
        if entities[packet.id]
          entities[packet.id].position = [packet.x, packet.y, packet.z].map { |v| v / 32 }
          follow if entity == @following
        end

      when :destroy_entity
        deleted = entities.delete packet.id
        if following == deleted
          puts "#{@follow_player} has gone away :("
          @following = nil
        end

      when :pre_chunk
        if !packet.add
          map.drop(packet.x, packet.z)
        end

      when :map_chunk
        send_packet :flying_ack, true
        before = map.size
        puts "loading map... " if before == 0
        map.add Chunk.new(packet.x, packet.y, packet.z, packet.size_x, packet.size_y, packet.size_z, packet.values.last)
        puts "map loaded!" if before < 441 && map.size == 441

      when :block_change
        map[packet.x, packet.y, packet.z] = BLOCKS[packet.type]

      when :multi_block_change
        packet.changes.each do |location, type|
          map[*location] = BLOCKS[type]
        end
        send_packet :flying_ack, position.flying
      end

    end

    def block_at(x, y, z)
      map[x, y, z]
    end

    def adjacent
      map.available(position.x.floor, position.y.floor, position.z.floor)
    end

    def path_to(x, y, z)
      map.path([position.x.floor, position.y.to_i, position.z.floor].map(&:to_i), [x, y, z].map(&:to_i))
    end

    def follow
      return unless following && position.x

      current = following.position.map { |v| v.floor.to_i }

      if following.follow_position.nil?
        following.follow_position = current
      end

      if following.follow_position != current
        following.follow_position = current
        x, y, z = *current
        # + 0.001 so it's never 0, which causes an error
        position.pitch = Math.atan2(position.y - y, Math.sqrt((position.x - x + 0.5)**2 + (position.z - z + 0.5)**2) + 0.001).in_degrees
        puts [position.z - z + 0.5, position.x - x + 0.5].inspect
        position.rotation = Math.atan2(position.z - z + 0.5, position.x - x + 0.5 + 0.001).in_degrees + 90

        if follow_mode == :watch
          send_look
        else
          puts "has moved, updating path"
          path = map.path([position.x.floor, position.y.to_i, position.z.floor].map(&:to_i), current)
          if path && path.size > 0
            pending_moves.clear
            path.pop # drop the last move
            pending_moves.concat path
          end
        end

      end
    end

    protected

    def send_look
      send_packet :player_look, position.rotation, position.pitch, position.flying
    end

    def send_move_look
      send_packet :player_move_look, position.x, position.y, position.stance, position.z, position.rotation, position.pitch, position.flying
    end

    def map
      @map ||= Map.new
    end

    def send_packet(kind, *values)
      packet_class = Packet.client_packets_by_kind[kind] or raise ArgumentError, "unknown packet type #{kind.inspect}"
      packet_channel.push packet_class.new(*values)
    end

    def send_delayed(delay, kind, *values)
      packet_class = Packet.client_packets_by_kind[kind] or raise ArgumentError, "unknown packet type #{kind.inspect}"
      packet = packet_class.new(*values)
      EM.add_timer(delay) { packet_channel.push packet }
    end

    def pending_moves
      @pending_moves ||= []
    end

  end
end
