$ ->

  videoPlayer = ->
    _V_("video-player")

  videoPlayerExists = ->
    $('.video-js')[0]?

  statusUrl = ->
    $('video').data('status-url')

  playUrl = ->
    $('video').data('play-url')

  checkStatus = ->
    $.get(statusUrl(), '', (data)->
      if data.ready
        clearInterval(timer)
        videoPlayer().src(playUrl())
        videoPlayer().play()
    , 'json')

  if videoPlayerExists()
    checkStatus()
    timer = setInterval ->
      checkStatus()
    , 1000


