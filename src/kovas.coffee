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

# Bubble Sort!
Array::sortBy = (fun) ->
  for i in [0...(@length - 1)]
    for j in [0...(@length - 1) - i]
      js = fun(this[j])
      jsn = fun(this[j+1])
      [this[j], this[j+1]] = [this[j+1], this[j]] if fun(this[j]) > fun(this[j+1])
  this

class CanvasRendererComponent
  constructor: (@element) ->
    @width = window.innerWidth
    @height = window.innerHeight
    @drawIntroState = 40

  start: ->
    @canvas = document.createElement 'canvas'
    @canvas.width = @width - 50
    @canvas.height = @height - 50
    @ctx = @canvas.getContext '2d'
    @ctx.font = "normal 20px Share Tech Mono"
    @element.appendChild @canvas

  drawScore: (score) ->
    @ctx.save()
    @ctx.translate(0, -20)
    @ctx.fillStyle = '#fff'
    @ctx.fillText("Score: " + score, 0, 0)
    @ctx.restore()

  drawIntro: ->
    if @drawIntroState > 0
      @ctx.save()
      @ctx.fillStyle = '#fff'
      @ctx.fillText("Press SPACE to begin", 178, 295)
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

  drawGhost: (x, y, colour) ->
    x *= 25
    y *= 25
    @ctx.save()
    @ctx.fillStyle = colour
    @ctx.fillRect(x, y, 25, 25)
    @ctx.restore()

  clear: ->
    @drawIntroState -= 1
    if @drawIntroState < -40
      @drawIntroState = 40
    @ctx.restore()
    @ctx.clearRect 0, 0, @width, @height
    @ctx.save()
    @ctx.translate(0, 40)

