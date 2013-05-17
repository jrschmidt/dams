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



class TopoGrid

  attr :cells, :cx_list

  def initialize
    @cells = []
    @cx_list = []
  end


  def set_cell(j,k,key,value)
    cell = get_cell(j,k)
    if cell == nil
      cell = {s: j, t: k}
      @cells << cell
    end
    cell[key] = value if cell.class == Hash
  end


  def get_cell(j,k)
    @cells.find {|cc| cc[:s] == j && cc[:t] == k}
  end


  def get_all_cells
    @cells
  end


end



class SquareTopoGrid < TopoGrid
  
  attr :m, :n

  def initialize(m,n)
    super()
    @m = m
    @n = n

    1.upto(@m) do |j|
      1.upto(@n) do |k|
        zz = {s: j, t: k, N: :blank, E: :blank, S: :blank, W: :blank}
        @cells << zz
      end
    end

    # block edges
    @cells.each do |cc|
      cc[:N] = :blocked if cc[:t] == 1
      cc[:W] = :blocked if cc[:s] == 1
      cc[:E] = :blocked if cc[:s] == @m
      cc[:S] = :blocked if cc[:t] == @n
    end

  end


end



class RiverTopoGrid < SquareTopoGrid

  def initialize
    super(5,3)

    # set mouth
    @mouth = 2+rand(@m-2)
    set_cell(@mouth,@n,:S,:connect)
    set_cell(@mouth,@n+1,:s,@mouth)
    set_cell(@mouth,@n+1,:t,@n+1)
    set_cell(@mouth,@n+1,:N,:connect)
    set_cell(@mouth,@n+1,:is_mouth,true)

    # build first segment with "mouth" cell as root
    @root = 0
    set_cell(@mouth,@n,:seg,@root)
    @root_s = @mouth
    @root_t = @n
    root_node = {s: @root_s, t: @root_t}
    @tree = [root_node]
    @segments = []
    @segments[@root] = @tree

    # build list of available connections
    @open_list = []
    1.upto(@m-1) do |s|
      1.upto(@n) do |t|
        ct = {s1: s, t1: t, dir1: :E, s2: s+1, t2: t, dir2: :W}
        @open_list << ct
      end
    end
    1.upto(@m) do |s|
      1.upto(@n-1) do |t|
        ct = {s1: s, t1: t, dir1: :S, s2: s, t2: t+1, dir2: :N}
        @open_list << ct
      end
    end

    # iterate randomly through connections until empty
    until @open_list == []
      @open_list.shuffle!
      connection = @open_list.pop
      s1 = connection[:s1]
      t1 = connection[:t1]
      dir1 = connection[:dir1]
      seg1 = get_cell(s1,t1)[:seg]
      s2 = connection[:s2]
      t2 = connection[:t2]
      dir2 = connection[:dir2]
      seg2 = get_cell(s2,t2)[:seg]

      # determine if cells in new connections
      # are already part of segments
      if seg1 == nil
        status = seg2 == nil ? :new_seg : :add_c1_to_seg2
      else
        status = seg2 == nil ? :add_c2_to_seg1 : :join_segs
        status = :no_connect if seg1 == seg2
      end

      case status

      # join segments, create new segment, or add new connection to an
      # existing segment as appropriate
      when :new_seg
        seg = @segments.length
        set_cell(s1,t1,:seg,seg)
        set_cell(s2,t2,:seg,seg)
        br = [ {s: s1, t: t1},{s: s2, t: t2} ]
        @segments << br
      when :add_c1_to_seg2
        set_cell(s1,t1,:seg,seg2)
        br = @segments[seg2]
        cc = {s: s1, t: t1}
        br << cc
        @segments[seg2] = br
      when :add_c2_to_seg1
        set_cell(s2,t2,:seg,seg1)
        br = @segments[seg1]
        cc = {s: s2, t: t2}
        br << cc
        @segments[seg1] = br
      when :join_segs
        seg = [seg1,seg2].min
        segx = [seg1,seg2].max
        brx = @segments[segx]
        brx.each do |cc|
          set_cell(cc[:s],cc[:t],:seg,seg)
          cc[:seg] = seg
        end
        combo = @segments[seg1]+@segments[seg2]
        @segments[seg] = combo
        @segments[segx] = []
      end

      if status != :no_connect
        set_cell(s1,t1,dir1,:connect)
        set_cell(s2,t2,dir2,:connect)
        add_topo_connection(s1,t1,s2,t2,dir1,dir2)
      end
    end

    add_topo_connection(@mouth,@n,@mouth,@n+1,:S,:N)
  end


  def add_topo_connection(s1,t1,s2,t2,dir1,dir2)
    cx = {s1: s1, t1: t1, dir1: dir1, s2: s2, t2: t2, dir2: dir2}
    @cx_list << cx
  end


  # make a string to pass to the DOM so a coffeescript method can draw a
  # diagram of the topo grid
  def to_dom_string
    str = ""
    1.upto(@n) do |k|
      1.upto(@m) do |j|
        cell = get_cell(j,k)
        [:N,:E,:S,:W].each do |dir|
          sym = cell[dir] if cell.respond_to? :[]
          ch = sym == :connect ? "c" : "x"
          str << ch
        end
      end
    end
    str
  end


