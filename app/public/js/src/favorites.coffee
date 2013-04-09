$ ->

  $('.favorite').click ->
    self = $(this)
    starred = self.hasClass('starred')
    channel = self.data('channel')
    icon = self.find('i')

    if starred
      url = '/channels/favorites'
      method = 'delete'
    else
      url = '/channels/favorites'
      method = 'post'

    data = 'channel=' + channel



    $.ajax url,
        type: method
        dataType: 'json'
        data: data
        beforeSend: (jqXHR) ->
          jqXHR.setRequestHeader("Accept", "application/json")
        success: (data, textStatus, jqXHR) ->
          console.log(method)
          if method is 'post'
            self.addClass('starred')
            icon.removeClass('icon-star-empty')
            icon.addClass('icon-star')
          else
            self.removeClass('starred')
            icon.removeClass('icon-star')
            icon.addClass('icon-star-empty')

    return false;

