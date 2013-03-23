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

  drawScore: (score) ->
    @ctx.save()
    @ctx.translate(0, -20)
    @ctx.font = "normal 20px Share Tech Mono"
    @ctx.fillStyle = '#fff'
    @ctx.fillText("Score: " + score, 0, 0)
    @ctx.restore()

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

  drawPlayer: (x, y) ->
    x *= 25
    y *= 25
    @ctx.save()
    @ctx.fillStyle = '#ff0'
    @ctx.fillRect(x, y, 25, 25)
    @ctx.restore()

  clear: ->
    @ctx.restore()
    @ctx.clearRect 0, 0, @width, @height
    @ctx.save()
    @ctx.translate(0, 40)

class KeyboardInputComponent
  MAPPING = {
    'left': 37,
    'right': 39,
    'down': 40,
    'up': 38
  }

  constructor: ->
    true

  start: ->
    @keys = []
    window.onkeydown = @keyDown
    window.onkeyup = @keyUp

  isKeyDown: (key) ->
    @keys[MAPPING[key]]

  keyDown: (e) =>
    @keys[e.keyCode] = true

    # prevent arrow keys from scrolling page
    if e.keyCode >= 37 && e.keyCode <= 40
      return false

  keyUp: (e) =>
    @keys[e.keyCode] = false

  moveLeft: ->
    @isKeyDown('left')

  moveRight: ->
    @isKeyDown('right')

  moveUp: ->
    @isKeyDown('up')

  moveDown: ->
    @isKeyDown('down')

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
    return undefined unless @isInBounds(x, y)
    @tiles[y][x]

  isInBounds: (x, y) ->
    (x >= 0 && x <= @width) && (y >= 0 && y <= @height)

  eatFood: (x, y) ->
    @tiles[y][x] = Tile.empty

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

Direction =
  left:  0,
  right: 1,
  up:    2,
  down:  3

class Player
  MOVE_DELAY = 20

  constructor: (@map) ->
    # TODO get start position from map
    @x = 1
    @y = 1
    @direction = Direction.down
    @nextMoveIn = MOVE_DELAY

  update: ->
    @nextMoveIn -= 1
    if @nextMoveIn <= 0
      newPosition = @newPosition(@direction)
      if newPosition
        [@x, @y] = newPosition
        @nextMoveIn = MOVE_DELAY

  canMove: (direction) ->
    @newPosition(direction) != undefined

  newPosition: (direction) ->
    newX = @x
    newY = @y
    switch direction
      when Direction.left  then newX -= 1
      when Direction.right then newX += 1
      when Direction.up    then newY -= 1
      when Direction.down  then newY += 1
    if @map.tileType(newX, newY) != Tile.wall
      [newX, newY]
    else
      undefined

  moveLeft: ->
    if @canMove(Direction.left)
      @direction = Direction.left

  moveRight: ->
    if @canMove(Direction.right)
      @direction = Direction.right

  moveUp: ->
    if @canMove(Direction.up)
      @direction = Direction.up

  moveDown: ->
    if @canMove(Direction.down)
      @direction = Direction.down

class Scorer
  constructor: (@map, @player) ->
    @score = 0

  update: ->
    if @map.tileType(@player.x, @player.y) == Tile.food
      @map.eatFood(@player.x, @player.y)
      @incrementScore()

  incrementScore: ->
    @score += 10

class Kovas
  constructor: (@options) ->
    true

  run: ->
    @map = new Map()
    @player = new Player(@map)
    @scorer = new Scorer(@map, @player)
    @options.input.start()
    @options.renderer.start()
    window.requestAnimationFrame @update

  update: =>
    # handle input
    if @options.input.moveLeft()
      @player.moveLeft()
    if @options.input.moveRight()
      @player.moveRight()
    if @options.input.moveUp()
      @player.moveUp()
    if @options.input.moveDown()
      @player.moveDown()
    @player.update()
    @scorer.update()

    # render
    @options.renderer.clear()
    @options.renderer.drawScore(@scorer.score)

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

    # player
    @options.renderer.drawPlayer(@player.x, @player.y)

    window.requestAnimationFrame @update