end



class HexMapGrid

  # Map Constants

  # Current map dimensions are 41 hexes East to West [0..40] and 23 hexes
  # North to South [0.22].
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
    :water_140,
    :zone ]

  def initialize
    @grid = []
    fill(:no_data)
  end


  def grid
    @grid
  end


  def fill(value)
    0.upto(HEX_DIM_EW) {|i| @grid[i] = [value]*(HEX_DIM_NS+1)}
  end


  def mark_hexes(value,hexes)
    hexes.each {|hx| put(hx,value)} unless hexes == nil
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
    put_ab(a,b,value) if z == :good
  end


  def put_ab(a,b,value)
    @grid[a][b] = value
  end


  def get(hex)
    z = :good
    if hex == nil
      z = :bad
    else
      a = hex[:a]
      b = hex[:b]
      z = :bad if a == nil || a<0 || a>HEX_DIM_EW || b == nil || b<0 || b>HEX_DIM_NS
    end
    get_ab(a,b) if z == :good
  end


  def get_ab(a,b)
    @grid[a][b]
  end


  # merge data from another HexMapGrid object with this one
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


  # returns true if ANY path exists in zone[] connecting hex1 and hex2
  def path_exists?(zone,hex1,hex2)
    root = hex1.clone
    branches = [root]
    zone << hex2
    path_found = false

    until path_found || branches.empty?
      branches.shuffle!
      ptr = branches.pop
      nbrs = zone.find_all {|z| adjacent?(z,ptr)}
      if nbrs.include?(hex2)
        path_found = true
      else
        branches = branches + nbrs
        zone = zone - nbrs
      end
    end
    path_found
  end


  # returns true if hex1 is adjacent to hex2
  def adjacent?(hex1,hex2)
    a1 = hex1[:a]
    b1 = hex1[:b]
    a2 = hex2[:a]
    b2 = hex2[:b]
    adj = false
    adj = true if a1 == a2 && (b2 == b1-1 || b2 == b1+1)
    adj = true if b1 == b2 && (a2 == a1-1 || a2 == a1+1)
    adj = true if a1%2 == 0 && (a2 == a1-1 || a2 == a1+1) && b2 == b1+1
    adj = true if a1%2 == 1 && (a2 == a1-1 || a2 == a1+1) && b2 == b1-1
    adj
  end


  # Make a vector of n hexes in a row in direction dir
  def make_vector(hex,dir,n)
    vector = [hex]
    hh = hex
    1.upto(n-1) do
      hh = next_hex(hh,dir)
      vector << hh
    end
    vector
  end


  def next_hex(hex,dir)
    nxt = {}
    if hex == nil
      nxt = nil
    else
      a = hex[:a]
      b = hex[:b]
      nxt = nil if a == nil || b == nil
    end
    if nxt != nil
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


end



