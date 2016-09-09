$ ->

  bitrate = ->
    localStorage.bitrate || "1000k"

  resolution = ->
    localStorage.resolution || "1280x720"

  loadSettings = ->
    $('.resolution-setting').each (i, e)  =>
      if $(e).val() == resolution()
        $(e).attr('checked', 'checked')

    $('.bitrate-setting').each (i, e)  =>
      if $(e).val() == bitrate()
        $(e).attr('checked', 'checked')


  $('.resolution-setting').change ->
    self = $(this)
    localStorage.resolution = self.val()

  $('.bitrate-setting').change ->
    self = $(this)
    localStorage.bitrate = self.val()




  loadSettings()
