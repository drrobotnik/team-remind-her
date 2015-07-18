# Description:
#   Forgetful? Add reminders
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   *hubot remind me in `time` to `action`* - Set a reminder in `time` to do an `action` `time` is in the format 1 day, 2 hours, 5 minutes etc. Time segments are optional, as are commas
#   *hubot remind `user` in `time` to `action`* - Set a reminder in `time` to do an `action` `time` is in the format 1 day, 2 hours, 5 minutes etc. Time segments are optional, as are commas
#
# Author:
#   whitman

chrono = require 'chrono-node'
uuid = require 'node-uuid'
moment = require 'moment'

time_until = (date) ->
  date.getTime() - new Date().getTime()

chrono_parse = (text, ref) ->
  results = chrono.parse text, ref
  if results.length == 0
    return
  result = results[0]
  date = result.start.date()
  if time_until(date) <= 0 && result.tags.ENTimeExpressionParser
    ref = chrono.parse('tomorrow')[0].start.date()
    return chrono_parse text, ref
  result

get_time = (text) ->
  chrono_result = chrono_parse text
    if not chrono_result and text.indexOf('every')
      text = text.replace 'in every', 'every in'
      chrono_result = chrono_parse text

    unless chrono_result
      msg.send "I did not understand the date in '#{text}'"
      return

    every_idx = text.indexOf('every')
    repeat = every_idx > -1 and every_idx < chrono_result.index
    date = chrono_result.start.date()
    return date

class Reminders
  constructor: (@robot) ->
    @cache = []
    @current_timeout = null

    @robot.brain.on 'loaded', =>
      if @robot.brain.data.reminders
        @cache = @robot.brain.data.reminders
        @queue()

  add: (reminder) ->
    @cache.push reminder
    @cache.sort (a, b) -> a.due - b.due
    @robot.brain.data.reminders = @cache
    @queue()

  # list: ->
  #  console.log(@cache)

  removeFirst: ->
    reminder = @cache.shift()
    @robot.brain.data.reminders = @cache
    return reminder

  queue: ->
    clearTimeout @current_timeout if @current_timeout
    if @cache.length > 0
      now = new Date().getTime()
      @removeFirst() until @cache.length is 0 or @cache[0].due > now
      if @cache.length > 0
        trigger = =>
          reminder = @removeFirst()
          if reminder.msg_envelope.message.user.name == reminder.msg_envelope.user.name
            from = 'you'
          else
            from = reminder.msg_envelope.message.user.name
          @robot.send reminder.msg_envelope, from + ' asked me to remind you to ' + reminder.action

          @queue()
        # setTimeout uses a 32-bit INT
        extendTimeout = (timeout, callback) ->
          if timeout > 0x7FFFFFFF
            @current_timeout = setTimeout ->
              extendTimeout (timeout - 0x7FFFFFFF), callback
            , 0x7FFFFFFF
          else
            @current_timeout = setTimeout callback, timeout
        extendTimeout @cache[0].due - now, trigger

class Reminder
  constructor: (@msg_envelope, @time, @action ) ->
    @time.replace(/^\s+|\s+$/g, '')

    periods =
      weeks:
        value: 0
        regex: "weeks?"
      days:
        value: 0
        regex: "days?"
      hours:
        value: 0
        regex: "hours?|hrs?"
      minutes:
        value: 0
        regex: "minutes?|mins?"
      seconds:
        value: 0
        regex: "seconds?|secs?"

    for period of periods
      pattern = new RegExp('^.*?([\\d\\.]+)\\s*(?:(?:' + periods[period].regex + ')).*$', 'i')
      matches = pattern.exec(@time)
      periods[period].value = parseInt(matches[1]) if matches

    @due = new Date().getTime()
    @due += ((periods.weeks.value * 604800) + (periods.days.value * 86400) + (periods.hours.value * 3600) + (periods.minutes.value * 60) + periods.seconds.value) * 1000

    @to = @who

  dueDate: ->
    dueDate = new Date @due
    options.timeZone = "UTC-8";
    dueDate.toLocaleString("en-US",options)

module.exports = (robot) ->

  reminders = new Reminders robot

  robot.respond /remind (\w*) (.*) to (.*)/i, (msg) ->
    time = get_time( msg.match[1] )
    action = msg.match[2]
    reminder = new Reminder msg.envelope, time, action
    reminders.add reminder
    msg.send 'I\'ll remind you to ' + action + ' on ' + reminder.dueDate()

  robot.respond /remind (\w*) (.*) to (.*)/i, (msg) ->
    who = msg.match[1]
    time = get_time( msg.match[2] )
    action = msg.match[3]

    users = robot.brain.usersForFuzzyName(who)
    if users.length is 1
      user = users[0]

    msg.envelope.user = user

    reminder = new Reminder msg.envelope, time, action
    reminders.add reminder

  robot.respond /reminders list/i, (msg) ->
    caches = reminders.cache
    if caches.length > 1
      msg.send "Scheduled Reminders:"

    for cache of caches
      cacheObj = caches[cache]
      to = cacheObj.msg_envelope.user.name
      from = cacheObj.msg_envelope.message.user.name
      message = cacheObj.action
      dueDate = new Date(cacheObj.due)

      dateOptions = {weekday: "long", year: "numeric", month: "long", day: "numeric", hour12: 1, timeZone:"UTC−8", timeZoneName:'short'}

      due = dueDate.toLocaleString("en-US", dateOptions)

      if from == to
        from = 'From you'
      else
        from = from + ' sent to ' + to

      message = from + ', "' + message + '"'
      msg.send message

