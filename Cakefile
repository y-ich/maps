{spawn, exec} = require 'child_process'

maps = ['googleMapsExtensions.coffee', 'maps.coffee']
maps2 = ['googleDrive.coffee', 'googleMapsExtensions.coffee', 'maps2.coffee']
start = 'webapp.coffee'
start2 = 'webapp2.coffee'

task 'watch', 'continually build with --watch', ->
    src = spawn 'coffee', ['-wcj', 'maps.js'].concat maps
    src.stdout.on 'data', (data) -> console.log data.toString().trim()

    src2 = spawn 'coffee', ['-wc', start]
    src2.stdout.on 'data', (data) -> console.log data.toString().trim()

    test = spawn 'coffee', ['-wcbj', 'test/maps.js'].concat maps
    test.stdout.on 'data', (data) -> console.log data.toString().trim()

    spec = spawn 'coffee', ['-wc','spec']
    spec.stdout.on 'data', (data) -> console.log data.toString().trim()

task 'watch2', 'continually build with --watch', ->
    src = spawn 'coffee', ['-wcj', 'maps2.js'].concat maps2
    src.stdout.on 'data', (data) -> console.log data.toString().trim()

    src2 = spawn 'coffee', ['-wc', start2]
    src2.stdout.on 'data', (data) -> console.log data.toString().trim()

    test = spawn 'coffee', ['-wcbj', 'test/maps2.js'].concat maps2
    test.stdout.on 'data', (data) -> console.log data.toString().trim()

    spec = spawn 'coffee', ['-wc','spec']
    spec.stdout.on 'data', (data) -> console.log data.toString().trim()

task 'css', 'compile less', ->
    child = exec 'lessc maps.less > maps.css', (error, stdout, stderr) ->
        console.log 'stdout: ' + stderr
        console.log 'error: ' + error if error?