class TerrainMap < HexMapGrid

  DEFAULT_ELEV_VALUE = :elev_60

  def initialize
  super
  fill(:default_base_elev)
  @rivers = RiverMap.new
  add_data(@rivers,:rivers)
  end


  def rivers
    @rivers
  end


  def get_map
    @grid
  end


  def fill(value)
    value = DEFAULT_ELEV_VALUE if value == :default_base_elev
    super(value)
  end


  def to_dom_string
    str = ""
    @grid.each do |t|
      t.each {|hex| str << encode(hex)}
    end
    str
  end


  # encode elevation values to a one-character code
  def encode(elev)
    values = {
      elev_10: "a",
      elev_20: "b",
      elev_30: "c",
      elev_40: "d",
      elev_50: "e",
      elev_60: "f",
      elev_70: "g",
      elev_80: "h",
      elev_90: "i",
      elev_100: "j",
      elev_110: "k",
      elev_120: "l",
      elev_130: "m",
      elev_140: "n",
      water_10: "A",
      water_20: "B",
      water_30: "C",
      water_40: "D",
      water_50: "E",
      water_60: "F",
      water_70: "G",
      water_80: "H",
      water_90: "I",
      water_100: "J",
      water_110: "K",
      water_120: "L",
      water_130: "M",
      water_140: "N",
      water: "A",
      zone: "Z" }
    ch = values.fetch(elev,:no_data)
    ch = "x" if ch == :no_data
    ch
  end


end



