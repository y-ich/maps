{spawn, exec} = require 'child_process'

files = ['googleMapsExtensions.coffee', 'maps.coffee']

task 'watch', 'continually build with --watch', ->
    src = spawn 'coffee', ['-wcj','maps.js', files.join ' ']
    src.stdout.on 'data', (data) -> console.log data.toString().trim()

    test = spawn 'coffee', ['-wcbj','test/maps.js', files.join ' ']
    test.stdout.on 'data', (data) -> console.log data.toString().trim()

    spec = spawn 'coffee', ['-wc','spec']
    spec.stdout.on 'data', (data) -> console.log data.toString().trim()
