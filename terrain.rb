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



module RiverTopoGrid


  def get_m
    @m = 5
  end


  def get_n
    @n = 3
  end


  def make_topo_grid
    # grid size = @m x @n
    @m = 5
    @n = 3

    @compass = [:N,:E,:S,:W]
    @t_grid = [nil]
    1.upto(@m) do |j|
      cc = [nil]
      1.upto(@n) do |k|
        zz = {:x=>j,:y=>k,:N=>:blank,:E=>:blank,:S=>:blank,:W=>:blank}
        cc << zz
      end
      @t_grid[j] = cc
    end

    # block edges
    1.upto(@m) {|j| set_grid(j,1,:N,:blocked)}
    1.upto(@n) {|k| set_grid(1,k,:W,:blocked)}
    1.upto(@n) {|k| set_grid(@m,k,:E,:blocked)}

    # set mouth
    mouth = 2+rand(@m-2)
    set_grid(mouth,@n,:S,:connect)

    # build first segment with "mouth" cell as root
    @root = 0
    set_grid(mouth,@n,:seg,@root)
    @root_x = mouth
    @root_y = @n
    root_node = {:x=>@root_x,:y=>@root_y}
    @tree = [root_node]
    @segments = []
    @segments[@root] = @tree

    # set rest of bottom row to :blocked
    1.upto(@m) {|j| set_grid(j,@n,:S,:blocked) if j != mouth}

    # build list of available connections
    @open_list = []
    1.upto(@m-1) do |x|
      1.upto(@n) do |y|
        ct = {:x1=>x,:y1=>y,:dir1=>:E,:x2=>x+1,:y2=>y,:dir2=>:W}
        @open_list << ct
      end
    end
    1.upto(@m) do |x|
      1.upto(@n-1) do |y|
        ct = {:x1=>x,:y1=>y,:dir1=>:S,:x2=>x,:y2=>y+1,:dir2=>:N}
        @open_list << ct
      end
    end

    # iterate through connections until empty
    until @open_list == []
      @open_list.shuffle!
      connection = @open_list.pop
      a1 = connection[:x1]
      b1 = connection[:y1]
      seg1 = @t_grid[a1][b1][:seg]

      dir1 = connection[:dir1]
      a2 = connection[:x2]
      b2 = connection[:y2]
      dir2 = connection[:dir2]
      seg2 = @t_grid[a2][b2][:seg]

      # determine if cells in new connections
      # are already part of segments
      if seg1 == nil
        if seg2 == nil
          status = :new_seg
        else
          status = :add_c1_to_seg2
        end
      else # (seg1 != nil)
        if seg2 == nil
          status = :add_c2_to_seg1
        elsif seg1 != seg2
          status = :join_segs
        else
          status = :no_connect
        end
      end

      case status

      when :new_seg
        seg = @segments.length
        set_grid(a1,b1,:seg,seg)
        set_grid(a2,b2,:seg,seg)
        br = [ {:x=>a1,:y=>b1},{:x=>a2,:y=>b2} ]
        @segments << br
      when :add_c1_to_seg2
        set_grid(a1,b1,:seg,seg2)
        br = @segments[seg2]
        cc = {:x=>a1,:y=>b1}
        br << cc
        @segments[seg2] = br
      when :add_c2_to_seg1
        set_grid(a2,b2,:seg,seg1)
        br = @segments[seg1]
        cc = {:x=>a2,:y=>b2}
        br << cc
        @segments[seg1] = br
      when :join_segs
        seg = [seg1,seg2].min
        segx = [seg1,seg2].max
        brx = @segments[segx]
        brx.each do |cc|
          set_grid(cc[:x],cc[:y],:seg,seg)
          cc[:seg] = seg
        end
        combo = @segments[seg1]+@segments[seg2]
        @segments[seg] = combo
        @segments[segx] = []
      when :no_connect

      end

      if status != :no_connect
        set_grid(a1,b1,dir1,:connect)
        set_grid(a2,b2,dir2,:connect)
      end
    end

  end


  def set_grid(j,k,key,value)
    cell = @t_grid[j][k]
    cell[key] = value if cell.class == Hash
    @t_grid[j][k] = cell
  end


  def topo_string
    make_topo_grid if @t_grid == nil
    str = ""
    1.upto(@n) do |k|
      1.upto(@m) do |j|
        cell = @t_grid[j][k]
        @compass.each do |dir|
          sym = cell[dir] if cell.respond_to? :[]
          if sym == :connect
            ch = "c"
          else
            ch = "x"
          end
          str << ch
        end
      end
    end
    str
  end


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
  RT_ZONE_WIDTH = 8
  RT_ZONE_HEIGHT = 8