class RiverMap < HexMapGrid

  def initialize
    super
    fill(:no_data)

    # generate a model for the topology of river branching
    @river_topo = RiverTopoGrid.new

    # extract the list of cell to cell connections from the topology model
    @cx_list = @river_topo.cx_list

    # add river branching points corresponding to the topology designated
    # in the 'river topo grid'
    @river_topo.get_all_cells.each {|cell| add_connector(cell)}

    # connect the branching points to each other
    @cx_list.each {|cx| connect_cx(cx)}

    # generate water elevation
    generate_water_elevation(@rivers)

  end


  def river_topo
    @river_topo
  end


  # place a river connector (branch point) on the terrain map in the zone
  # corresponding to a cell in the river topo grid
  def add_connector(topo_cell)
    connector = HexConnector.new(topo_cell,self)
    mark_hexes(:water, connector.get_hexes)
    connector.get_connection_points.each_pair do |dir,hex|
      s = topo_cell[:s]
      t = topo_cell[:t]
      c1 = @cx_list.find {|cc| cc[:s1] == s && cc[:t1] == t && cc[:dir1] == dir}
      c2 = @cx_list.find {|cc| cc[:s2] == s && cc[:t2] == t && cc[:dir2] == dir}
      c1[:hex1] = hex unless c1 == nil
      c2[:hex2] = hex unless c2 == nil
    end
  end


  def get_start_point(cell,pattern)
    s = cell[:s]
    t = cell[:t]

    # (the '+3' and '+2' are to temporarily set all connectors to a set spot
    #   in the zone, later we'll set them at random locations within the zone)
    aa = (s-1)*RT_ZONE_WIDTH+3
    bb = (t-1)*RT_ZONE_HEIGHT+2

    # for the river mouth, use special values
    if pattern == :cx_river_mouth
      aa = aa+1
      bb = HEX_DIM_NS
    end

    {a: aa, b: bb}
  end


  # determine the connector pattern for a cell in the river topo grid
  def get_pattern(cell)
    cx = "xxxx"
    cx[0] = "N" if cell[:N] == :connect
    cx[1] = "E" if cell[:E] == :connect
    cx[2] = "S" if cell[:S] == :connect
    cx[3] = "W" if cell[:W] == :connect
    cx = "mouth" if cell[:is_mouth] == true
    pattern = select_random_match(cx.to_sym,CX_PATTERN_OPTIONS)
    pattern
  end


  # make the actual connection between two river connector branch points and
  # return the path of that connection
  def connect_cx(cx)

    # extract values from input parameter cx
    s1 = cx[:s1]
    t1 = cx[:t1]
    hex1 = cx[:hex1]
    a1= hex1[:a]
    b1 = hex1[:b]
    dir1 = cx[:dir1]
    s2 = cx[:s2]
    t2 = cx[:t2]
    hex2 = cx[:hex2]
    a2 = hex2[:a]
    b2 = hex2[:b]
    dir2 = cx[:dir2]
    case dir1
    when :S
      mode = :vert
      north_point = hex1
      south_point = hex2
    when :N
      mode = :vert
      north_point = hex2
      south_point = hex1
    when :E
      mode = :horz
      west_point = hex1
      east_point = hex2
    when :W
      mode = :horz
      west_point = hex2
      east_point = hex1
    end

    # get the zone of possible connector hexes for vertical or horizontal
    # connection
    case mode

    # get top and bottom bounding lanes for zone for a vertical connection
    when :vert
      max_west = 8*s1-7
      max_east = 8*s1-2

      top = []
      hx = north_point
      until hx[:a] == max_west || hx == south_point
        hx = next_hex(hx,:SW)
        top << hx
      end
      top << next_hex(north_point,:S)
      hx = north_point
      until hx[:a] == max_east
        hx = next_hex(hx,:SE)
        top << hx
      end
      top.sort_by! {|hh| hh[:a]}

      btm = []
      hx = south_point
      until hx[:a] == max_west
        hx = next_hex(hx,:NW)
        btm << hx
      end
      btm << next_hex(south_point,:N)
      hx = south_point
      until hx[:a] == max_east
        hx = next_hex(hx,:NE)
        btm << hx
      end
      btm.sort_by! {|hh| hh[:a]}

      hhxx1 = north_point
      hhxx2 = south_point

    # get top and bottom bounding lanes for zone for a horizontal connection
    when :horz
      a1 = west_point[:a]
      b1 = west_point[:b]
      a2 = east_point[:a]
      b2 = east_point[:b]
      delta_a = a2-a1
      delta_b = b2-b1
      zpat = ((delta_a-a1%2+1)/2).to_i
      delta_a_top = zpat-delta_b
      a_top = a1+delta_a_top
      zpab = -((delta_a+a1%2)/2).to_i
      delta_a_btm = delta_b-zpab
      a_btm = a1+delta_a_btm
      zpbt = ((delta_a+a1%2-1)/2).to_i
      delta_b_top = ((delta_b-zpbt)/2).to_i
      b_top = b1+delta_b_top
      zpbb = -((delta_a-a1%2)/2).to_i
      delta_b_btm = ((delta_b-zpbb+1)/2).to_i
      b_btm = b1+delta_b_btm

      top = []
      max_west = west_point[:a]+1
      hx = {a: a_top, b: b_top}
      top << hx

      until hx[:a] == max_west
        hx = next_hex(hx,:SW)
        top << hx
      end

      hx = {a: a_top, b: b_top}
      max_east = east_point[:a]-1
      until hx[:a] == max_east
        hx = next_hex(hx,:SE)
        top << hx
      end
      top.sort_by! {|hh| hh[:a]}

      btm = []
      hx = {a: a_btm, b: b_btm}
      btm << hx
      until hx[:a] == max_west
        hx = next_hex(hx,:NW)
        btm << hx
      end

      hx = {a: a_btm, b: b_btm}
      until hx[:a] == max_east
        hx = next_hex(hx,:NE)
        btm << hx
      end
      btm.sort_by! {|hh| hh[:a]}

      hhxx1 = west_point
      hhxx2 = east_point

    end

    # use the top and bottom bounding lanes to construct the connection zone
    zone = []
    zone_width = 0
    zone_width = top.length if top.respond_to?(:length)
    0.upto(zone_width-1) do |i|
      top_hex = top[i]
      btm_hex = btm[i]
      aa = top_hex[:a]
      b1 = top_hex[:b]
      b2 = btm_hex[:b]
      b1.upto(b2) {|bb| zone << {a: aa, b: bb} }
    end

    # pick a random connecting path through the zone
    path = []
    until zone == []
      zone.shuffle!
      hx = zone.pop
      path << hx unless path_exists?(zone+path,hhxx1,hhxx2)
    end
    path.each {|hx| put(hx,:water)}

  end


  def generate_water_elevation(river_grid)

  end


end



class TopoCell

end



# A HexConnector object is a set of one or more adjacent hexes that serve as
# a junction point to connect two or more segments in a hex grid map, or to
# terminate a single segment. A HexConnector object corresponds to a cell in
# the topo grid.

