---
---
MOCKED = false

{{ site.env.coffee }}

TITLE = document.title

API_URL = 'http://api.citybik.es'
MAPS_URL = 'https://www.google.com/maps'

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


Keys =
  network: -> 'network'
  station: (id) -> id
  station_tags: (id) -> "#{id}_tags"
  shortcuts: (id) -> "#{id}_shortcuts"


Maps =
  coord: (lat, lon) -> "#{MAPS_URL}/place/#{lat},#{lon}/@#{lat},#{lon},18z"
  query: (q) -> "#{MAPS_URL}/search/#{q}/18z"

class App

  constructor: ->
    @stations = new Stations
    @networks = new Networks @stations
    @exporter = new Exporter

    $(window).on 'hashchange', => @hashchange()

  run: ->
    unless @hashchange()
      network = JSON.parse localStorage.getItem Keys.network()
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

    @$input.closest('form').on 'submit', (e) =>
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
    url = if MOCKED then MOCK_URL else API_URL+URL
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
    network ?= JSON.parse localStorage.getItem Keys.network()
    network ?= DEFAULT_NETWORK
    network if network.id == id

class Stations
  MOCK_URL = 'mock/stations.json'
  EMPTY_HTML = '<span class="col-md-12 text-center help-block small">No results</span>'

  constructor: ->
    @$el = $ '#stations'
    @$filter =
      search: $ '#stations-filter .search'
      input: $ '#stations-filter .search input'
      reset: $ '#stations-filter .search .btn-reset'
      shortcuts: $ '#stations-filter .shortcuts'
      tags: $ '#stations-filter .shortcuts .tags'
    @$stars = $ '#stars'
    @$all = $ '#all'
    @$updated = $ '#updated'
    @$refresh = $ '#refresh'
    @$loading = @$refresh.find '.activity-indicator'
    @empty()

    [@$el, $('#stations-filter')].map ($el) =>
      $el.on 'click', '.btn-action', (e) =>
        $btn = $ e.currentTarget
        action = $btn.attr 'data-action'
        id = $btn.attr 'data-id'
        @[action](id)

    @$refresh.on 'click', =>
      @refresh()


    @$filter.input.closest('form').on 'submit', (e) => @filter e
    @$filter.input.on 'input', (e) => @filter e

  filterBy: (mode) ->
    switch mode
      when 'shortcuts'
        @$filter.search.fadeOut 100,  =>
          @$filter.shortcuts.fadeIn(100)
      when 'search'
        @$filter.shortcuts.fadeOut 100, =>
          @$filter.search.fadeIn 100, =>
            @$filter.input.focus()

  setFilter: (text='') =>
    @$filter.input.focus().val(text).trigger('input')

  filter: (e=null) ->
    e?.preventDefault()
    value = @$filter.input.val()
    $items = @$el.find '.station'
    if value
      @$filter.reset.show()
      $items.hide()
      for result, i in @index.search value
        $item = $("##{result.ref}")
        $item.show()
    else
      @$filter.reset.hide()
      $items.show()
    @renderShortcuts()

  shortcuts: ->
    if @network
      {id} = @network
      key = Keys.shortcuts id
      shortcuts = localStorage.getItem key
      shortcuts = prompt "Please enter a list of commma-separated tags", shortcuts or ''
      if shortcuts isnt null
        localStorage.setItem key, shortcuts
        @renderShortcuts()

  renderShortcuts: ->
    if @network
      @$filter.tags.empty()
      {id} = @network
      key = Keys.shortcuts id
      shortcuts = localStorage.getItem key
      if shortcuts
        for tag in shortcuts.split ','
          tag = tag.trim()
          stations = (@items[ref].free_bikes for {ref} in @index.search tag)
          bikes =
            if stations.length
              stations.reduce (a, b) -> a + b
            else
              0
          val = @$filter.input.val()
          cls = if tag == val then 'active' else ''
          @$filter.tags.append(
            """
            <button type="button" class="btn btn-info btn-action #{cls}" data-action="setFilter" data-id="#{tag}" data-toggle="button">
              #{tag}
              <span class="badge">#{bikes}</span>
            </button>
            """
          )
      else
        @$filter.tags.prepend(
          """
          <button class="btn btn-default text-muted btn-action" data-action="shortcuts">
            Click here to start adding shortcuts
          </button>
          """
        )


  tag: (id) ->
    station = @items[id]
    tags = prompt "Edit tags for #{station.name}", station.tags
    if tags isnt null
      station.tags = tags
      localStorage.setItem Keys.station_tags(id), tags
    @index.update station
    @render id


  star: (id) ->
    localStorage.setItem id, true
    @render id

  unstar: (id) ->
    localStorage.removeItem id
    @render id

  starred: (id) ->
    localStorage.getItem id, false

  load: (@network) ->
    localStorage.setItem(Keys.network, JSON.stringify @network)
    @refresh()

  loading: ->
    @$loading.addClass('spin')
    @$refresh.addClass('disabled')

  idle: ->
    @$refresh.removeClass('disabled')
    @$loading.removeClass('spin')


  empty: ->
    @index = lunr ->
      @field('tags', {boost: 20})
      @field('name', {boost: 10})
      @field('extra.address')
      @ref('id')
    @items = {}
    [@$stars, @$all].map (el) -> el.empty() #html EMPTY_HTML

  refresh: ->
    @loading()
    url = if MOCKED then MOCK_URL else API_URL+@network.href
    $.getJSON url, ({network: {stations}}) =>
      @empty()
      for station in stations
        {id} = station
        station.tags = localStorage.getItem(Keys.station_tags(id)) or ''
        @index.add station
        @items[id] = station
        @render id, station
      @filter()
      @$updated.html (new Date).toLocaleTimeString()
      @idle()
    .fail => @idle()

  render: (id, station=null) ->
    $('#'+id)?.remove()
    station ?= @items[id]
    {empty_slots, free_bikes, name, tags, extra, latitude, longitude} = station

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

    map =
      if latitude and longitude
        Maps.coord latitude, longitude
      else
        if {address} = extra
          Maps.query address
        else
          Maps.query name

    (if starred then @$stars else @$all).prepend(
      """
      {% include _station.html %}
      """
    )

class Exporter
  constructor: ->
    @$el = $ '#exporter'
    @$textarea = @$el.find 'textarea'

    @$el.on 'click', '.btn-action', (e) =>
      $btn = $ e.currentTarget
      action = $btn.attr 'data-action'
      @[action]()

  export: ->
    data = JSON.stringify localStorage

    @$textarea
      .val(data)
      .select()

    @success(
      'Data has been exported to this text area.',
      'Please copy the content and paste it in the browser you want to import the data.'
    )

  import: ->
    data = @$textarea.val()
    if data
      data = JSON.parse data
      for k,v of data
        localStorage.setItem k, v
      @success 'Imported'
    else
      @warning 'Nothing to import'

  clear: ->
    if confirm 'Are you sure? All data will be lost'
      localStorage.clear()
      @$textarea.val ''
      app.stations.refresh()
      @success 'All data has been deleted'

  success: (head, body="") ->
    @$textarea.before(
      """
        <div class="alert alert-success alert-dismissible fade in" role="alert">
          <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">×</span></button>
          <strong>#{head}</strong> #{body}
        </div>
      """
    )


  warning: (head, body="") ->
    @$textarea.before(
      """
        <div class="alert alert-warning alert-dismissible fade in" role="alert">
          <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">×</span></button>
          <strong>#{head}</strong>#{body}
        </div>
      """
    )


$ ->
  window.app = new App()
  window.app.run()
