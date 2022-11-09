// Generated by CoffeeScript 2.7.0
(function() {
  var DamsApp, DamsView, DataSource, ElevationPalette, TData, Terrain, TopoDiagram, TopoView, start;

  DamsApp = class DamsApp {
    constructor() {
      this.terrain = new Terrain(this);
      this.damsview = new DamsView();
      this.damsview.render(this.terrain.data);
      this.topo = new TopoDiagram();
    }

  };

  Terrain = class Terrain {
    constructor(app) {
      this.app = app;
      this.source = new DataSource();
      this.data = this.source.getdata();
    }

  };

  DataSource = class DataSource {
    constructor() {
      var a, b, ch, da, dd, ds, dstring, el, i, l;
      this.canvas = document.getElementById("canvas");
      this.code = {
        "a": "10",
        "b": "20",
        "c": "30",
        "d": "40",
        "e": "50",
        "f": "60",
        "g": "70",
        "h": "80",
        "i": "90",
        "j": "100",
        "k": "110",
        "l": "120",
        "m": "130",
        "n": "140",
        "A": "-10",
        "B": "-20",
        "C": "-30",
        "D": "-40",
        "E": "-50",
        "F": "-60",
        "G": "-70",
        "H": "-80",
        "I": "-90",
        "J": "-100",
        "K": "-110",
        "L": "-120",
        "M": "-130",
        "N": "-140",
        "x": "no-data",
        "Z": "MARK-PURPLE"
      };
      dstring = this.canvas.getAttribute("data-terrain-map");
      dd = [];
      for (a = i = 0; i <= 40; a = ++i) {
        ds = dstring.slice(a * 23, +(a * 23 + 22) + 1 || 9e9);
        da = [];
        for (b = l = 0; l <= 22; b = ++l) {
          ch = ds[b];
          el = this.decode(ch);
          da[b] = el;
          dd[a] = da;
        }
      }
      this.data = dd;
    }

    getdata() {
      return this.data;
    }

    decode(ch) {
      var elev, str;
      str = this.code[ch];
      elev = Number(str);
      return elev;
    }

  };

  DamsView = class DamsView {
    constructor() {
      this.canvas = document.getElementById("canvas");
      this.context = this.canvas.getContext("2d");
      this.colors = new ElevationPalette();
      this.img = document.getElementById("terrain");
      this.context.drawImage(this.img, 0, 0);
    }

    markhex(a, b, elev) {
      var color;
      color = this.colors.getcolor(elev);
      return this.fillhex(a, b, color);
    }

    fillhex(a, b, color) {
      var x, y;
      x = 35 + a * 18;
      y = 29 + b * 24;
      if (a % 2 === 0) {
        y = y + 12;
      }
      this.context.fillStyle = color;
      this.context.beginPath();
      this.context.moveTo(x, y);
      this.context.lineTo(x + 11, y);
      this.context.lineTo(x + 18, y + 12);
      this.context.lineTo(x + 12, y + 25);
      this.context.lineTo(x - 1, y + 25);
      this.context.lineTo(x - 6, y + 12);
      this.context.lineTo(x, y);
      this.context.fill();
      return this.context.closePath();
    }

    render(data) {
      var a, b, da, el, i, l;
      for (a = i = 0; i <= 40; a = ++i) {
        for (b = l = 0; l <= 22; b = ++l) {
          da = data[a];
          el = da[b];
          this.markhex(a, b, el);
        }
      }
      return this.context.drawImage(this.img, 0, 0);
    }

  };

  ElevationPalette = class ElevationPalette {
    constructor() {
      this.elevationcolors = {
        "10": "#40d818",
        "20": "#48ca1a",
        "30": "#50bc1c",
        "40": "#58ae1e",
        "50": "#60a020",
        "60": "#689222",
        "70": "#708424",
        "80": "#787626",
        "90": "#806828",
        "100": "#885a2a",
        "110": "#904c2c",
        "120": "#983e2e",
        "130": "#a03030",
        "140": "#a82232",
        "water": "#6699ff",
        "watera": "#6699ff",
        "waterb": "#a399ff",
        "empty": "#666666",
        "no-data": "#339933",
        "MARK-PURPLE": "#ff00ff"
      };
    }

    getcolor(elev) {
      var color, es;
      if (elev < 0) {
        if (elev === (-10) || elev === (-30) || elev === (-50) || elev === (-70) || elev === (-90) || elev === (-110) || elev === (-130)) {
          return color = this.elevationcolors["watera"];
        } else {
          return color = this.elevationcolors["waterb"];
        }
      } else {
        es = elev.toString();
        if (this.elevationcolors.hasOwnProperty(es)) {
          color = this.elevationcolors[es];
        } else {
          color = this.elevationcolors["no-data"];
        }
        return color;
      }
    }

  };

  TopoDiagram = class TopoDiagram {
    constructor() {
      var m, n;
      this.tdata = new TData(this);
      this.topoview = new TopoView();
      m = this.tdata.m;
      n = this.tdata.n;
      this.topostring = this.tdata.topostring;
      this.topoview.render(m, n, this.topostring);
    }

  };

  TData = class TData {
    constructor() {
      this.canvas = document.getElementById("topo-grid");
      this.m = this.canvas.getAttribute("data-m");
      this.n = this.canvas.getAttribute("data-n");
      this.topostring = this.canvas.getAttribute("data-topo");
    }

  };

  TopoView = class TopoView {
    constructor() {
      this.canvas = document.getElementById("topo-grid");
      this.context = this.canvas.getContext("2d");
    }

    render(m, n, dstring) {
      var d4, i, j, k, ref, results, z;
      results = [];
      for (k = i = 0, ref = n - 1; (0 <= ref ? i <= ref : i >= ref); k = 0 <= ref ? ++i : --i) {
        results.push((function() {
          var l, ref1, results1;
          results1 = [];
          for (j = l = 0, ref1 = m - 1; (0 <= ref1 ? l <= ref1 : l >= ref1); j = 0 <= ref1 ? ++l : --l) {
            this.drawcell(j, k);
            z = 4 * (j + k * m);
            d4 = dstring.slice(z, +(z + 3) + 1 || 9e9);
            if (d4[0] === "c") {
              this.connect(j, k, "N");
            }
            if (d4[1] === "c") {
              this.connect(j, k, "E");
            }
            if (d4[2] === "c") {
              this.connect(j, k, "S");
            }
            if (d4[3] === "c") {
              results1.push(this.connect(j, k, "W"));
            } else {
              results1.push(void 0);
            }
          }
          return results1;
        }).call(this));
      }
      return results;
    }

    drawcell(m, n) {
      var label, x1, x2, y1, y2;
      this.canvas = document.getElementById("topo-grid");
      this.context = this.canvas.getContext("2d");
      this.context.fillStyle = "#339933";
      x1 = 10 + 40 * m;
      y1 = 10 + 40 * n;
      this.context.fillRect(x1, y1, 20, 20);
      label = (m + 1).toString() + " , " + (n + 1).toString();
      this.context.fillStyle = "#000000";
      this.context.textAlign = "center";
      x2 = x1 + 10;
      y2 = y1 + 10;
      return this.context.fillText(label, x2, y2);
    }

    connect(m, n, dir) {
      var x1, y1;
      this.canvas = document.getElementById("topo-grid");
      this.context = this.canvas.getContext("2d");
      this.context.strokeStyle = "#666666";
      this.context.lineWidth = 3;
      switch (dir) {
        case "N":
          this.connect(m, n - 1, "S");
          break;
        case "W":
          this.connect(m - 1, n, "E");
          break;
        case "S":
          x1 = 20 + m * 40;
          y1 = 30 + n * 40;
          this.context.moveTo(x1, y1);
          this.context.lineTo(x1, y1 + 20);
          break;
        case "E":
          x1 = 30 + m * 40;
          y1 = 20 + n * 40;
          this.context.moveTo(x1, y1);
          this.context.lineTo(x1 + 20, y1);
      }
      return this.context.stroke();
    }

  };

  //   #   #   #   #   #
  //   Global Scope Statements
  //   #   #   #   #   #
  start = function() {
    return this.app = new DamsApp();
  };

  window.onload = start;

}).call(this);