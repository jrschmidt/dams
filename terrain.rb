require 'rubygems'

require 'sinatra'

require 'coffee-script'

require 'pry'


get '/' do
  erb :index
end


get '/javascripts/dams.js' do
  coffee :dams
end



module TerrainHelper


  class HexGrid

    def initialize
      @grid = []
      fill(:no_data)
    end

    def fill(value)
      0.upto(HEX_DIM_EW) {|i| @grid[i] = [value]*(HEX_DIM_NS+1)}
    end

    def put(hex,value)
      z = :good
      if hex == nil
        z = :bad
      else
        a = hex[:a]
        b = hex[:b]
        z = :bad if (a == nil || a<0 || a>HEX_DIM_EW || b == nil || b<0 || b>HEX_DIM_NS)
      end
      put_ab(a,b,value) if (z == :good)
    end

    def put_ab(a,b,value)
      @grid[a][b] = value
    end

    def get(hex)
      z = :good
      if (hex == nil)
        z = :bad
      else
        a = hex[:a]
        b = hex[:b]
        z = :bad if a == nil || a<0 || a>HEX_DIM_EW || b == nil || b<0 || b>HEX_DIM_NS
      end
      get_ab(a,b) if (z == :good)
    end

    def get_ab(a,b)
      @grid[a][b]
    end

    def get_map
      @grid
    end


    def add_data(hex_grid2,mode)
      case mode
      when :rivers
        symbols = WATER_SYMBOLS
      end
      0.upto(HEX_DIM_EW) do |a|
        0.upto(HEX_DIM_NS) do |b|
          value = hex_grid2.get_ab(a,b)
          put_ab(a,b,value) if symbols.include?(value)
        end
      end
    end

  end

#   Map Constants
#   Current map dimensions are 41 hexes East to West [0..40] and 23 hexes
#   North to South [0.22].
  HEX_DIM_EW = 40
  HEX_DIM_NS = 22

  LAND_SYMBOLS = [
    :elev_10,
    :elev_20,
    :elev_30,
    :elev_40,
    :elev_50,
    :elev_60,
    :elev_70,
    :elev_80,
    :elev_90,
    :elev_100,
    :elev_110,
    :elev_120,
    :elev_130,
    :elev_140 ] 

  WATER_SYMBOLS = [
    :water,
    :water_10,
    :water_20,
    :water_30,
    :water_40,
    :water_50,
    :water_60,
    :water_70,
    :water_80,
    :water_90,
    :water_100,
    :water_110,
    :water_120,
    :water_130,
    :water_140 ] 


#   Heuristics Used For This Version:
#   (with their constants)

#   Options designated in this format: {1,2,3} are given equal weight unless
#   otherwise specified. 

#   River mouth:

#   [OPTION 1]
#   Equal weight for values {"low",12,14,16,18,20,22,24,26,28,"high"}.
#   If "low", then equal weight for {6,8,10}; if "high", then equal weight
#   for {30,32,34}.
 
  RV_MOUTH_SPREAD = 11
  RV_MOUTH_LO = 6
  RV_MOUTH_HI = 28
  RV_MOUTH_MID = 10

#   River extend:

#   [OPTION 1]
#   Initial direction is {North}. Pick {1,2,3} segments until next branch point. For each
#   segment, go {1,2,3} hexes in current direction. If branch point, make
#   Y-shaped branch and continue both branches. If not a branch point, pick
#   next direction {L,R}. Process all segments from all branches simultaneously, one
#   segment at a time. After each segment, randomly choose which branch to extend
#   next. End a branch when a blocked hex is reached.

  RV_DIR_INIT = :dir_N
  RV_BRANCH_ID_INIT = :br_000
  RV_SEGMENTS_TO_BRANCH = 1..3
  RV_SEGMENT_SIZE = 1..3

#   River block

