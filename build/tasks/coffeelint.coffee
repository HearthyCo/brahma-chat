module.exports = ->

  @loadNpmTasks "grunt-coffeelint"

  @config "coffeelint",
    options:
      max_line_length:
        level: "ignore"
    all:
      src: ["Gruntfile.coffee", "src/**/*.coffee"]