class HexConnector

  # River Branch Connector Templates:
  # These templates give hex patterns for different kinds of river junctions.
  # Within an individual template array, there is one hash for each hex in that
  # pattern. :src is the index number in the array to move from to get the next
  # hex in the pattern. A value of :origin for the key :src means move from the
  # starting hex for that pattern instead. The "starting hex" may be empty in
  # some patterns. A value of :no_go for the key :dir means start at the origin
  # hex. The :id key has a value of :N, :S, :E or :W if it is the north, south,
  # east or west connector hex for that pattern.
  CX_PATTERN_OPTIONS = { mouth: :cx_river_mouth,
                         Nxxx: :cx_stub_n,
                         xExx: :cx_stub_e,
                         xxSx: :cx_stub_s,
                         xxxW: :cx_stub_w,
                         NESW: [:cx_4_a, :cx_4_b],
                         NESx: [:cx_rt_a, :cx_rt_b],
                         NxSW: [:cx_lft_a, :cx_lft_b],
                         NxSx: :cx_vert,
                         xExW: [:cx_hrz_a, :cx_hrz_b],
                         xESW: :cx_dn,
                         NExW: :cx_up,
                         NExx: :cx_n_e,
                         xESx: :cx_s_e,
                         xxSW: :cx_s_w,
                         NxxW: :cx_n_w }

