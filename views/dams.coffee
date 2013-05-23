

class DamsApp

  constructor: () ->

    @terrain = new Terrain(this)
    @damsview = new DamsView()
    @damsview.render(@terrain.data)

    @topo = new TopoDiagram()



class Terrain

  constructor: (app) ->

    @app = app
    @source = new DataSource()
    @data = @source.getdata()



class DataSource

  constructor: () ->

    @canvas = document.getElementById("canvas")

    @code = {
      "a":"10"
      "b":"20"
      "c":"30"
      "d":"40"
      "e":"50"
      "f":"60"
      "g":"70"
      "h":"80"
      "i":"90"
      "j":"100"
      "k":"110"
      "l":"120"
      "m":"130"
      "n":"140"
      "A":"-10"
      "B":"-20"
      "C":"-30"
      "D":"-40"
      "E":"-50"
      "F":"-60"
      "G":"-70"
      "H":"-80"
      "I":"-90"
      "J":"-100"
      "K":"-110"
      "L":"-120"
      "M":"-130"
      "N":"-140"
      "x":"no-data"
      "Z":"MARK-PURPLE" }

    dstring = @canvas.getAttribute("data-terrain-map")

    dd = []
    for a in [0..40]
      ds = dstring[a*23..a*23+22]
      da = []
      for b in [0..22]
        ch = ds[b]
        el = @decode(ch)
        da[b] = el
        dd[a] = da
    @data = dd


  getdata: () ->
    return @data


  decode: (ch) ->
    str = @code[ch]
    elev = Number(str)
    return elev



class DamsView

  constructor: () ->

    @canvas = document.getElementById("canvas")
    @context = @canvas.getContext("2d")

    @colors = new ElevationPalette()

    @img = document.getElementById("terrain")
    @context.drawImage(@img,0,0)


  markhex: (a,b,elev) ->
    color = @colors.getcolor(elev)
    @fillhex(a,b,color)


  fillhex: (a,b,color) ->
    x = 35+a*18
    y = 29+b*24
    y = y+12 if (a%2 == 0)
    @context.fillStyle = color
    @context.beginPath()
    @context.moveTo(x,y)
    @context.lineTo(x+11,y)
    @context.lineTo(x+18,y+12)
    @context.lineTo(x+12,y+25)
    @context.lineTo(x-1,y+25)
    @context.lineTo(x-6,y+12)
    @context.lineTo(x,y)
    @context.fill()
    @context.closePath()


  render: (data) ->
    for a in [0..40]
      for b in [0..22]
        da = data[a]
        el = da[b]
        @markhex(a,b,el)
    @context.drawImage(@img,0,0)



class ElevationPalette

  constructor: () ->

    @elevationcolors = {
      "10":"#40d818"
      "20":"#48ca1a"
      "30":"#50bc1c"
      "40":"#58ae1e"
      "50":"#60a020"
      "60":"#689222"
      "70":"#708424"
      "80":"#787626"
      "90":"#806828"
      "100":"#885a2a"
      "110":"#904c2c"
      "120":"#983e2e"
      "130":"#a03030"
      "140":"#a82232"
      "water":"#6699ff"
      "watera":"#6699ff"
      "waterb":"#a399ff"
      "empty":"#666666"
      "no-data":"#339933" 
      "MARK-PURPLE":"#ff00ff" }

  getcolor: (elev) ->
    if elev<0
      if elev in [-10,-30,-50,-70,-90,-110,-130]
        color = @elevationcolors["watera"]
      else
        color = @elevationcolors["waterb"]
    else
      es = elev.toString()
      if @elevationcolors.hasOwnProperty(es)
        color = @elevationcolors[es]
      else
        color = @elevationcolors["no-data"]
      return color



class TopoDiagram

  constructor: () ->

    @tdata = new TData(this)
    @topoview = new TopoView()
    m = @tdata.m
    n = @tdata.n
    @topostring = @tdata.topostring
    @topoview.render(m,n,@topostring)



class TData

  constructor: () ->

    @canvas = document.getElementById("topo-grid")
    @m = @canvas.getAttribute("data-m")
    @n = @canvas.getAttribute("data-n")
    @topostring = @canvas.getAttribute("data-topo")



class TopoView

  constructor: () ->
    @canvas = document.getElementById("topo-grid")
    @context = @canvas.getContext("2d")


  render: (m,n,dstring) ->
    for k in [0..n-1]
      for j in [0..m-1]
        @drawcell(j,k)
        z = 4*(j+k*m)
        d4 = dstring[z..z+3]
        @connect(j,k,"N") if d4[0] == "c"
        @connect(j,k,"E") if d4[1] == "c"
        @connect(j,k,"S") if d4[2] == "c"
        @connect(j,k,"W") if d4[3] == "c"


  drawcell: (m,n) ->
    @canvas = document.getElementById("topo-grid")
    @context = @canvas.getContext("2d")

    @context.fillStyle = "#339933"
    x1 = 10+40*m
    y1 = 10+40*n
    @context.fillRect(x1,y1,20,20)

    label = (m+1).toString()+" , "+(n+1).toString()
    @context.fillStyle = "#000000"
    @context.textAlign = "center"
    x2 = x1+10
    y2 = y1+10
    @context.fillText(label,x2,y2)


  connect: (m,n,dir) ->
    @canvas = document.getElementById("topo-grid")
    @context = @canvas.getContext("2d")
    @context.strokeStyle = "#666666"
    @context.lineWidth = 3
    switch dir
      when "N"
        @connect(m,n-1,"S")
      when "W"
        @connect(m-1,n,"E")
      when "S"
        x1 = 20+m*40
        y1 = 30+n*40
        @context.moveTo(x1,y1)
        @context.lineTo(x1,y1+20)
      when "E"
        x1 = 30+m*40
        y1 = 20+n*40
        @context.moveTo(x1,y1)
        @context.lineTo(x1+20,y1)
    @context.stroke()



#   #   #   #   #   #
#   Global Scope Statements
#   #   #   #   #   #


start = () ->
  @app = new DamsApp()


window.onload = start