#   {OPTION 1]
#   Mark hexes as blocked for further river extensions if they are one hex
#   away from edge or another river.

  RV_EDGE_MARGIN = 1



  def build_terrain
    @map = HexGrid.new
    @map.fill(:elev_60)
    @rivers = build_rivers
    @map.add_data(@rivers,:rivers)
    @map.get_map
  end

  def build_rivers
    @rivers = HexGrid.new
    @rivers.fill(:no_data)

    # mark blocked edge hexes
    0.upto(HEX_DIM_NS) {|b| river_block_ab(0,b)}
    0.upto(HEX_DIM_NS) {|b| river_block_ab(HEX_DIM_EW,b)}
    0.upto(HEX_DIM_EW) {|a| river_block_ab(a,0)}
    0.upto(HEX_DIM_EW) {|a| river_block_ab(a,HEX_DIM_NS)}

    #pick river starting point
    mouth = {:a=>pick_river_mouth,:b=>HEX_DIM_NS}
    @rivers.put(mouth,:water)
    first_ext = next_hex(mouth,:dir_N)
    first_ext[:dir] = :dir_N

    segments_until_next_branch_point = 0
    @new_branch_id_symbol = RV_BRANCH_ID_INIT
    @branches_pending = []
    add_extension(first_ext)


    # cycle randomly through the queue of uncompleted branches until
    # the list is empty
    until @branches_pending == []

      # randomly pick next branch to extend from pending extensions
      branch_head = array_pick_random(@branches_pending,:equal_weight)

      # if starting from a branch point, pick number of segments to next
      # branch point
      if segments_until_next_branch_point == 0
        is_branch_point = true
        segments_until_next_branch_point = int_random(1,3,:equal_weight)
      else
        segments_until_next_branch_point -= 1
        is_branch_point = false
      end

      # pick the length of this segment (number of hexes in a straight line)
      hexes_in_segment = int_random(1,3,:equal_weight)

      # get the hexes for this segment
      h = branch_head
      direction = branch_head[:dir]
      segment = [h]
      (hexes_in_segment-1).times do
        hex = next_hex(h,direction)
        segment << hex
        h = hex
      end
      segment.compact!

      # check to see if the hexes are blocked
      end_branch = false
      segment.each {|hex| end_branch = true if river_not_allowed(hex)}

      # terminate the branch if this is the end
      if end_branch
        river_block(next_hex(branch_head,direction))
        river_block(go_left(branch_head,direction))
        river_block(go_right(branch_head,direction))

      # extend the branch if not the end
      else
        until segment == []
          pointer = segment.shift
          @rivers.put(pointer,:water)

          # if not last hex in this segment
          if segment.length > 0
            river_block(go_left(pointer,direction))
            river_block(go_right(pointer,direction))

          # if last hex in this segment
          else

            # if end of segment is branch point
            if is_branch_point
              river_block(next_hex(pointer,direction))
              ext_lft = go_left(pointer,direction)
              end_branch = true if river_not_allowed(ext_lft)
              ext_rt = go_right(pointer,direction)
              end_branch = true if  river_not_allowed(ext_rt)

              # if branch is blocked
              if end_branch
                river_block(ext_lft)
                river_block(ext_rt)

              # if branch is not blocked
              else
                add_extension(ext_lft)
                add_extension(ext_rt)
              end

            # if end of segment is not branch point
            else
              river_block(next_hex(pointer,direction))
              ext_lft = go_left(pointer,direction)
              ext_rt = go_right(pointer,direction)
              next_dir = array_pick_random([:left,:right],:equal_weight)
              case next_dir
              when :left
                end_branch = true if river_not_allowed(ext_lft)
              when :right
                end_branch = true if river_not_allowed(ext_rt)
              end

              # if branch is blocked
              if end_branch
                river_block(ext_lft)
                river_block(ext_rt)

              # if branch is not blocked
              else
                case next_dir
                when :left
                  river_block(ext_rt)
                  add_extension(ext_lft)
                when :right
                  river_block(ext_lft)
                  add_extension(ext_rt)
                end

              end

            end

          end
          
        end

      end

    end

    @rivers

  end


  # pick which hex at the bottom of the map will be the river mouth
  def pick_river_mouth
    rnd = rand(RV_MOUTH_SPREAD)
    if rnd == 0
      start = RV_MOUTH_LO+2*rand(3)
    elsif rnd == RV_MOUTH_SPREAD
      start = RV_MOUTH_HI-2*rand(3)
    else
      start = RV_MOUTH_MID+2*rnd
    end
    start
  end


  def  add_extension(ext)
    if ext != nil
      id = @new_branch_id_symbol
      @new_branch_id_symbol = @new_branch_id_symbol.succ
      branch = ext
      branch[:id] = id
      @rivers.put(branch,id)
      @branches_pending << branch
    end
  end


  def river_not_allowed(hex)
    if hex == nil
      bad = true
    else
      mark = @rivers.get(hex)
      bad = true
      bad = false if mark == :no_data
      bad = false if mark == hex[:id]
    end
    bad
  end


  def river_block(hex)
    @rivers.put(hex,:blocked) if @rivers.get(hex) != :water
  end


  def river_block_ab(a,b)
    hex = {:a=>a,:b=>b}
    river_block(hex)
  end


  def go_left(hex,dir)
    if dir == nil
      lft = nil
    else
      dir2 = left(dir)
      lft = next_hex(hex,dir2)
      lft[:dir] = dir2
    end
    lft
  end


  def go_right(hex,dir)
    if dir == nil
      rt = nil
    else
      dir2 = right(dir)
      rt = next_hex(hex,dir2)
      rt[:dir] = dir2
    end
    rt
  end


  def left(dir)
    case dir
    when :dir_N
      left = :dir_NW
    when :dir_NE
      left = :dir_N
    when :dir_SE
      left = :dir_NE
    when :dir_S
      left = :dir_SE
    when :dir_SW
      left = :dir_S
    when :dir_NW
      left = :dir_SW
    else
      left = nil
    end
    left
  end


  def right(dir)
    case dir
    when :dir_N
      right = :dir_NE
    when :dir_NE
      right = :dir_SE
    when :dir_SE
      right = :dir_S
    when :dir_S
      right = :dir_SW
    when :dir_SW
      right = :dir_NW
    when :dir_NW
      right = :dir_N
    else
     right = nil
    end
    right
  end


  def next_hex(hex,dir)
    nxt = {}
    if (hex == nil)
      nxt = nil
    else
      a = hex[:a]
      b = hex[:b]
      nxt = nil if a == nil || b == nil
    end
    if (nxt != nil)
      case dir
      when :dir_N
        nxt[:a] = a
        nxt[:b] = b-1
      when :dir_NE
        nxt[:a] = a+1
        nxt[:b] = b-a%2
      when :dir_SE
        nxt[:a] = a+1
        nxt[:b] = b-a%2+1
      when :dir_S
        nxt[:a] = a
        nxt[:b] = b+1
      when :dir_SW
        nxt[:a] = a-1
        nxt[:b] = b-a%2+1
      when :dir_NW
        nxt[:a] = a-1
        nxt[:b] = b-a%2
      else
        nxt = nil
      end
      nxt = nil if nxt[:a]<0 || nxt[:a]>HEX_DIM_EW || nxt[:b]<0 || nxt[:b]>HEX_DIM_NS
    end
    nxt
  end


  def int_random(j,k,mode)
    j+rand(k-j+1)    
  end


  def array_pick_random(arr,mode)
    arr.shuffle!
    arr.pop
  end


  # This method is called by an erb statement in an application template. It
  # calls build_terrain to generate the terrain map, then converts it to a
  # string. The erb code embeds the string in a data field in a tag in the
  # DOM, where it can be accessed by the javascript/coffeescript for display.
  def terrain_string
    str = ""
    @terrain = build_terrain
    @terrain.each do |t|
      t.each do |hex|
        str << encode(hex)
      end
    end
    str
  end


  # encode elevation values to a one-character code
  def encode(elev)
    values = {
      :elev_10 => "a",
      :elev_20 => "b",
      :elev_30 => "c",
      :elev_40 => "d",
      :elev_50 => "e",
      :elev_60 => "f",
      :elev_70 => "g",
      :elev_80 => "h",
      :elev_90 => "i",
      :elev_100 => "j",
      :elev_110 => "k",
      :elev_120 => "l",
      :elev_130 => "m",
      :elev_140 => "n", 
      :water_10 => "A",
      :water_20 => "B",
      :water_30 => "C",
      :water_40 => "D",
      :water_50 => "E",
      :water_60 => "F",
      :water_70 => "G",
      :water_80 => "H",
      :water_90 => "I",
      :water_100 => "J",
      :water_110 => "K",
      :water_120 => "L",
      :water_130 => "M",
      :water_140 => "N",
      :water => "A" }
    ch = values.fetch(elev,:no_data)
    ch = "x" if (ch == :no_data)
    ch
  end

end



helpers TerrainHelper


