{spawn, exec} = require 'child_process'

maps = ['googleMapsExtensions.coffee', 'maps.coffee']
fusionMaps = ['googleDrive.coffee', 'fusion-maps.coffee']
eventMaps = ['event-maps.coffee']
start = 'webapp.coffee'
start2 = 'webapp2.coffee'

task 'maps', 'continually build with --watch', ->
    src = spawn 'coffee', ['-wcj', 'maps.js'].concat maps
    src.stdout.on 'data', (data) -> console.log data.toString().trim()

    src2 = spawn 'coffee', ['-wc', start]
    src2.stdout.on 'data', (data) -> console.log data.toString().trim()

    test = spawn 'coffee', ['-wcbj', 'test/maps.js'].concat maps
    test.stdout.on 'data', (data) -> console.log data.toString().trim()

    spec = spawn 'coffee', ['-wc','spec']
    spec.stdout.on 'data', (data) -> console.log data.toString().trim()

task 'fusion-maps', 'continually build with --watch', ->
    src = spawn 'coffee', ['-wcj', 'fusion-maps.js'].concat fusionMaps
    src.stdout.on 'data', (data) -> console.log data.toString().trim()

    src2 = spawn 'coffee', ['-wc', start2]
    src2.stdout.on 'data', (data) -> console.log data.toString().trim()

    test = spawn 'coffee', ['-wcbj', 'test/fusion-maps.js'].concat fusionMaps
    test.stdout.on 'data', (data) -> console.log data.toString().trim()

    spec = spawn 'coffee', ['-wc','spec']
    spec.stdout.on 'data', (data) -> console.log data.toString().trim()

task 'event-maps', 'continually build with --watch', ->
    src = spawn 'coffee', ['-wcj', 'event-maps.js'].concat eventMaps
    src.stdout.on 'data', (data) -> console.log data.toString().trim()

    src2 = spawn 'coffee', ['-wc', start2]
    src2.stdout.on 'data', (data) -> console.log data.toString().trim()

    test = spawn 'coffee', ['-wcbj', 'test/event-maps.js'].concat eventMaps
    test.stdout.on 'data', (data) -> console.log data.toString().trim()

    spec = spawn 'coffee', ['-wc','spec']
    spec.stdout.on 'data', (data) -> console.log data.toString().trim()

task 'navi', 'continually build with --watch', ->
    app = spawn 'coffee', ['-wcj', 'navi.js'].concat ['waudio.coffee', 'navi.coffee']
    app.stdout.on 'data', (data) -> console.log data.toString().trim()