# River Branch Connector Templates:
  CX_TEMPLATES = {
    :cx_stub_n => [{:src=>:origin,:dir=>:no_go,:id=>:N}],
    :cx_stub_e => [{:src=>:origin,:dir=>:no_go,:id=>:E}],
    :cx_stub_s => [{:src=>:origin,:dir=>:no_go,:id=>:S}],
    :cx_stub_w => [{:src=>:origin,:dir=>:no_go,:id=>:W}],

    :cx_vert => [{:src=>:origin,:dir=>:no_go,:id=>:N},
                {:src=>0,:dir=>:S,:id=>:S}],

    :cx_hrz_a => [{:src=>:origin,:dir=>:S,:id=>:W},
                 {:src=>0,:dir=>:NE,:id=>:E}],

    :cx_hrz_b => [{:src=>:origin,:dir=>:no_go,:id=>:W},
                {:src=>0,:dir=>:SE,:id=>:E}],

    :cx_n_e => [{:src=>:origin,:dir=>:no_go,:id=>:N},
               {:src=>0,:dir=>:S,:id=>nil},
               {:src=>1,:dir=>:SE,:id=>:E}],

    :cx_s_e => [{:src=>:origin,:dir=>:SE,:id=>:E},
               {:src=>0,:dir=>:SW,:id=>nil},
               {:src=>1,:dir=>:S,:id=>:S}],

    :cx_s_w => [{:src=>:origin,:dir=>:no_go,:id=>:W},
               {:src=>0,:dir=>:SE,:id=>nil},
               {:src=>1,:dir=>:S,:id=>:S}],

    :cx_n_w => [{:src=>:origin,:dir=>:SE,:id=>:N},
               {:src=>0,:dir=>:S,:id=>nil},
               {:src=>1,:dir=>:SW,:id=>:W}],

    :cx_dn => [{:src=>:origin,:dir=>:no_go,:id=>:W},
              {:src=>0,:dir=>:SE,:id=>nil},
              {:src=>1,:dir=>:S,:id=>:S},
              {:src=>1,:dir=>:NE,:id=>:E}],

    :cx_up => [{:src=>:origin,:dir=>:SE,:id=>:N},
              {:src=>0,:dir=>:S,:id=>nil},
              {:src=>1,:dir=>:SW,:id=>:W},
              {:src=>1,:dir=>:SE,:id=>:E}],

    :cx_rt_a => [{:src=>:origin,:dir=>:no_go,:id=>:N},
                {:src=>0,:dir=>:S,:id=>nil},
                {:src=>1,:dir=>:SE,:id=>nil},
                {:src=>2,:dir=>:S,:id=>:S},
                {:src=>2,:dir=>:NE,:id=>:E}],

    :cx_rt_b => [{:src=>:origin,:dir=>:SE,:id=>:N},
                {:src=>0,:dir=>:S,:id=>nil},
                {:src=>1,:dir=>:SE,:id=>:E},
                {:src=>1,:dir=>:SW,:id=>nil},
                {:src=>3,:dir=>:S,:id=>:S}],

    :cx_lft_a => [{:src=>:origin,:dir=>:S,:id=>:W},
                 {:src=>0,:dir=>:SE,:id=>nil},
                 {:src=>1,:dir=>:S,:id=>:S},
                 {:src=>1,:dir=>:NE,:id=>nil},
                 {:src=>3,:dir=>:N,:id=>:N}],

    :cx_lft_b => [{:src=>:origin,:dir=>:SE,:id=>:N},
                 {:src=>0,:dir=>:S,:id=>nil},
                 {:src=>1,:dir=>:SW,:id=>:W},
                 {:src=>1,:dir=>:SE,:id=>nil},
                 {:src=>3,:dir=>:S,:id=>:S}],

    :cx_4_a => [{:src=>:origin,:dir=>:SE,:id=>:N},
               {:src=>0,:dir=>:S,:id=>nil},
               {:src=>1,:dir=>:SW,:id=>:W},
               {:src=>1,:dir=>:SE,:id=>nil},
               {:src=>3,:dir=>:NE,:id=>:E},
               {:src=>3,:dir=>:S,:id=>:S}],

    :cx_4_b => [{:src=>:origin,:dir=>:S,:id=>:W},
               {:src=>0,:dir=>:SE,:id=>nil},
               {:src=>1,:dir=>:S,:id=>:S},
               {:src=>1,:dir=>:NE,:id=>nil},
               {:src=>3,:dir=>:N,:id=>:N},
               {:src=>3,:dir=>:SE,:id=>:E}] }

  


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

    make_topo_grid
    @rt_grid = @t_grid
 
     
    1.upto(@m) do |j|
      1.upto(@n) do |k|
        cell = @rt_grid[j][k]
        add_connector(cell,j,k)
        @rt_grid[j][k] = cell

      end
    end
    @rivers
  end


  # place a river connector (branch point) on the terrain map in the zone
  # corresponding to a cell in the river topo grid
  def add_connector(cell,j,k)
    pattern = get_pattern(cell)
    hexes = []
    aa = (j-1)*RT_ZONE_WIDTH+3
    bb = (k-1)*RT_ZONE_HEIGHT+2
    template = CX_TEMPLATES[pattern]
    template.each do |step|
      src = step[:src]
      dir = step[:dir]
      id = step[:id]
      if src == :origin
        h0 = {:a=>aa,:b=>bb}
      else
        h0 = hexes[src]
      end
      hex = next_hex(h0,dir)
      @rivers.put(hex,:water)
      hexes << hex

    end


  end


  # determine the connector pattern for a cell in the river topo grid
  def get_pattern(cell)
    cx = "xxxx"
    cx[0] = "N" if cell[:N] == :connect
    cx[1] = "E" if cell[:E] == :connect
    cx[2] = "S" if cell[:S] == :connect
    cx[3] = "W" if cell[:W] == :connect
    case cx
    when "Nxxx"
      pattern = :cx_stub_n
    when "xExx"
      pattern = :cx_stub_e
    when "xxSx"
      pattern = :cx_stub_s
    when "xxxW"
      pattern = :cx_stub_w
    when "NESW"
      if rand(2) == 0
        pattern = :cx_4_a
      else
        pattern = :cx_4_b
      end
    when "NESx"
      if rand(2) == 0
        pattern = :cx_rt_a
      else
        pattern = :cx_rt_b
      end
    when "NxSW"
      if rand(2) == 0
        pattern = :cx_lft_a
      else
        pattern = :cx_lft_b
      end
    when "NxSx"
      pattern = :cx_vert
    when "xExW"
      if rand(2) == 0
        pattern = :cx_hrz_a
      else
        pattern = :cx_hrz_b
      end
    when "xESW"
      pattern = :cx_dn
    when "NExW"
      pattern = :cx_up
    when "NExx"
      pattern = :cx_n_e
    when "xESx"
      pattern = :cx_s_e
    when "xxSW"
      pattern = :cx_s_w
    when "NxxW"
      pattern = :cx_n_w
    else pattern = nil
    end
  pattern
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
      when :no_go
        nxt[:a] = a
        nxt[:b] = b
      when :N
        nxt[:a] = a
        nxt[:b] = b-1
      when :NE
        nxt[:a] = a+1
        nxt[:b] = b-a%2
      when :SE
        nxt[:a] = a+1
        nxt[:b] = b-a%2+1
      when :S
        nxt[:a] = a
        nxt[:b] = b+1
      when :SW
        nxt[:a] = a-1
        nxt[:b] = b-a%2+1
      when :NW
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



helpers TerrainHelper, RiverTopoGrid



