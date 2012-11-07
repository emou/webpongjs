exports = window

Message = exports.WebPongJSMessage

class Client

  @KEYS:
    up: 38,
    down: 40,
    j: 74,
    k: 75,

  constructor: (@conf, @game, @board) ->
    @blockName = null
    @context = @board.getContext '2d'
    @controlledBlock = null
    @initialDrift = null
    @messageBoard = document.getElementById(@conf.messageBoard.id)
    @callbacks =
      init: this.onInit,
      start: this.onStart,
      update: this.onUpdate,
      drop: this.onDrop

  start: (@sock) ->
    @sock = @sock ? new SockJS "http://#{@conf.server.addr}:#{@conf.server.port}#{@conf.server.prefix}"
    @sock.onmessage = (e) =>
      try
        msg = Message.parse(e.data)
      catch e
        console.error "Error parsing message from server: #{e}"
        throw e

      handler = @callbacks[msg.type]
      if handler?
        handler msg
      else
        console.error "Ignoring unknown message #{msg}"

    @sock.onopen = =>
      this.userMessage 'Connected to server'
      this.send 'init', null

    @sock.onclose = =>
      this.userMessage 'Server closed the connection. Refresh the page to try again'
      @game.stop()

  onInit: (msg) =>
    @initialDrift = Number(msg.data.timestamp) - (new Date).getTime()
    @blockName = msg.data.block
    @controlledBlock = @game.state.blocks[msg.data.block]
    @game.setBlock @blockName
    this.userMessage 'Waiting for other player'

  onStart: (msg) =>
    @game.start @initialDrift
    @game.on 'update', this.onGameUpdate
    @game.on 'game over', this.onGameOver
    @game.on 'input', this.onGameInput
    document.onkeydown = this.onKeyDown
    document.onkeyup = this.onKeyUp
    this.userMessage "Game running. Use the keyboard to control the #{@blockName} block"

  onUpdate: (msg) =>
    @game.addServerUpdate msg.data

  onDrop: (msg) =>
    @game.stop()
    this.userMessage 'Other player dropped. Waiting for a new player to connect'

  send: (msgType, msgData) ->
    @sock.send (new Message msgType, msgData).stringify()

  userMessage: (msg) ->
    @messageBoard.innerHTML = msg

  onKeyDown: (ev) =>
    switch ev.keyCode
      when Client.KEYS.up, Client.KEYS.k
        @controlledBlock.movingUp = 1
      when Client.KEYS.down, Client.KEYS.j
        @controlledBlock.movingDown = 1

  onKeyUp: (ev) =>
    switch ev.keyCode
      when Client.KEYS.up, Client.KEYS.k
        @controlledBlock.movingUp = 0
      when Client.KEYS.down, Client.KEYS.j
        @controlledBlock.movingDown = 0

  drawLeftBlock: (y) ->
    @context.beginPath()
    @context.fillStyle = @conf.block.left.color
    @context.fillRect 0, y, @conf.block.size.x, @conf.block.size.y
    @context.closePath()
    @context.fill()

  drawRightBlock: (y) ->
    @context.beginPath()
    @context.fillStyle = @conf.block.right.color
    @context.fillRect @conf.board.size.x - @conf.block.size.x, y,
      @conf.block.size.x, @conf.block.size.y
    @context.closePath()
    @context.fill()

  drawBall: (x, y) ->
    @context.beginPath()
    @context.fillStyle = @conf.ball.color
    @context.arc x, y, @conf.ball.radius, 0, 2 * Math.PI, false
    @context.closePath()
    @context.fill()

  onGameUpdate: (ev, state) =>
    this.drawState ev, state

  onGameInput: (ev, inputEntry) =>
    this.send 'input', inputEntry

  drawState: (ev, state) =>
    @context.clearRect 0, 0, @board.width, @board.height
    this.drawBall state.ball.x, state.ball.y
    this.drawLeftBlock state.blocks.left.y
    this.drawRightBlock state.blocks.right.y

  onGameOver: (ev, data) =>
    # Temp placeholder
    window.alert 'Game over!'

exports.WebPongJSClient = Client
