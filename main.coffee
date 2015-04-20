---
---


DEBUG = false

TITLE = document.title

API_URL = 'http://api.citybik.es'

DEFAULT_NETWORK =
  id: 'dublinbikes'
  name: 'dublinbikes'
  href: '/v2/networks/dublinbikes'
  company: 'JCDecaux'
  location:
    city: 'Dublin'
    country: 'IE'
    latitude: 53.3498053
    longitude: -6.2603097

class App

  constructor: ->
    @stations = new Stations
    @networks = new Networks @stations

    $(window).on 'hashchange', => @hashchange()

  run: ->
    unless @hashchange()
      network = JSON.parse localStorage.getItem 'network'
      network ?= DEFAULT_NETWORK
      location.hash = network.id
    @networks.load()

  hashchange: ->
    if location.hash
      @networks.$el.modal 'hide'
      id = location.hash.slice 1
      network = @networks.get id
      if network
        @stations.load network
        $('.current-network').html network.name
        document.title = TITLE + ' | ' + network.name
        return true
      else
        alert 'Unknown service'
    return false

class Networks
  URL = '/v2/networks'
  MOCK_URL = 'mock/networks.json'

  constructor: (@stations)->
    @$el = $ '#networks'
    @$input = @$el.find 'input'
    @$loading = @$el.find '.activity-indicator'
    @$list = @$el.find '.list-group'
    @empty()

    @$list.on 'click', '.list-group-item', =>
      @$el.modal 'hide'

    @$el.on 'shown.bs.modal', =>
      @$input.focus()

    @$input.on 'input', =>
      value = @$input.val()
      $items = @$list.find '.list-group-item'
      if value
        $items.hide()
        $items.removeClass('active')
        for result, i in @index.search value
          $item = $("#network-#{result.ref}")
          $item.show()
          if i is 0
            $item.addClass('active')
      else
        $items.removeClass('active')
        $items.show()

    @$input.parent('form').on 'submit', (e) =>
      e.preventDefault()
      $item = @$list.find '.active'
      if $item[0]?
        $item[0].click()

  empty: ->
    @index = lunr ->
      @field('location.city', {boost: 10})
      @field('name')
      @field('company')
      @ref('id')
    @items = {}
    @$list.empty()

  load: ->
    @refresh()

  refresh: ->
    @$loading.addClass('spin').parent().addClass('disabled')
    url = if DEBUG then MOCK_URL else API_URL+URL
    $.getJSON url, ({networks}) =>
      @empty()
      for network in networks
        @index.add network
        {id} = network
        @items[id] = network
        @render id, network
      @$loading.removeClass('spin').parent().removeClass('disabled')
    .fail =>
      @$loading.removeClass('spin').parent().removeClass('disabled')

  render: (id, network=null)->
    network ?= @items[id]
    {name, company, location} = network
    desc = []
    if company?
      if Array.isArray company
        for c in company
          desc.push c
      else
        desc.push company
    if location?.city?
      desc.push location.city
    if location?.country?
      desc.push location.country
    desc = desc.join ', '

    @$list.append(
      """
      <a href="##{id}" class="list-group-item" id="network-#{id}">
        <h4 class="list-group-item-heading">#{name}</h4>
        <p class="list-group-item-text">#{desc}</p>
      </a>
      """
    )

  get: (id) ->
    network = @items[id]
    network ?= JSON.parse localStorage.getItem 'network'
    network ?= DEFAULT_NETWORK
    network if network.id == id

class Stations
  MOCK_URL = 'mock/stations.json'
  EMPTY_HTML = '<span class="col-md-12 text-center help-block small">No results</span>'

  constructor: ->
    @$el = $ '#stations'
    @$input = $ '#stations-search input'
    @$stars = $ '#stars'
    @$all = $ '#all'
    @$updated = $ '#updated'
    @$refresh = $ '#refresh'
    @$loading = @$refresh.find '.activity-indicator'
    @empty()

    @$el.on 'click', '.btn-action', (e) =>
      $btn = $ e.currentTarget
      action = $btn.attr 'data-action'
      id = $btn.attr 'data-id'
      @[action](id)

    @$refresh.on 'click', =>
      @refresh()


    @$input.on 'input', =>
      value = @$input.val()
      $items = @$el.find '.station'
      if value
        $items.hide()
        console.log @index.search value
        for result, i in @index.search value
          $item = $("##{result.ref}")
          $item.show()
      else
        $items.show()

  star: (id) ->
    localStorage.setItem id, true
    $('#'+id).remove()
    @render id

  unstar: (id) ->
    localStorage.removeItem id
    $('#'+id).remove()
    @render id

  starred: (id) ->
    localStorage.getItem id, false

  load: (@network) ->
    localStorage.setItem('network', JSON.stringify @network)
    @refresh()

  loading: ->
    @$loading.addClass('spin')
    @$refresh.addClass('disabled')

  idle: ->
    @$refresh.removeClass('disabled')
    @$loading.removeClass('spin')


  empty: ->
    @index = lunr ->
      @field('name', {boost: 10})
      @field('extra.address')
      @ref('id')
    @items = {}
    [@$stars, @$all].map (el) -> el.empty() #html EMPTY_HTML

  refresh: ->
    @loading()
    url = if DEBUG then MOCK_URL else API_URL+@network.href
    $.getJSON url, ({network: {stations}}) =>
      @empty()
      for station in stations
        @index.add station
        {id} = station
        @items[id] = station
        @render id, station
      @$updated.html (new Date).toLocaleTimeString()
      @idle()
    .fail => @idle()

  render: (id, station=null) ->
    station ?= @items[id]
    {empty_slots, free_bikes, name} = station

    starred = @starred id

    slots = empty_slots + free_bikes
    percent = 100 * free_bikes / slots

    color =
      if free_bikes is 0
        'default'
      else if free_bikes <= 3
        'danger'
      else if free_bikes <= 6
        'warning'
      else
        'success'

    [action, icon] =
      if starred
        ['unstar', 'remove']
      else
        ['star', 'star-empty']

    title = action.charAt(0).toUpperCase() + action.slice(1)

    (if starred then @$stars else @$all).prepend(
      """
      {% include _station.html %}
      """
    )

$ ->
  window.app = new App()
  window.app.run()