# FIXME 'id' is a very bad name which doesn't really describe what that field does. 'Connect direction' is more accurate. Maybe change it to 'cx_dir'.

  CX_TEMPLATES = {
    :cx_stub_n => [{src: :origin, dir: :no_go, id: :N}],
    :cx_stub_e => [{src: :origin, dir: :no_go, id: :E}],
    :cx_stub_s => [{src: :origin, dir: :no_go, id: :S}],
    :cx_stub_w => [{src: :origin, dir: :no_go, id: :W}],

    :cx_vert => [{src: :origin, dir: :no_go, id: :N},
                 {src: 0, dir: :S, id: :S}],

    :cx_hrz_a => [{src: :origin, dir: :S, id: :W},
                  {src: 0, dir: :NE, id: :E}],

    :cx_hrz_b => [{src: :origin, dir: :no_go, id: :W},
                  {src: 0, dir: :SE, id: :E}],

    :cx_n_e => [{src: :origin, dir: :no_go, id: :N},
                {src: 0, dir: :S, id: nil},
                {src: 1, dir: :SE, id: :E}],

    :cx_s_e => [{src: :origin, dir: :SE, id: :E},
                {src: 0, dir: :SW, id: nil},
                {src: 1, dir: :S, id: :S}],

    :cx_s_w => [{src: :origin, dir: :no_go, id: :W},
                {src: 0, dir: :SE, id: nil},
                {src: 1, dir: :S, id: :S}],

    :cx_n_w => [{src: :origin, dir: :SE, id: :N},
                {src: 0, dir: :S, id: nil},
                {src: 1, dir: :SW, id: :W}],

    :cx_dn => [{src: :origin, dir: :no_go, id: :W},
               {src: 0, dir: :SE, id: nil},
               {src: 1, dir: :S, id: :S},
               {src: 1, dir: :NE, id: :E}],

    :cx_up => [{src: :origin, dir: :SE, id: :N},
               {src: 0, dir: :S, id: nil},
               {src: 1, dir: :SW, id: :W},
               {src: 1, dir: :SE, id: :E}],

    :cx_rt_a => [{src: :origin, dir: :no_go, id: :N},
                 {src: 0, dir: :S, id: nil},
                 {src: 1, dir: :SE, id: nil},
                 {src: 2, dir: :S, id: :S},
                 {src: 2, dir: :NE, id: :E}],

    :cx_rt_b => [{src: :origin, dir: :SE, id: :N},
                 {src: 0, dir: :S, id: nil},
                 {src: 1, dir: :SE, id: :E},
                 {src: 1, dir: :SW, id: nil},
                 {src: 3, dir: :S, id: :S}],

    :cx_lft_a => [{src: :origin, dir: :S, id: :W},
                  {src: 0, dir: :SE, id: nil},
                  {src: 1, dir: :S, id: :S},
                  {src: 1, dir: :NE, id: nil},
                  {src: 3, dir: :N, id: :N}],

    :cx_lft_b => [{src: :origin, dir: :SE, id: :N},
                  {src: 0, dir: :S, id: nil},
                  {src: 1, dir: :SW, id: :W},
                  {src: 1, dir: :SE, id: nil},
                  {src: 3, dir: :S, id: :S}],

    :cx_4_a => [{src: :origin, dir: :SE, id: :N},
                {src: 0, dir: :S, id: nil},
                {src: 1, dir: :SW, id: :W},
                {src: 1, dir: :SE, id: nil},
                {src: 3, dir: :NE, id: :E},
                {src: 3, dir: :S, id: :S}],

    :cx_4_b => [{src: :origin, dir: :S, id: :W},
                {src: 0, dir: :SE, id: nil},
                {src: 1, dir: :S, id: :S},
                {src: 1, dir: :NE, id: nil},
                {src: 3, dir: :N, id: :N},
                {src: 3, dir: :SE, id: :E}],

    :cx_river_mouth => [{src: :origin, dir: :no_go, id: nil},
                        {src: 0, dir: :N, id: :N}] }

  RT_ZONE_WIDTH = 8
  RT_ZONE_HEIGHT = 8

  attr :topo_grid_cell, :hex_grid, :hexes, :connect_points

  def initialize(topo_cell,hex_grid)
    @topo_grid_cell = topo_cell
    @hex_grid = hex_grid
    @hexes = []
    @connect_points = {N: nil, E: nil, S: nil, W: nil}
    build_hexes
  end


  def get_hexes
    @hexes
  end


  def get_connection_points
    cx_points = @connect_points.select {|dir,hex| hex != nil}
    cx_points
  end


  def build_hexes

    pattern = get_pattern(@topo_grid_cell)
    start = get_start_point(@topo_grid_cell,pattern)
    prior_hexes = []

    # starting at the 'start point' hex, follow the pattern to build the connector
    template = CX_TEMPLATES[pattern]
    template.each do |step|
      src = step[:src]
      dir = step[:dir]

      h0 = src == :origin ? {a: start[:a], b: start[:b]} : prior_hexes[src]
      hex = @hex_grid.next_hex(h0,dir)
      prior_hexes << hex
      connect_points[step[:id]] = hex if [:N, :E, :S, :W].include?(step[:id])

      @hex_grid.put(hex,:water)
    end
  end


  # determine the connector pattern for a cell in the river topo grid
  def get_pattern(cell)
    cx = "xxxx"
    cx[0] = "N" if cell[:N] == :connect
    cx[1] = "E" if cell[:E] == :connect
    cx[2] = "S" if cell[:S] == :connect
    cx[3] = "W" if cell[:W] == :connect
    cx = "mouth" if cell[:is_mouth] == true
    pattern = select_random_match(cx.to_sym,CX_PATTERN_OPTIONS)
    pattern
  end


  def get_start_point(cell,pattern)
    s = cell[:s]
    t = cell[:t]

    # (the '+3' and '+2' are to temporarily set all connectors to a set spot
    #   in the zone, later we'll set them at random locations within the zone)
    aa = (s-1)*RT_ZONE_WIDTH+3
    bb = (t-1)*RT_ZONE_HEIGHT+2

    # for the river mouth, use special values
    if pattern == :cx_river_mouth
      aa = aa+1
      bb = HexMapGrid::HEX_DIM_NS
    end

    {a: aa, b: bb}
  end


end



# returns the value attached to the given key or, if key owns an array with
# multiple values, selects one of those values at random
def select_random_match(key,options_hash)
  mm = options_hash[key]
  match = nil if mm == nil
  match = mm if mm.class == Symbol
  match = mm[rand(mm.size)] if mm.class == Array
  match
end


def terrain_string
  @map = TerrainMap.new
  @map.to_dom_string
end

def topo_string
  @r_topo = @map.rivers.river_topo
  @r_topo.to_dom_string
end

def get_m
  @r_topo.m
end

def get_n
  @r_topo.n
end