class KeyboardInputComponent
  MAPPING = {
    'left': 37,
    'right': 39,
    'down': 40,
    'up': 38,
    'space': 32
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
    if (e.keyCode >= 37 && e.keyCode <= 40) || e.keyCode == 32
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

  startGame: ->
    @isKeyDown('space')

# Singleton to keep track of tile types
Tile =
  empty: 0
  wall:  1
  food:  2

class Map
  MAPS = [
    {
      data: """
#######################
#..........#..........#
#.###.####.#.####.###.#
#.###.####.#.####.###.#
#.....................#
#.###.##.#####.##.###.#
#......#...#...#......#
######.###.#.###.######
#....#...........#....#
#.##.#.#### ####.#.##.#
#.##.#.#       #.#.##.#
#......#   g   #......#
#.##.#.#       #.#.##.#
#.##.#.#########.#.##.#
#....#...........#....#
######.###.#.###.######
#......#...#...#......#
#.###.##.#####.##.###.#
#.....................#
#.###.####.#.####.###.#
#.###.####.#.####.###.#
#..........#..........#
#######################
      """
    }
  ]

  constructor: (@levelIndex = 0) ->
    @tiles = {}
    @width = 0
    @height = 0
    @remainingFood = 0
    @_loadLevel MAPS[@levelIndex].data

  tileType: (x, y) ->
    return undefined unless @isInBounds(x, y)
    @tiles[y][x]

  isInBounds: (x, y) ->
    (x >= 0 && x <= @width) && (y >= 0 && y <= @height)

  eatFood: (x, y) ->
    @remainingFood -= 1
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
            @remainingFood += 1
            @tiles[y] ||= {}
            @tiles[y][x] = Tile.food
            x += 1
          when "#"
            @tiles[y] ||= {}
            @tiles[y][x] = Tile.wall
            x += 1
          when " "
            @tiles[y] ||= {}
            @tiles[y][x] = Tile.empty
            x += 1
          when "g"
            @tiles[y] ||= {}
            @tiles[y][x] = Tile.empty
            @ghostStartPosition = [x, y]
            x += 1
          else
            throw "Don't know what to do with #{char.charCodeAt(0)} #{char}!"

Direction =
  left:  0,
  right: 1,
  up:    2,
  down:  3

class Actor
  constructor: (@map) ->
    # TODO get start position from map
    [@x, @y] = @startPosition()
    @direction = @startDirection()
    @nextMoveIn = @moveDelay()

  update: ->
    @nextMoveIn -= 1
    if @nextMoveIn <= 0
      newPosition = @newPosition(@direction)
      if newPosition
        [@x, @y] = newPosition
        @nextMoveIn = @moveDelay()
        @movedTile()

  canMove: (direction) ->
    @newPosition(direction) != undefined

  addToPosition: (direction, amount = 1) ->
    newX = @x
    newY = @y
    switch direction
      when Direction.left  then newX -= amount
      when Direction.right then newX += amount
      when Direction.up    then newY -= amount
      when Direction.down  then newY += amount
    [newX, newY]

  newPosition: (direction) ->
    [newX, newY] = @addToPosition(direction)
    if @map.tileType(newX, newY) != Tile.wall
      [newX, newY]
    else
      undefined

  movedTile: ->
    true

class Player extends Actor
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

  moveDelay: ->
    20

  # TODO get start position from map
  startPosition: ->
    [1, 1]

  startDirection: ->
    Direction.down

class Ghost extends Actor
  constructor: (@map, @player) ->
    super(@map)

  update: ->
    @nextMoveIn -= 1
    if @nextMoveIn <= 0
      newPosition = @newPosition(@direction)
      if newPosition
        [@x, @y] = newPosition
        @nextMoveIn = @moveDelay()
        @movedTile()

  movedTile: ->
    # simple math...
    # 1) find which directions we can move in
    @canMoveUp = @direction != Direction.down && @canMove(Direction.up)
    @canMoveLeft = @direction != Direction.right && @canMove(Direction.left)
    @canMoveDown = @direction != Direction.up && @canMove(Direction.down)
    @canMoveRight = @direction != Direction.left && @canMove(Direction.right)

    target = @getTarget()

    # 2) find the target distance if we move into that tile
    if @canMoveUp
      [x, y] = @newPosition(Direction.up)
      @upDistance = @calculateDistance(x, y, target.x, target.y)
    else
      @upDistance = Infinity

    if @canMoveLeft
      [x, y] = @newPosition(Direction.left)
      @leftDistance = @calculateDistance(x, y, target.x, target.y)
    else
      @leftDistance = Infinity

    if @canMoveDown
      [x, y] = @newPosition(Direction.down)
      @downDistance = @calculateDistance(x, y, target.x, target.y)
    else
      @downDistance = Infinity

    if @canMoveRight
      [x, y] = @newPosition(Direction.right)
      @rightDistance = @calculateDistance(x, y, target.x, target.y)
    else
      @rightDistance = Infinity

    # 3) bubble sort the distances to find the direction which will put us
    # closest to the target
    distances = [
      { direction: Direction.up, distance: @upDistance },
      { direction: Direction.left, distance: @leftDistance },
      { direction: Direction.down, distance: @downDistance },
      { direction: Direction.right, distance: @rightDistance }
    ]

    distances.sortBy (e) ->
      e.distance

    @direction = distances[0].direction

  calculateDistance: (x, y, tx, ty) ->
    dx = Math.abs(tx - x)
    dy = Math.abs(ty - y)
    dx + dy

  moveDelay: ->
    30

  startDirection: ->
    Math.floor(Math.random() * 2)

  startPosition: ->
    [x, y] = @map.ghostStartPosition
    [x + Math.round((Math.random() * 2) - 1), y + Math.round((Math.random() * 2) - 1)]

  getTarget: ->
    @player

class RedGhost extends Ghost
  colour: '#f00'

  chaseTarget: ->
    [0, 3]

class PinkGhost extends Ghost
  colour: '#f9c'

  getTarget: ->
    [x, y] = @player.addToPosition(@player.position, 4)
    { x: x, y: y }

  moveDelay: ->
    30

  chaseTarget: ->
    [@map.width, 3]

class CyanGhost extends Ghost
  colour: '#6ff'

  getTarget: ->
    [x, y] = @player.addToPosition(@player.position, 6)
    { x: x, y: y }

  moveDelay: ->
    35

  chaseTarget: ->
    [0, @map.height - 3]

class OrangeGhost extends Ghost
  MODE_PLAYER: 0
  MODE_CHASE: 1

  colour: '#f93'

  getTarget: ->
    if @targeting_mode == @MODE_PLAYER
      if @calculateDistance(@x, @y, @player.x, @player.y) < 8
        @targeting_mode = @MODE_CHASE
      @player
    else
      [x, y] = @chaseTarget()
      if @calculateDistance(@x, @y, @player.x, @player.y) >= 8
        @targeting_mode = @MODE_PLAYER
      { x: x, y: y }

  moveDelay: ->
    40

  chaseTarget: ->
    [@map.width, @map.height - 3]


class Scorer
  constructor: (@map, @player, @ghosts, @gameWinCallback, @gameOverCallback) ->
    @score = 0

  update: ->
    for ghost in @ghosts
      if ghost.x == @player.x && ghost.y == @player.y
        return @loseLife()

    if @map.tileType(@player.x, @player.y) == Tile.food
      @map.eatFood(@player.x, @player.y)
      @incrementScore()

    if @map.remainingFood == 0
      @gameWinCallback()

  incrementScore: ->
    @score += 10

  loseLife: ->
    @gameOverCallback()

GameMode =
  intro: 0,
  play:  1,
  won:   2,
  lost:  3

class Kovas
  constructor: (@options) ->
    true

  run: ->
    @mode = GameMode.intro
    @map = new Map()
    @ghosts = []
    @options.input.start()
    @options.renderer.start()
    window.requestAnimationFrame @update

  gameStart: ->
    if @map.remainingFood == 0
      @map = new Map()
    @player = new Player(@map)
    @ghosts = [
      new RedGhost(@map, @player),
      new PinkGhost(@map, @player),
      new CyanGhost(@map, @player),
      new OrangeGhost(@map, @player),
    ]
    @scorer = new Scorer(@map, @player, @ghosts, @gameWin, @gameOver)
    @mode = GameMode.play

  gameWin: =>
    @mode = GameMode.won

  gameOver: =>
    @mode = GameMode.lost

  update: =>
    if @mode == GameMode.play
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

    # update ghosts
    for ghost in @ghosts
      ghost.update()

    # render
    @options.renderer.clear()

    if @scorer
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
    if @player
      @options.renderer.drawPlayer(@player.x, @player.y)

    for ghost in @ghosts
      @options.renderer.drawGhost(ghost.x, ghost.y, ghost.colour)

    if @mode != GameMode.play
      @options.renderer.drawIntro()
      if @options.input.startGame()
        @gameStart()

    window.requestAnimationFrame @update
