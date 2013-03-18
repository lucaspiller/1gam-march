# Helper for raf so we can avoid all the browser
# inconsistencies later on
window.requestAnimationFrame = (() ->
  return window.requestAnimationFrame ||
    window.webkitRequestAnimationFrame ||
    window.mozRequestAnimationFrame ||
    window.msRequestAnimationFrame ||
    window.oRequestAnimationFrame ||
    (f) ->
      window.setTimeout(f,1e3/60)
)()

# Create a new instance of the game and run it
document.addEventListener 'DOMContentLoaded', ->
  game = new Kovas {
    renderer: new CanvasRendererComponent(document.getElementById('kovas')),
    input: new KeyboardInputComponent
  }
  game.run()

class CanvasRendererComponent
  constructor: (@element) ->
    @width = window.innerWidth
    @height = window.innerHeight

  start: ->
    @canvas = document.createElement 'canvas'
    @canvas.width = @width - 50
    @canvas.height = @height - 50
    @ctx = @canvas.getContext '2d'
    @element.appendChild @canvas

  drawEmptyTile: (x, y) ->
    # Nothing to render
    true

  drawWallTile: (x, y) ->
    @ctx.save()
    @ctx.fillStyle = '#00f'
    @ctx.fillRect(x * 25, y * 25, 25, 25)
    @ctx.restore()

  drawFoodTile: (x, y) ->
    x = (x * 25) + 10
    y = (y * 25) + 10
    @ctx.save()
    @ctx.fillStyle = '#fff'
    @ctx.fillRect(x, y, 5, 5)
    @ctx.restore()

  clear: ->
    @ctx.clearRect 0, 0, @width, @height

class KeyboardInputComponent
  MAPPING = {
    'left': 37,
    'right': 39,
    'down': 40,
    'up': 38
  }

  constructor: ->

  start: ->
    @keys = []
    @keysUp = []
    @keysDown = []
    window.onkeydown = @keyDown
    window.onkeyup = @keyUp

  isKeyDown: (key) ->
    @keys[MAPPING[key]]

  keyWentUp: (key) ->
    @keysUp[MAPPING[key]]

  keyWentDown: (key) ->
    @keysDown[MAPPING[key]]

  keyDown: (e) =>
    @keys[e.keyCode] = true
    @keysDown[e.keyCode] = true

    # prevent arrow keys from scrolling page
    if e.keyCode >= 37 && e.keyCode <= 40
      return false

  keyUp: (e) =>
    @keys[e.keyCode] = false
    @keysUp[e.keyCode] = true

  update: ->
    @keysUp = []
    @keysDown = []

  moveLeft: ->
    @keyWentDown('left')

  moveRight: ->
    @keyWentDown('right')

  moveUp: ->
    @keyWentDown('up')

  moveDown: ->
    @keyWentDown('down')

# Singleton to keep track of tile types
Tile =
  empty: 0
  wall:  1
  food:  2

class Map
  MAPS = [
    {
      data: """
####################
#....#........#....#
#.##.#.######.#.##.#
#.#..............#.#
#.#.##.#.####.##.#.#
#......#....#......#
#.#.##.####.#.##.#.#
#.#..#...........#.#
#.##.#.######.#.##.#
#....#........#....#
####################
      """
    }
  ]

  constructor: (@levelIndex = 0) ->
    @tiles = {}
    @width = 0
    @height = 0
    @_loadLevel MAPS[@levelIndex].data

  tileType: (x, y) ->
    @tiles[y][x]

  _loadLevel: (data) ->
    x = 0
    y = 0
    for char, index in data.split ''
      if char == "\n"
        y += 1
        x = 0
      else
        if x > @width
          @width = x
        if y > @height
          @height = y

        switch char
          when "."
            @tiles[y] ||= {}
            @tiles[y][x] = Tile.food
            x += 1
          when "#"
            @tiles[y] ||= {}
            @tiles[y][x] = Tile.wall
            x += 1
          else
            throw "Don't know what to do with #{char.charCodeAt(0)} #{char}!"

class Kovas
  constructor: (@options) ->
    true

  run: ->
    @map = new Map()
    @options.input.start()
    @options.renderer.start()
    window.requestAnimationFrame @update

  update: =>
    # handle input
    @options.input.update()

    # render
    @options.renderer.clear()

    # render map
    for y in [0..@map.height]
      for x in [0..@map.width]
        switch @map.tileType(x, y)
          when Tile.empty
            @options.renderer.drawEmptyTile(x, y)
          when Tile.wall
            @options.renderer.drawWallTile(x, y)
          when Tile.food
            @options.renderer.drawFoodTile(x, y)

    window.requestAnimationFrame @update
