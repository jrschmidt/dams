

class DamsApp

  constructor: () ->

    @terrain = new Terrain(this)
    @view = new View()
    @view.render(@terrain.data)



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
      "x":"no-data" }

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



class View

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
      "water":"#a399ff"
      "empty":"#339966"
      "no-data":"#993399" }

  getcolor: (elev) ->
    if elev<0
      color = @elevationcolors["water"]
    else
      es = elev.toString()
      if @elevationcolors.hasOwnProperty(es)
        color = @elevationcolors[es]
      else
        color = @elevationcolors["no-data"]
      return color



#   #   #   #   #   #
#   Global Scope Statements
#   #   #   #   #   #


start = () ->
  @app = new DamsApp()


window.onload = start


