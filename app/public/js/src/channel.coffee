$ ->
  timer = null

  videoPlayer = ->
    $("#video-player")[0]

  statusUrl = ->
    $('#video-player').data('status-url')

  tuneUrl = ->
    $('#video-player').data('tune-url')

  playUrl = ->
    $('#video-player').data('play-url')

  startLoading = (title=null, message=null) ->
    spinOpts = {
      className: 'spinner', # The CSS class to assign to the spinner
      top: '2px', # Top position relative to parent in px
    }

    $('.alert').spin(spinOpts)

    $('.alert h4').html(title)
    $('.alert').append(message)

    $('.alert').show()

  stopLoading = (title=null, message=null) ->
    $('.alert').spin(false)

    $('.alert h4').html(title)
    $('.alert').append(message)

    $('.alert').hide() if not title? and not message?

  tune = ->
    console.log('tuning channel')
    $.ajax tuneUrl(),
      type: 'post'
      dataType: 'json'
      beforeSend: (jqXHR) ->
        jqXHR.setRequestHeader("Accept", "application/json")
        startLoading("Tuning channel...")
      success: (data, textStatus, jqXHR) ->
        timer = setInterval ->
          checkStatus()
        , 1000

  play = ->
    deviceAgent = navigator.userAgent.toLowerCase()
    agentID = deviceAgent.match(/(iphone|ipod|ipad)/)

    $(videoPlayer()).show()
    videoPlayer().src = playUrl()
    videoPlayer().play()

    if agentID && agentID[1] == 'iphone'
      window.location.href = playUrl()


  checkStatus = ->
    $.ajax statusUrl(),
        type: 'get'
        dataType: 'json'
        beforeSend: (jqXHR) ->
          jqXHR.setRequestHeader("Accept", "application/json")
          startLoading('Preparing stream...')
        success: (data, textStatus, jqXHR) ->
          console.log(data)
          if data.ready
            clearInterval(timer)
            stopLoading('Stream is ready!', 'The stream is ready to play.')
            play()
        error: (jqXHR, textStatus, errorThrown) ->
          console.log(textStatus)
          console.log(errorThrown)
          tune()


  if videoPlayer()?
    checkStatus()
