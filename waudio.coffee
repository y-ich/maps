# (C) 2013 ICHIKAWA, Yuji (New 3 Rs)

class WAudio
    @NO_SOURCE: 0
    @LOADING: 1
    @LOADED: 2

    @context: if AudioContext? then new AudioContext() else if webkitAudioContext? then new webkitAudioContext() else null
    @unlock: ->
        # (iOS用) 何かのユーザーイベントの際に呼び出し、Web Audioを有効にする。
        # 空のソースを再生
        source = @context.createBufferSource()
        source.buffer = @context.createBuffer 1, 1, 22050
        source.connect @context.destination
        source.noteOn 0

    constructor: (@src) ->
        @forcePlay = false
        @state = WAudio.NO_SOURCE

    load: ->
        xhr = new XMLHttpRequest()
        xhr.open 'GET', @src
        xhr.responseType = 'arraybuffer'
        xhr.onload = =>
            WAudio.context.decodeAudioData xhr.response, (buffer) =>
                @buffer = buffer
                @state = WAudio.LOADED
                @play() if @forcePlay
        xhr.send()
        @state = WAudio.LOADING

    play: ->
        switch @state
            when WAudio.NO_SOURCE
                @forcePlay = true
                @load()
            when WAudio.LOADING
                @forcePlay = true
            when WAudio.LOADED
                @source = WAudio.context.createBufferSource()
                @source.buffer = @buffer
                @source.connect WAudio.context.destination
                @source.noteOn 0
    pause: ->
        @source.noteOff 0

