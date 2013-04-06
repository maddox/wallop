$ ->

  $('.channel').click ->
    self = $(this)
    channel = self.data('channel')
    tuneUrl = '/channels/' + channel + '/tune'
    playerUrl = '/channels/' + channel

    $.get(tuneUrl, '', (data)->
      window.location.href = playerUrl
      )

    return false;

